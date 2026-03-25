"""
OCPP 2.0.1 internal convenience method implementations.
Each function dispatches on `::OCPPData.V201.Spec` and is called from the
public dispatch layer in `convenience.jl`.
"""

function _boot_notification(
    ::OCPPData.V201.Spec,
    cp::ChargePoint;
    reason::OCPPData.V201.BootReason,
    charging_station::OCPPData.V201.ChargingStation,
    kwargs...,
)
    req = OCPPData.V201.BootNotificationRequest(;
        reason = reason,
        charging_station = charging_station,
        kwargs...,
    )
    resp = _send_typed(cp, "BootNotification", req, OCPPData.V201.BootNotificationResponse)
    if resp.status == OCPPData.V201.RegistrationAccepted
        lock(cp.lock) do
            cp.status = :booted
        end
    end
    return resp
end

function _heartbeat(::OCPPData.V201.Spec, cp::ChargePoint; timeout::Float64 = 30.0)
    req = OCPPData.V201.HeartbeatRequest()
    return _send_typed(
        cp,
        "Heartbeat",
        req,
        OCPPData.V201.HeartbeatResponse;
        timeout = timeout,
    )
end

function _authorize(
    ::OCPPData.V201.Spec,
    cp::ChargePoint;
    id_token::OCPPData.V201.IdToken,
    kwargs...,
)
    req = OCPPData.V201.AuthorizeRequest(; id_token = id_token, kwargs...)
    return _send_typed(cp, "Authorize", req, OCPPData.V201.AuthorizeResponse)
end

function _status_notification(
    ::OCPPData.V201.Spec,
    cp::ChargePoint;
    connector_id::Int,
    connector_status::OCPPData.V201.ConnectorStatus,
    evse_id::Int,
    timestamp::String = Dates.format(now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SS.sssZ"),
    kwargs...,
)
    req = OCPPData.V201.StatusNotificationRequest(;
        connector_id = connector_id,
        connector_status = connector_status,
        evse_id = evse_id,
        timestamp = timestamp,
        kwargs...,
    )
    return _send_typed(
        cp,
        "StatusNotification",
        req,
        OCPPData.V201.StatusNotificationResponse,
    )
end

"""
    transaction_event(cp; event_type, seq_no, timestamp, transaction_info,
                      trigger_reason, kwargs...)

Send a TransactionEvent (V201 only). Throws `OCPPVersionError` for V16.
Required kwargs:
- `event_type::OCPPData.V201.TransactionEvent` — Started, Updated, or Ended
- `seq_no::Int` — sequence number (monotonically increasing per transaction)
- `transaction_info::OCPPData.V201.Transaction` — transaction details
- `trigger_reason::OCPPData.V201.TriggerReason` — reason for this event
"""
function _transaction_event(
    ::OCPPData.V201.Spec,
    cp::ChargePoint;
    event_type::OCPPData.V201.TransactionEvent,
    seq_no::Int,
    transaction_info::OCPPData.V201.Transaction,
    trigger_reason::OCPPData.V201.TriggerReason,
    timestamp::String = Dates.format(now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SS.sssZ"),
    kwargs...,
)
    req = OCPPData.V201.TransactionEventRequest(;
        event_type = event_type,
        seq_no = seq_no,
        transaction_info = transaction_info,
        trigger_reason = trigger_reason,
        timestamp = timestamp,
        kwargs...,
    )
    return _send_typed(cp, "TransactionEvent", req, OCPPData.V201.TransactionEventResponse)
end

function _meter_values(
    ::OCPPData.V201.Spec,
    cp::ChargePoint;
    evse_id::Int,
    meter_value::Vector{OCPPData.V201.MeterValue},
    kwargs...,
)
    req = OCPPData.V201.MeterValuesRequest(;
        evse_id = evse_id,
        meter_value = meter_value,
        kwargs...,
    )
    return _send_typed(cp, "MeterValues", req, OCPPData.V201.MeterValuesResponse)
end

function _start_transaction(::OCPPData.V201.Spec, cp::ChargePoint; kwargs...)
    throw(
        OCPPVersionError("start_transaction is V16-only. Use transaction_event for V201."),
    )
end

function _stop_transaction(::OCPPData.V201.Spec, cp::ChargePoint; kwargs...)
    throw(OCPPVersionError("stop_transaction is V16-only. Use transaction_event for V201."))
end
