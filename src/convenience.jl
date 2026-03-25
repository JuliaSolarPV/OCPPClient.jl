"""
Typed convenience methods for common OCPP actions. Each method constructs a
typed request struct, converts to a Dict payload, calls `send_call`, and
returns the typed response.
"""

# ── Helpers ──

"""Convert a typed struct to a Dict{String,Any} payload with camelCase keys."""
function _to_payload(obj)::Dict{String,Any}
    return Dict{String,Any}(JSON.parse(JSON.json(obj)))
end

"""Convert a Dict payload back to a typed struct."""
function _from_payload(::Type{T}, payload)::T where {T}
    return JSON.parse(JSON.json(payload), T)
end

"""
Send a typed request and return the typed response. Throws `OCPPCallError`
if the server returns a CallError.
"""
function _send_typed(
    cp::ChargePoint,
    action::String,
    request,
    ::Type{ResponseT};
    timeout::Float64 = 30.0,
) where {ResponseT}
    payload = _to_payload(request)
    result = send_call(cp, action, payload; timeout = timeout)
    if result isa OCPPData.CallError
        throw(
            OCPPCallError(
                result.error_code,
                result.error_description,
                result.error_details,
            ),
        )
    end
    return _from_payload(ResponseT, result.payload)
end

# ── V16 Convenience Methods ──

"""
    boot_notification(cp; charge_point_vendor, charge_point_model, kwargs...)

Send a BootNotification to the CSMS. Returns `BootNotificationResponse`.
"""
function boot_notification(
    cp::ChargePoint;
    charge_point_vendor::String,
    charge_point_model::String,
    kwargs...,
)
    req = OCPPData.V16.BootNotificationRequest(;
        charge_point_vendor = charge_point_vendor,
        charge_point_model = charge_point_model,
        kwargs...,
    )
    resp = _send_typed(cp, "BootNotification", req, OCPPData.V16.BootNotificationResponse)
    if resp.status == OCPPData.V16.RegistrationAccepted
        lock(cp.lock) do
            cp.status = :booted
        end
    end
    return resp
end

"""
    heartbeat(cp; timeout=30.0)

Send a Heartbeat to the CSMS. Returns `HeartbeatResponse`.
"""
function heartbeat(cp::ChargePoint; timeout::Float64 = 30.0)
    req = OCPPData.V16.HeartbeatRequest()
    return _send_typed(
        cp,
        "Heartbeat",
        req,
        OCPPData.V16.HeartbeatResponse;
        timeout = timeout,
    )
end

"""
    authorize(cp; id_tag)

Send an Authorize request. Returns `AuthorizeResponse`.
"""
function authorize(cp::ChargePoint; id_tag::String)
    req = OCPPData.V16.AuthorizeRequest(; id_tag = id_tag)
    return _send_typed(cp, "Authorize", req, OCPPData.V16.AuthorizeResponse)
end

"""
    status_notification(cp; connector_id, status, error_code, kwargs...)

Send a StatusNotification. Returns `StatusNotificationResponse`.
"""
function status_notification(
    cp::ChargePoint;
    connector_id::Int,
    status::OCPPData.V16.ChargePointStatus,
    error_code::OCPPData.V16.ChargePointErrorCode,
    kwargs...,
)
    req = OCPPData.V16.StatusNotificationRequest(;
        connector_id = connector_id,
        status = status,
        error_code = error_code,
        kwargs...,
    )
    return _send_typed(
        cp,
        "StatusNotification",
        req,
        OCPPData.V16.StatusNotificationResponse,
    )
end

"""
    start_transaction(cp; connector_id, id_tag, meter_start, timestamp,
                      kwargs...)

Send a StartTransaction. Returns `StartTransactionResponse`.
"""
function start_transaction(
    cp::ChargePoint;
    connector_id::Int,
    id_tag::String,
    meter_start::Int,
    timestamp::String = Dates.format(now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SS.sssZ"),
    kwargs...,
)
    req = OCPPData.V16.StartTransactionRequest(;
        connector_id = connector_id,
        id_tag = id_tag,
        meter_start = meter_start,
        timestamp = timestamp,
        kwargs...,
    )
    return _send_typed(cp, "StartTransaction", req, OCPPData.V16.StartTransactionResponse)
end

"""
    stop_transaction(cp; transaction_id, meter_stop, timestamp, kwargs...)

Send a StopTransaction. Returns `StopTransactionResponse`.
"""
function stop_transaction(
    cp::ChargePoint;
    transaction_id::Int,
    meter_stop::Int,
    timestamp::String = Dates.format(now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SS.sssZ"),
    kwargs...,
)
    req = OCPPData.V16.StopTransactionRequest(;
        transaction_id = transaction_id,
        meter_stop = meter_stop,
        timestamp = timestamp,
        kwargs...,
    )
    return _send_typed(cp, "StopTransaction", req, OCPPData.V16.StopTransactionResponse)
end

"""
    meter_values(cp; connector_id, meter_value, kwargs...)

Send MeterValues. Returns `MeterValuesResponse`.
"""
function meter_values(
    cp::ChargePoint;
    connector_id::Int,
    meter_value::Vector{OCPPData.V16.MeterValue},
    kwargs...,
)
    req = OCPPData.V16.MeterValuesRequest(;
        connector_id = connector_id,
        meter_value = meter_value,
        kwargs...,
    )
    return _send_typed(cp, "MeterValues", req, OCPPData.V16.MeterValuesResponse)
end
