@testitem "_to_payload produces camelCase Dict" tags = [:unit, :fast] begin
    using OCPPClient: _to_payload
    using OCPPData

    req = OCPPData.V16.BootNotificationRequest(;
        charge_point_vendor = "TestVendor",
        charge_point_model = "TestModel",
    )
    payload = _to_payload(req)

    @test payload isa Dict{String,Any}
    @test payload["chargePointVendor"] == "TestVendor"
    @test payload["chargePointModel"] == "TestModel"
    @test !haskey(payload, "charge_point_vendor")
end

@testitem "_from_payload round-trips correctly" tags = [:unit, :fast] begin
    using OCPPClient: _to_payload, _from_payload
    using OCPPData

    req = OCPPData.V16.BootNotificationRequest(;
        charge_point_vendor = "V1",
        charge_point_model = "M1",
        firmware_version = "1.0",
    )
    payload = _to_payload(req)
    req2 = _from_payload(OCPPData.V16.BootNotificationRequest, payload)

    @test req2.charge_point_vendor == "V1"
    @test req2.charge_point_model == "M1"
    @test req2.firmware_version == "1.0"
end

@testitem "_from_payload handles response types" tags = [:unit, :fast] begin
    using OCPPClient: _from_payload
    using OCPPData

    payload = Dict{String,Any}(
        "currentTime" => "2024-01-01T00:00:00Z",
        "interval" => 300,
        "status" => "Accepted",
    )
    resp = _from_payload(OCPPData.V16.BootNotificationResponse, payload)

    @test resp.current_time == "2024-01-01T00:00:00Z"
    @test resp.interval == 300
    @test resp.status == OCPPData.V16.RegistrationAccepted
end

@testitem "Event types construct correctly" tags = [:unit, :fast] begin
    using OCPPClient
    using OCPPData
    using Dates

    ts = now(Dates.UTC)

    c = Connected(ts)
    @test c.timestamp == ts

    d = Disconnected(ts, :normal)
    @test d.reason == :normal

    call = OCPPData.Call("id1", "Reset", Dict{String,Any}())
    scr = ServerCallReceived("Reset", call, ts)
    @test scr.action == "Reset"

    result = OCPPData.CallResult("id2", Dict{String,Any}())
    rr = ResponseReceived("", result, ts)
    @test rr.message isa OCPPData.CallResult
end

@testitem "OCPPCallError formats correctly" tags = [:unit, :fast] begin
    using OCPPClient

    e = OCPPCallError("NotSupported", "Action not supported", Dict{String,Any}())
    buf = IOBuffer()
    showerror(buf, e)
    msg = String(take!(buf))
    @test occursin("NotSupported", msg)
    @test occursin("Action not supported", msg)
end

@testitem "OCPPTimeoutError formats correctly" tags = [:unit, :fast] begin
    using OCPPClient

    e = OCPPTimeoutError("connection timed out")
    buf = IOBuffer()
    showerror(buf, e)
    msg = String(take!(buf))
    @test occursin("OCPPTimeoutError", msg)
    @test occursin("connection timed out", msg)
end

@testitem "OCPPVersionError formats correctly" tags = [:unit, :fast] begin
    using OCPPClient

    e = OCPPVersionError("V16 only")
    buf = IOBuffer()
    showerror(buf, e)
    msg = String(take!(buf))
    @test occursin("OCPPVersionError", msg)
    @test occursin("V16 only", msg)
end
