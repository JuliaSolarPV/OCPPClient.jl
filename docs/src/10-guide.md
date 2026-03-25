# User guide

## Connecting to a CSMS

Create a `ChargePoint` with a charge point ID and WebSocket URL. The charge point is created in
the `:disconnected` state — no network activity happens yet.

```julia
using OCPPClient

cp = ChargePoint(
    "CP001",                          # charge point identifier (used in the WS path)
    "ws://csms.example.com/ocpp/CP001";
    reconnect = true,                 # reconnect automatically on disconnect (default)
    reconnect_interval = 5.0,         # seconds between reconnect attempts (default)
)
```

Call `connect!` to open the WebSocket. Because the OCPP message loop runs inside the connection,
`connect!` is a blocking call — wrap it in `@async` to continue using the REPL or run other tasks:

```julia
conn_task = @async connect!(cp)

# Poll until connected
while cp.status != :connected
    sleep(0.1)
end
```

`cp.status` transitions through:

| Value | Meaning |
|-------|---------|
| `:disconnected` | Not connected |
| `:connected` | WebSocket open, messages flowing |
| `:booted` | `BootNotification` accepted by CSMS |

To close the connection:

```julia
disconnect!(cp)
```

## Sending requests

All convenience methods send an OCPP request and **block** until the response arrives (default
timeout: 30 seconds). They return a typed response struct from OCPPData.jl.

### BootNotification

```julia-repl
# OCPP 1.6
julia> resp = boot_notification(cp; charge_point_vendor = "ACME", charge_point_model = "X1")
OCPPData.V16.BootNotificationResponse("2026-03-25T18:14:54.903Z", 14400, OCPPData.V16.RegistrationPending)

julia> resp.status
OCPPData.V16.RegistrationPending
```

```julia
# OCPP 2.0.1
resp = boot_notification(
    cp;
    reason = OCPPData.V201.BootReasonPowerUp,
    charging_station = OCPPData.V201.ChargingStation(; model = "X1", vendor_name = "ACME"),
)
```

Calling `boot_notification` also sets `cp.status = :booted` when the CSMS accepts with
`RegistrationAccepted`. The exact status returned depends on the CSMS configuration.

### Heartbeat

```julia-repl
julia> resp = heartbeat(cp)
OCPPData.V16.HeartbeatResponse("2026-03-25T18:14:55.070Z")

julia> resp.current_time
"2026-03-25T18:14:55.070Z"
```

### Authorize

```julia-repl
# OCPP 1.6
julia> resp = authorize(cp; id_tag = "TAG002")
OCPPData.V16.AuthorizeResponse(OCPPData.V16.IdTagInfo(OCPPData.V16.AuthorizationAccepted, "2026-03-25T19:14:55.207Z", nothing))

julia> resp.id_tag_info.status
OCPPData.V16.AuthorizationAccepted
```

```julia
# OCPP 2.0.1
resp = authorize(cp; id_token = OCPPData.V201.IdToken(; id_token = "TAG002", type = OCPPData.V201.ISO14443))
```

### StatusNotification

```julia-repl
# OCPP 1.6
julia> status_notification(
           cp;
           connector_id = 1,
           status = OCPPData.V16.ChargePointAvailable,
           error_code = OCPPData.V16.NoError,
       )
OCPPData.V16.StatusNotificationResponse()
```

```julia
# OCPP 2.0.1
status_notification(
    cp;
    connector_id = 1,
    evse_id = 1,
    connector_status = OCPPData.V201.Available,
)
```

### MeterValues

```julia
# OCPP 1.6
meter_values(cp; connector_id = 1, meter_value = OCPPData.V16.MeterValue[])

# OCPP 2.0.1
meter_values(cp; evse_id = 1, meter_value = OCPPData.V201.MeterValue[])
```

### Transactions

**OCPP 1.6** uses separate start and stop calls:

```julia-repl
julia> resp = start_transaction(cp; connector_id = 1, id_tag = "TAG002", meter_start = 0)
OCPPData.V16.StartTransactionResponse(OCPPData.V16.IdTagInfo(OCPPData.V16.AuthorizationAccepted, "2026-03-25T19:14:55.531Z", nothing), 4)

julia> resp.transaction_id
4

julia> stop_transaction(cp; transaction_id = resp.transaction_id, meter_stop = 1234)
OCPPData.V16.StopTransactionResponse(nothing)
```

**OCPP 2.0.1** uses a unified `TransactionEvent`:

