# Architecture

OCPPClient.jl is organized into four layers. Each layer has a single responsibility, and the
layers interact only through well-defined interfaces.

## Layer overview

```text
┌──────────────────────────────────────────────────────┐
│  Convenience layer                                   │
│  convenience.jl + convenience_v16.jl / _v201.jl     │
│  boot_notification, heartbeat, authorize, …          │
├──────────────────────────────────────────────────────┤
│  Routing layer                                       │
│  routing.jl                                          │
│  _handle_server_call, action dispatch                │
├──────────────────────────────────────────────────────┤
│  Transport layer                                     │
│  transport.jl                                        │
│  connect!, disconnect!, send_call, WebSocket I/O     │
├──────────────────────────────────────────────────────┤
│  ChargePoint state                                   │
│  charge_point.jl                                     │
│  id, url, spec, status, handlers, listeners, …       │
└──────────────────────────────────────────────────────┘
```text

## ChargePoint state (`charge_point.jl`)

`ChargePoint` is a mutable struct that holds all runtime state:

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Charge point identifier |
| `url` | `String` | WebSocket URL |
| `ws` | `WebSocket \| Nothing` | Active WebSocket connection |
| `status` | `Symbol` | `:disconnected`, `:connected`, or `:booted` |
| `handlers` | `Dict{String, Function}` | Action → handler registered via `on!` |
| `listeners` | `Vector{Function}` | Event callbacks registered via `subscribe!` |
| `pending_calls` | `Dict{String, Channel}` | Awaited calls keyed by `unique_id` |
| `spec` | `AbstractOCPPSpec` | `V16.Spec()` or `V201.Spec()` |
| `reconnect` | `Bool` | Enable automatic reconnect |
| `reconnect_interval` | `Float64` | Seconds between reconnect attempts |
| `lock` | `ReentrantLock` | Guards all mutable fields |

`spec` is the central discriminator — every version-specific behaviour dispatches on its type
using Julia multiple dispatch.

## Transport layer (`transport.jl`)

### Connecting

`connect!(cp)` opens a WebSocket with the negotiated OCPP subprotocol:

```text
cp.spec = V16.Spec()   →  subprotocol = "ocpp1.6"
cp.spec = V201.Spec()  →  subprotocol = "ocpp2.0.1"
```text

On success the status is set to `:connected` and a `Connected` event is emitted.
If `reconnect = true`, the loop retries on disconnect.

### Sending a call

`send_call(cp, action, payload; timeout)` implements the client→server request/response cycle:

1. Generate a UUID `unique_id`
2. Encode the `Call` frame as JSON
3. Park a `Channel{OCPPMessage}(1)` in `cp.pending_calls[unique_id]`
4. Send the frame over the WebSocket
5. Start a `Timer` for the timeout; on expiry, remove the channel and throw `OCPPTimeoutError`
6. `take!` from the channel — the receive loop (below) deposits the matching reply

### Receiving messages

The receive loop runs inside `connect!`:

```text
for raw_frame in ws
    msg = OCPPData.decode(raw_frame)
    if msg isa Call         → routing layer (_handle_server_call)
    if msg isa CallResult   → resolve pending channel, emit ResponseReceived
    if msg isa CallError    → resolve pending channel, emit ResponseReceived
end
```text

## Routing layer (`routing.jl`)

`_handle_server_call(cp, call)` processes an incoming `Call` from the CSMS:

1. Look up `cp.handlers[call.action]`
2. If missing, return `CallError("NotImplemented")`
3. Deserialize `call.payload` to the typed request struct via
   `_request_type(cp.spec, call.action)` (dispatches to `V16.request_type` or
   `V201.request_type`)
4. Call the handler: `handler(cp, request)`
5. Serialize the response struct with `_to_payload`
6. Return `CallResult(call.unique_id, payload)`
7. On exception, return `CallError("InternalError", message)`

The `_request_type` / `_response_type` helpers are conditionally defined via
`OCPPData.ENABLE_V16` / `OCPPData.ENABLE_V201` guards, so only the compiled versions
are available at runtime.

## Convenience layer (`convenience.jl`, `convenience_v16.jl`, `convenience_v201.jl`)

### Shared helpers

- `_to_payload(obj)` — struct → `Dict{String,Any}` via JSON round-trip (camelCase keys)
- `_from_payload(T, payload)` — `Dict{String,Any}` → typed struct `T`
- `_send_typed(cp, action, request, ResponseT; timeout)` — wraps `send_call` +
  `_to_payload` + `_from_payload`; throws `OCPPCallError` if the server returns a
  `CallError` frame

### Public dispatch

Each public method (`boot_notification`, `heartbeat`, …) is a one-liner that dispatches
on `cp.spec`:

```julia
function boot_notification(cp::ChargePoint; kwargs...)
    return _boot_notification(cp.spec, cp; kwargs...)
end
```text

The private `_boot_notification(::V16.Spec, cp; ...)` and
`_boot_notification(::V201.Spec, cp; ...)` implementations live in the version-specific
files and are only included when the corresponding `ENABLE_*` flag is set.

### V16 / V201 selection at compile time

OCPPClient reads `OCPPData.ENABLE_V16` and `OCPPData.ENABLE_V201` (set via the
`protocol_version` Preferences.jl key in OCPPData) and conditionally includes
`convenience_v16.jl` and / or `convenience_v201.jl`. This mirrors OCPPData's own
conditional compilation pattern and ensures type-safety — V201 types are never
referenced when the package was compiled for V16 only.
