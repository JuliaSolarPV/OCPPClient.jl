"""
ChargePoint struct and registration functions (on!, subscribe!).
"""

mutable struct ChargePoint
    id::String
    url::String
    ws::Union{HTTP.WebSockets.WebSocket,Nothing}
    status::Symbol  # :disconnected, :connected, :booted
    handlers::Dict{String,Function}
    listeners::Vector{Function}
    pending_calls::Dict{String,Channel{OCPPData.OCPPMessage}}
    spec::OCPPData.AbstractOCPPSpec
    reconnect::Bool
    reconnect_interval::Float64
    lock::ReentrantLock
end

"""
    ChargePoint(id, url; spec=OCPPData.V16.Spec(), reconnect=true,
                reconnect_interval=5.0)

Create a ChargePoint. Does not connect yet — call `connect!` to start.
"""
function ChargePoint(
    id::String,
    url::String;
    spec::OCPPData.AbstractOCPPSpec = OCPPData.V16.Spec(),
    reconnect::Bool = true,
    reconnect_interval::Float64 = 5.0,
)
    return ChargePoint(
        id,
        url,
        nothing,
        :disconnected,
        Dict{String,Function}(),
        Function[],
        Dict{String,Channel{OCPPData.OCPPMessage}}(),
        spec,
        reconnect,
        reconnect_interval,
        ReentrantLock(),
    )
end

"""
    on!(cp::ChargePoint, action::String, handler::Function)

Register a handler for a server-initiated action (e.g., Reset).
Signature: `handler(cp::ChargePoint, request) → response_payload`
"""
function on!(cp::ChargePoint, action::String, handler::Function)
    lock(cp.lock) do
        cp.handlers[action] = handler
    end
    return nothing
end

# Support do-block syntax: on!(cp, "Reset") do cp, req ... end
function on!(handler::Function, cp::ChargePoint, action::String)
    return on!(cp, action, handler)
end

"""
    subscribe!(cp::ChargePoint, callback::Function)

Subscribe to `ClientEvent`s. Signature: `callback(event::ClientEvent)`.
"""
function subscribe!(cp::ChargePoint, callback::Function)
    lock(cp.lock) do
        push!(cp.listeners, callback)
    end
    return nothing
end

# Support do-block syntax: subscribe!(cp) do event ... end
function subscribe!(callback::Function, cp::ChargePoint)
    return subscribe!(cp, callback)
end

"""
Emit a ClientEvent to all registered listeners.
"""
function _emit(cp::ChargePoint, event::ClientEvent)
    listeners = lock(cp.lock) do
        copy(cp.listeners)
    end
    for cb in listeners
        try
            cb(event)
        catch e
            @error "Event listener error" exception = (e, catch_backtrace())
        end
    end
    return nothing
end