```julia
transaction_event(
    cp;
    event_type = OCPPData.V201.Started,
    seq_no = 0,
    transaction_info = OCPPData.V201.Transaction(; transaction_id = "txn-001"),
    trigger_reason = OCPPData.V201.Authorized,
)
```

Calling `start_transaction` or `stop_transaction` on a V201 charge point throws `OCPPVersionError`.
Calling `transaction_event` on a V16 charge point also throws `OCPPVersionError`.

### Raw send

For actions not covered by a convenience method, use `send_call` directly:

```julia
result = send_call(cp, "DataTransfer", Dict{String,Any}("vendorId" => "ACME"); timeout = 10.0)
# result is OCPPData.CallResult or OCPPData.CallError
```

## Handling server-initiated calls

The CSMS can send `Call` messages at any time (e.g., `Reset`, `ChangeConfiguration`). Register
handlers with `on!` using do-block syntax:

```julia
on!(cp, "Reset") do cp, req
    @info "Reset requested" type=req.type
    return OCPPData.V16.ResetResponse(; status = OCPPData.V16.GenericAccepted)
end
```

The handler receives:
- `cp` — the `ChargePoint`, so you can send further requests from the handler
- `req` — a typed request struct (e.g., `OCPPData.V16.ResetRequest`)

The handler **must return** a typed response struct. OCPPClient serializes it automatically.

If no handler is registered for an action, the client replies with a `CallError` frame using
error code `"NotImplemented"`. If the handler throws an exception, the client replies with
`"InternalError"` and logs the stack trace.

## Event subscriptions

Subscribe to lifecycle events with `subscribe!`:

```julia
subscribe!(cp) do event
    if event isa Connected
        @info "Connected at" event.timestamp
    elseif event isa Disconnected
        @info "Disconnected" reason=event.reason
    end
end
```

Available event types:

| Type | Fields | When fired |
|------|--------|------------|
| `Connected` | `timestamp` | WebSocket opened |
| `Disconnected` | `timestamp`, `reason::Symbol` | WebSocket closed |
| `ServerCallReceived` | `action`, `message`, `timestamp` | Incoming `Call` from CSMS |
| `ResponseReceived` | `action`, `message`, `timestamp` | Incoming `CallResult`/`CallError` from CSMS |

## V16 vs V201

Select the protocol version via the `spec` keyword:

```julia
# OCPP 1.6 (default)
cp16 = ChargePoint("CP-V16", "ws://csms.example.com/ocpp/CP-V16")

# OCPP 2.0.1
cp201 = ChargePoint(
    "CP-V201",
    "ws://csms.example.com/ocpp/CP-V201";
    spec = OCPPData.V201.Spec(),
)
```

Key API differences:

| Method | V16 kwargs | V201 kwargs |
|--------|------------|-------------|
| `boot_notification` | `charge_point_vendor`, `charge_point_model` | `reason::BootReason`, `charging_station::ChargingStation` |
| `authorize` | `id_tag::String` | `id_token::IdToken` |
| `status_notification` | `connector_id`, `status`, `error_code` | `connector_id`, `evse_id`, `connector_status` |
| `meter_values` | `connector_id`, `meter_value` | `evse_id`, `meter_value` |
| Transactions | `start_transaction` / `stop_transaction` | `transaction_event` |

The WebSocket subprotocol is negotiated automatically (`"ocpp1.6"` for V16, `"ocpp2.0.1"` for V201).

To compile OCPPClient with only one protocol version, set the `protocol_version` preference in
OCPPData.jl (see
[OCPPData.jl docs](https://JuliaSolarPV.github.io/OCPPData.jl) for details). OCPPClient reads
`OCPPData.ENABLE_V16` and `OCPPData.ENABLE_V201` and conditionally includes the corresponding
files at compile time.

## Error handling

| Exception | When thrown |
|-----------|-------------|
| `OCPPTimeoutError` | Server did not reply within the timeout |
| `OCPPCallError` | Server replied with a `CallError` frame |
| `OCPPVersionError` | Called a method incompatible with `cp.spec` |

```julia
try
    resp = heartbeat(cp; timeout = 5.0)
catch e
    if e isa OCPPTimeoutError
        @warn "Heartbeat timed out"
    elseif e isa OCPPCallError
        @error "CSMS error" code=e.error_code description=e.error_description
    end
end
```

`OCPPCallError` fields: `error_code::String`, `error_description::String`,
`error_details::Dict{String,Any}`.
