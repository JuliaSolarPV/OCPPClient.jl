"""
    OCPPClient

OCPP WebSocket client for connecting to a Central System (CSMS).
Supports OCPP 1.6 with typed request/response handling.
"""
module OCPPClient

using Dates: Dates, DateTime, now, @dateformat_str
using HTTP
using JSON
using Logging
using OCPPData
using PrecompileTools
using UUIDs

include("events.jl")
include("charge_point.jl")
include("routing.jl")
include("transport.jl")
include("convenience.jl")

# Core types
export ChargePoint

# Lifecycle
export connect!, disconnect!, send_call

# Registration
export on!, subscribe!

# Events
export ClientEvent, Connected, Disconnected
export ServerCallReceived, ResponseReceived

# Errors
export OCPPTimeoutError, OCPPCallError

# Convenience methods
export boot_notification, heartbeat, authorize
export status_notification, start_transaction, stop_transaction
export meter_values

include("precompile.jl")

end
