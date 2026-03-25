```@meta
CurrentModule = OCPPClient
```

# OCPPClient.jl

OCPPClient.jl is a Julia WebSocket client for OCPP (Open Charge Point Protocol) charge points.
It connects a charge point to a Central System Management Software (CSMS), handles the
full OCPP-J message exchange, and exposes a typed Julia API so you never have to touch raw JSON.
Built on top of [HTTP.jl](https://github.com/JuliaWeb/HTTP.jl) and
[OCPPData.jl](https://github.com/JuliaSolarPV/OCPPData.jl).

## Features

- **OCPP 1.6 and 2.0.1** — select the protocol version with the `spec` keyword
- **Typed request/response API** — `boot_notification`, `heartbeat`, `authorize`, and more;
  no manual JSON serialization required
- **Server-call dispatch** — register handlers with `on!` for server-initiated actions
  such as `Reset` or `ChangeConfiguration`
- **Event subscriptions** — observe connection lifecycle events with `subscribe!`
- **Automatic reconnect** — configurable reconnect interval (disabled for tests)
- **Structured errors** — `OCPPTimeoutError`, `OCPPCallError`, `OCPPVersionError`

## Quick start

```julia-repl
julia> using OCPPClient, OCPPData

julia> cp = ChargePoint("CP-TEST-001", "ws://localhost:8180/steve/websocket/CentralSystemService")
ChargePoint("CP-TEST-001", ...)

julia> on!(cp, "Reset") do cp, req
           return OCPPData.V16.ResetResponse(; status = OCPPData.V16.GenericAccepted)
       end

julia> conn_task = @async connect!(cp)

julia> while cp.status != :connected; sleep(0.1); end

julia> resp = boot_notification(cp; charge_point_vendor = "ACME", charge_point_model = "X1")
OCPPData.V16.BootNotificationResponse("2026-03-25T18:14:54.903Z", 14400, OCPPData.V16.RegistrationPending)

julia> heartbeat(cp)
OCPPData.V16.HeartbeatResponse("2026-03-25T18:14:55.070Z")

julia> disconnect!(cp)
```

## Package structure

```text
OCPPClient.jl/
├── src/
│   ├── OCPPClient.jl        # Module entry point, exports
│   ├── charge_point.jl      # ChargePoint struct, on!, subscribe!
│   ├── events.jl            # ClientEvent types, error types
│   ├── transport.jl         # connect!, disconnect!, send_call, WebSocket I/O
│   ├── routing.jl           # _handle_server_call, server-call dispatch
│   ├── convenience.jl       # Shared helpers + public dispatch layer
│   ├── convenience_v16.jl   # OCPP 1.6 typed convenience methods
│   ├── convenience_v201.jl  # OCPP 2.0.1 typed convenience methods
│   └── precompile.jl        # PrecompileTools workloads (TTFX reduction)
├── test/
│   ├── runtests.jl
│   ├── test-charge-point.jl
│   ├── test-routing.jl
│   ├── test-convenience-v201.jl
│   └── test-integration.jl
└── docs/
    └── src/                 # This documentation
```

## Contributors

```@raw html
<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->
```
