"""
WebSocket transport: connect!, disconnect!, send_call, message loop,
and auto-reconnect logic.
"""

if OCPPData.ENABLE_V16
    """
        _ws_protocol(spec::OCPPData.AbstractOCPPSpec)

    Return the OCPP WebSocket sub-protocol string for the given spec.
    """
    _ws_protocol(::OCPPData.V16.Spec) = "ocpp1.6"
end
if OCPPData.ENABLE_V201
    _ws_protocol(::OCPPData.V201.Spec) = "ocpp2.0.1"
end

"""
    connect!(cp::ChargePoint)

Connect to the CSMS WebSocket server. Blocks while connected; use with
`@async` or `Threads.@spawn`. Automatically reconnects on disconnect if
`cp.reconnect` is `true`.
"""
function connect!(cp::ChargePoint)
    url = cp.url * "/" * cp.id
    protocol = _ws_protocol(cp.spec)
    headers = ["Sec-WebSocket-Protocol" => protocol]

    while true
        try
            HTTP.WebSockets.open(url; headers = headers, suppress_close_error = true) do ws
                lock(cp.lock) do
                    cp.ws = ws
                    cp.status = :connected
                end
                _emit(cp, Connected(now(Dates.UTC)))
                @info "Connected to CSMS" url = url id = cp.id
                _message_loop(cp, ws)
            end
        catch e
            if !(e isa EOFError || e isa HTTP.WebSockets.WebSocketError)
                @error "Connection error" exception = (e, catch_backtrace())
            end
        end

        # Connection ended — clean up
        lock(cp.lock) do
            cp.ws = nothing
            cp.status = :disconnected
        end

        should_reconnect = lock(cp.lock) do
            cp.reconnect
        end

        if !should_reconnect
            _emit(cp, Disconnected(now(Dates.UTC), :normal))
            break
        end

        _emit(cp, Disconnected(now(Dates.UTC), :error))
        interval = cp.reconnect_interval
        @info "Reconnecting in $(interval)s..." id = cp.id
        sleep(interval)
    end

    return nothing
end

"""
    disconnect!(cp::ChargePoint)

Disconnect from the CSMS. Disables auto-reconnect before closing.
"""
function disconnect!(cp::ChargePoint)
    lock(cp.lock) do
        cp.reconnect = false
    end
    ws = lock(cp.lock) do
        cp.ws
    end
    if ws !== nothing && !HTTP.WebSockets.isclosed(ws)
        close(ws)
    end
    return nothing
end

"""
    send_call(cp::ChargePoint, action::String, payload::Dict{String,Any};
              timeout::Float64=30.0)

Send an OCPP Call to the CSMS and block until a response is received or the
timeout expires. Returns the `OCPPData.OCPPMessage` (CallResult or CallError).
"""
function send_call(
    cp::ChargePoint,
    action::String,
    payload::Dict{String,Any};
    timeout::Float64 = 30.0,
)
    ws = lock(cp.lock) do
        cp.ws
    end
    if ws === nothing || HTTP.WebSockets.isclosed(ws)
        throw(OCPPTimeoutError("Not connected to CSMS"))
    end

    unique_id = OCPPData.generate_unique_id()
    ch = Channel{OCPPData.OCPPMessage}(1)

    lock(cp.lock) do
        cp.pending_calls[unique_id] = ch
    end

    msg = OCPPData.Call(unique_id, action, payload)
    encoded = OCPPData.encode(msg)

    try
        HTTP.WebSockets.send(ws, encoded)
    catch e
        lock(cp.lock) do
            delete!(cp.pending_calls, unique_id)
        end
        rethrow()
    end

    # Wait for response with timeout
    timer = Timer(timeout)
    @async begin
        wait(timer)
        isopen(ch) && close(ch)
    end

    result = try
        take!(ch)
    catch e
        if e isa InvalidStateException
            throw(
                OCPPTimeoutError(
                    "Timeout ($(timeout)s) waiting for response " *
                    "to $action ($unique_id)",
                ),
            )
        end
        rethrow()
    finally
        close(timer)
        lock(cp.lock) do
            delete!(cp.pending_calls, unique_id)
        end
    end

    return result
end

"""
Read messages from the WebSocket and dispatch them.
"""
function _message_loop(cp::ChargePoint, ws::HTTP.WebSockets.WebSocket)
    for raw in ws
        data = String(raw)
        msg = try
            OCPPData.decode(data)
        catch e
            @error "Failed to decode OCPP message" raw = data exception =
                (e, catch_backtrace())
            continue
        end
        _dispatch(cp, ws, msg)
    end
    return nothing
end

function _dispatch(cp::ChargePoint, ws::HTTP.WebSockets.WebSocket, call::OCPPData.Call)
    _emit(cp, ServerCallReceived(call.action, call, now(Dates.UTC)))
    response = _handle_server_call(cp, call)
    encoded = OCPPData.encode(response)
    try
        HTTP.WebSockets.send(ws, encoded)
    catch e
        @error "Failed to send response" action = call.action exception =
            (e, catch_backtrace())
    end
    return nothing
end

function _dispatch(
    cp::ChargePoint,
    ::HTTP.WebSockets.WebSocket,
    result::OCPPData.CallResult,
)
    ch = lock(cp.lock) do
        get(cp.pending_calls, result.unique_id, nothing)
    end
    if ch !== nothing && isopen(ch)
        put!(ch, result)
    else
        @warn "Received CallResult for unknown unique_id" unique_id = result.unique_id
    end
    _emit(cp, ResponseReceived("", result, now(Dates.UTC)))
    return nothing
end

function _dispatch(
    cp::ChargePoint,
    ::HTTP.WebSockets.WebSocket,
    error_msg::OCPPData.CallError,
)
    ch = lock(cp.lock) do
        get(cp.pending_calls, error_msg.unique_id, nothing)
    end
    if ch !== nothing && isopen(ch)
        put!(ch, error_msg)
    else
        @warn "Received CallError for unknown unique_id" unique_id = error_msg.unique_id
    end
    _emit(cp, ResponseReceived("", error_msg, now(Dates.UTC)))
    return nothing
end
