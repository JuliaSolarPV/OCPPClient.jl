# OCPPClient.jl

[![Development documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaSolarPV.github.io/OCPPClient.jl/dev)
[![Test workflow status](https://github.com/JuliaSolarPV/OCPPClient.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/JuliaSolarPV/OCPPClient.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaSolarPV/OCPPClient.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaSolarPV/OCPPClient.jl)
[![Lint workflow Status](https://github.com/JuliaSolarPV/OCPPClient.jl/actions/workflows/Lint.yml/badge.svg?branch=main)](https://github.com/JuliaSolarPV/OCPPClient.jl/actions/workflows/Lint.yml?query=branch%3Amain)
[![Docs workflow Status](https://github.com/JuliaSolarPV/OCPPClient.jl/actions/workflows/Docs.yml/badge.svg?branch=main)](https://github.com/JuliaSolarPV/OCPPClient.jl/actions/workflows/Docs.yml?query=branch%3Amain)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![BestieTemplate](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/JuliaBesties/BestieTemplate.jl/main/docs/src/assets/badge.json)](https://github.com/JuliaBesties/BestieTemplate.jl)

OCPPClient.jl is a Julia WebSocket client for [OCPP](https://www.openchargealliance.org/) (Open
Charge Point Protocol) charge points. It connects a charge point to a Central System Management
Software (CSMS) and provides a typed Julia API for all common OCPP actions — no manual JSON
required. Built on [HTTP.jl](https://github.com/JuliaWeb/HTTP.jl) and
[OCPPData.jl](https://github.com/JuliaSolarPV/OCPPData.jl).

- **OCPP 1.6 and 2.0.1** — select the protocol version with the `spec` keyword
- **Typed request/response API** — `boot_notification`, `heartbeat`, `authorize`, and more
- **Server-call dispatch** — register handlers with `on!` for server-initiated actions
- **Event subscriptions** — observe connection lifecycle with `subscribe!`
- **Automatic reconnect** — configurable reconnect interval
- **Structured errors** — `OCPPTimeoutError`, `OCPPCallError`, `OCPPVersionError`

## Example Usage

```julia
julia> using OCPPClient, OCPPData

julia> cp = ChargePoint("CP001", "ws://csms.example.com/ocpp/CP001")
ChargePoint("CP001", ...)

# Register a handler for server-initiated Reset calls
julia> on!(cp, "Reset") do cp, req
           return OCPPData.V16.ResetResponse(; status = OCPPData.V16.GenericAccepted)
       end

# Connect in the background
julia> conn_task = @async connect!(cp)

julia> while cp.status != :connected; sleep(0.1); end

# Send BootNotification
julia> resp = boot_notification(cp; charge_point_vendor = "ACME", charge_point_model = "X1")
OCPPData.V16.BootNotificationResponse("2026-03-25T18:14:54.903Z", 14400, OCPPData.V16.RegistrationPending)

julia> heartbeat(cp)
OCPPData.V16.HeartbeatResponse("2026-03-25T18:14:55.070Z")
```

### Transactions (OCPP 1.6)

```julia
julia> resp = start_transaction(cp; connector_id = 1, id_tag = "TAG002", meter_start = 0)
OCPPData.V16.StartTransactionResponse(OCPPData.V16.IdTagInfo(OCPPData.V16.AuthorizationAccepted, "2026-03-25T19:14:55.531Z", nothing), 4)

julia> stop_transaction(cp; transaction_id = resp.transaction_id, meter_stop = 1234)
OCPPData.V16.StopTransactionResponse(nothing)
```

### OCPP 2.0.1

```julia
julia> cp = ChargePoint(
           "CP001",
           "ws://csms.example.com/ocpp/CP001";
           spec = OCPPData.V201.Spec(),
       )

julia> resp = boot_notification(
           cp;
           reason = OCPPData.V201.BootReasonPowerUp,
           charging_station = OCPPData.V201.ChargingStation(; model = "X1", vendor_name = "ACME"),
       )

julia> transaction_event(
           cp;
           event_type = OCPPData.V201.Started,
           seq_no = 0,
           transaction_info = OCPPData.V201.Transaction(; transaction_id = "txn-001"),
           trigger_reason = OCPPData.V201.Authorized,
       )
```

### Event subscriptions

```julia
julia> subscribe!(cp) do event
           if event isa Connected
               @info "Connected" timestamp = event.timestamp
           elseif event isa Disconnected
               @info "Disconnected" reason = event.reason
           end
       end
```

## How to Cite

If you use OCPPClient.jl in your work, please cite using the reference given in [CITATION.cff](https://github.com/JuliaSolarPV/OCPPClient.jl/blob/main/CITATION.cff).

## Contributing

If you want to make contributions of any kind, please first take a look into our [contributing guide directly on GitHub](docs/src/90-contributing.md) or the [contributing page on the website](https://JuliaSolarPV.github.io/OCPPClient.jl/dev/90-contributing/).
