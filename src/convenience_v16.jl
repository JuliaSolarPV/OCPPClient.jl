"""
OCPP 1.6 internal convenience method implementations.
Each function dispatches on `::OCPPData.V16.Spec` and is called from the
public dispatch layer in `convenience.jl`.
"""

function _boot_notification(
    ::OCPPData.V16.Spec,
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

function _heartbeat(::OCPPData.V16.Spec, cp::ChargePoint; timeout::Float64 = 30.0)
    req = OCPPData.V16.HeartbeatRequest()
    return _send_typed(
        cp,
        "Heartbeat",
        req,
        OCPPData.V16.HeartbeatResponse;
        timeout = timeout,
    )
end

function _authorize(::OCPPData.V16.Spec, cp::ChargePoint; id_tag::String, kwargs...)
    req = OCPPData.V16.AuthorizeRequest(; id_tag = id_tag)
    return _send_typed(cp, "Authorize", req, OCPPData.V16.AuthorizeResponse)
end

function _status_notification(
    ::OCPPData.V16.Spec,
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

function _start_transaction(
    ::OCPPData.V16.Spec,
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

function _stop_transaction(
    ::OCPPData.V16.Spec,
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

function _meter_values(
    ::OCPPData.V16.Spec,
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

function _transaction_event(::OCPPData.V16.Spec, cp::ChargePoint; kwargs...)
    throw(
        OCPPVersionError(
            "transaction_event is V201-only. Use start_transaction/stop_transaction for V16.",
        ),
    )
end
