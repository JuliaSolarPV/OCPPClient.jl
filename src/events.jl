"""
Client-side event types and custom error types for OCPPClient.
"""

# ── Event types ──

abstract type ClientEvent end

struct Connected <: ClientEvent
    timestamp::DateTime
end

struct Disconnected <: ClientEvent
    timestamp::DateTime
    reason::Symbol  # :normal, :error, :timeout
end

struct ServerCallReceived <: ClientEvent
    action::String
    message::OCPPData.Call
    timestamp::DateTime
end

struct ResponseReceived <: ClientEvent
    action::String
    message::OCPPData.OCPPMessage  # CallResult or CallError
    timestamp::DateTime
end

# ── Error types ──

struct OCPPTimeoutError <: Exception
    msg::String
end

function Base.showerror(io::IO, e::OCPPTimeoutError)
    return print(io, "OCPPTimeoutError: ", e.msg)
end

struct OCPPCallError <: Exception
    error_code::String
    error_description::String
    error_details::Dict{String,Any}
end

function Base.showerror(io::IO, e::OCPPCallError)
    return print(io, "OCPPCallError: [", e.error_code, "] ", e.error_description)
end
