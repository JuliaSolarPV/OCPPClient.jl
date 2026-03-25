"""
    OCPPClient

OCPP WebSocket client for connecting to a Central System (CSMS).
Supports OCPP 1.6 and 2.0.1 with typed request/response handling.
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
if OCPPData.ENABLE_V16
    include("convenience_v16.jl")
end
if OCPPData.ENABLE_V201
    include("convenience_v201.jl")
end

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
export OCPPTimeoutError, OCPPCallError, OCPPVersionError

# Convenience methods
export boot_notification, heartbeat, authorize
export status_notification, start_transaction, stop_transaction
export meter_values, transaction_event

include("precompile.jl")

end
