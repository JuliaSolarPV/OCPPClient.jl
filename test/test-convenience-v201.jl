@testmodule CPV201Helpers begin
    using OCPPClient
    using OCPPData

    function make_cp_v201(; kwargs...)
        return ChargePoint(
            "CP-V201",
            "ws://localhost:9000/ocpp";
            spec = OCPPData.V201.Spec(),
            kwargs...,
        )
    end
end

@testitem "_to_payload V201 BootNotificationRequest" tags = [:unit, :fast] setup =
    [CPV201Helpers] begin
    using OCPPClient: _to_payload
    using OCPPData

    req = OCPPData.V201.BootNotificationRequest(;
        reason = OCPPData.V201.BootReasonPowerUp,
        charging_station = OCPPData.V201.ChargingStation(;
            model = "TestModel",
            vendor_name = "TestVendor",
        ),
    )
    payload = _to_payload(req)
    @test payload isa Dict{String,Any}
    @test haskey(payload, "reason")
    @test haskey(payload, "chargingStation")
    @test payload["chargingStation"]["model"] == "TestModel"
    @test payload["chargingStation"]["vendorName"] == "TestVendor"
end

@testitem "_from_payload V201 BootNotificationResponse" tags = [:unit, :fast] setup =
    [CPV201Helpers] begin
    using OCPPClient: _from_payload
    using OCPPData

    payload = Dict{String,Any}(
        "currentTime" => "2024-01-01T00:00:00.000Z",
        "interval" => 300,
        "status" => "Accepted",
    )
    resp = _from_payload(OCPPData.V201.BootNotificationResponse, payload)
    @test resp isa OCPPData.V201.BootNotificationResponse
    @test resp.status == OCPPData.V201.RegistrationAccepted
    @test resp.interval == 300
end

@testitem "_to_payload V201 HeartbeatRequest" tags = [:unit, :fast] setup = [CPV201Helpers] begin
    using OCPPClient: _to_payload
    using OCPPData

    payload = _to_payload(OCPPData.V201.HeartbeatRequest())
    @test payload isa Dict{String,Any}
end

@testitem "_from_payload V201 HeartbeatResponse" tags = [:unit, :fast] setup =
    [CPV201Helpers] begin
    using OCPPClient: _from_payload
    using OCPPData

    resp = _from_payload(
        OCPPData.V201.HeartbeatResponse,
        Dict{String,Any}("currentTime" => "2024-01-01T00:00:00.000Z"),
    )
    @test resp isa OCPPData.V201.HeartbeatResponse
    @test resp.current_time == "2024-01-01T00:00:00.000Z"
end

@testitem "OCPPVersionError on start_transaction with V201 spec" tags = [:unit, :fast] setup =
    [CPV201Helpers] begin
    using OCPPClient

    cp = CPV201Helpers.make_cp_v201()
    @test_throws OCPPVersionError start_transaction(
        cp;
        connector_id = 1,
        id_tag = "TAG001",
        meter_start = 0,
    )
end

@testitem "OCPPVersionError on stop_transaction with V201 spec" tags = [:unit, :fast] setup =
    [CPV201Helpers] begin
    using OCPPClient

    cp = CPV201Helpers.make_cp_v201()
    @test_throws OCPPVersionError stop_transaction(cp; transaction_id = 1, meter_stop = 100)
end

@testitem "OCPPVersionError on transaction_event with V16 spec" tags = [:unit, :fast] begin
    using OCPPClient
    using OCPPData

    cp = ChargePoint("CP-V16", "ws://localhost:9000/ocpp")
    @test_throws OCPPVersionError transaction_event(cp; event_type = "Started")
end
