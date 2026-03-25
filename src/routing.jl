"""
Server-initiated call dispatch: incoming Call → handler → CallResult/CallError.
"""

if OCPPData.ENABLE_V16
    """Look up the request type for an action based on the OCPP spec version."""
    function _request_type(::OCPPData.V16.Spec, action::String)
        return OCPPData.V16.request_type(action)
    end

    """Look up the response type for an action based on the OCPP spec version."""
    function _response_type(::OCPPData.V16.Spec, action::String)
        return OCPPData.V16.response_type(action)
    end
end

if OCPPData.ENABLE_V201
    function _request_type(::OCPPData.V201.Spec, action::String)
        return OCPPData.V201.request_type(action)
    end

    function _response_type(::OCPPData.V201.Spec, action::String)
        return OCPPData.V201.response_type(action)
    end
end

"""
    _handle_server_call(cp::ChargePoint, call::OCPPData.Call)

Dispatch an incoming server Call to the registered handler and return a
CallResult or CallError.
"""
function _handle_server_call(cp::ChargePoint, call::OCPPData.Call)::OCPPData.OCPPMessage
    handler = lock(cp.lock) do
        get(cp.handlers, call.action, nothing)
    end

    if handler === nothing
        return OCPPData.CallError(
            call.unique_id,
            "NotImplemented",
            "No handler registered for action: $(call.action)",
            Dict{String,Any}(),
        )
    end

    try
        # Deserialize payload to typed request struct
        RequestType = _request_type(cp.spec, call.action)
        typed_request = JSON.parse(JSON.json(call.payload), RequestType)

        # Call handler: handler(cp, typed_request) → typed response
        response = handler(cp, typed_request)

        # Convert response to Dict payload
        response_payload = _to_payload(response)

        return OCPPData.CallResult(call.unique_id, response_payload)
    catch e
        @error "Handler error for $(call.action)" exception = (e, catch_backtrace())
        return OCPPData.CallError(
            call.unique_id,
            "InternalError",
            "Handler error: $(sprint(showerror, e))",
            Dict{String,Any}(),
        )
    end
end
