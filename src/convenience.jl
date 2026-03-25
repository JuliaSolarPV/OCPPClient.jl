"""
Typed convenience methods for common OCPP actions. Each method dispatches to a
version-specific implementation based on `cp.spec`. Version-specific
implementations live in `convenience_v16.jl` and `convenience_v201.jl`.
"""

# ── Shared helpers ──

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

# ── Public dispatch layer ──

"""
    boot_notification(cp; kwargs...)

Send a BootNotification. Dispatches to V16 or V201 based on `cp.spec`.

**V16 kwargs:** `charge_point_vendor::String`, `charge_point_model::String`

**V201 kwargs:** `reason::OCPPData.V201.BootReason`,
`charging_station::OCPPData.V201.ChargingStation`
"""
function boot_notification(cp::ChargePoint; kwargs...)
    return _boot_notification(cp.spec, cp; kwargs...)
end

"""
    heartbeat(cp; timeout=30.0)

Send a Heartbeat. Returns a version-appropriate HeartbeatResponse.
"""
function heartbeat(cp::ChargePoint; kwargs...)
    return _heartbeat(cp.spec, cp; kwargs...)
end

"""
    authorize(cp; kwargs...)

Send an Authorize request.

**V16 kwargs:** `id_tag::String`

**V201 kwargs:** `id_token::OCPPData.V201.IdToken`
"""
function authorize(cp::ChargePoint; kwargs...)
    return _authorize(cp.spec, cp; kwargs...)
end

"""
    status_notification(cp; kwargs...)

Send a StatusNotification.

**V16 kwargs:** `connector_id::Int`, `status::OCPPData.V16.ChargePointStatus`,
`error_code::OCPPData.V16.ChargePointErrorCode`

**V201 kwargs:** `connector_id::Int`, `connector_status::OCPPData.V201.ConnectorStatus`,
`evse_id::Int`, `timestamp::String` (optional, defaults to now)
"""
function status_notification(cp::ChargePoint; kwargs...)
    return _status_notification(cp.spec, cp; kwargs...)
end

"""
    start_transaction(cp; connector_id, id_tag, meter_start, timestamp, kwargs...)

Send a StartTransaction (V16 only). Throws `OCPPVersionError` for V201 — use
`transaction_event` instead.
"""
function start_transaction(cp::ChargePoint; kwargs...)
    return _start_transaction(cp.spec, cp; kwargs...)
end

"""
    stop_transaction(cp; transaction_id, meter_stop, timestamp, kwargs...)

Send a StopTransaction (V16 only). Throws `OCPPVersionError` for V201 — use
`transaction_event` instead.
"""
function stop_transaction(cp::ChargePoint; kwargs...)
    return _stop_transaction(cp.spec, cp; kwargs...)
end

"""
    meter_values(cp; kwargs...)

Send MeterValues.

**V16 kwargs:** `connector_id::Int`, `meter_value::Vector{OCPPData.V16.MeterValue}`

**V201 kwargs:** `evse_id::Int`, `meter_value::Vector{OCPPData.V201.MeterValue}`
"""
function meter_values(cp::ChargePoint; kwargs...)
    return _meter_values(cp.spec, cp; kwargs...)
end

"""
    transaction_event(cp; event_type, seq_no, transaction_info, trigger_reason,
                      timestamp, kwargs...)

Send a TransactionEvent (V201 only). Throws `OCPPVersionError` for V16 — use
`start_transaction`/`stop_transaction` instead.
"""
function transaction_event(cp::ChargePoint; kwargs...)
    return _transaction_event(cp.spec, cp; kwargs...)
end
