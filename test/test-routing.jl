@testitem "Handler dispatch returns CallResult" tags = [:unit, :fast] begin
    using OCPPClient
    using OCPPClient: _handle_server_call
    using OCPPData

    cp = ChargePoint("CP001", "ws://localhost:9000/ocpp")
    on!(cp, "Reset") do cp, req
        return OCPPData.V16.ResetResponse(; status = OCPPData.V16.GenericAccepted)
    end

    call = OCPPData.Call("test-id-1", "Reset", Dict{String,Any}("type" => "Soft"))
    result = _handle_server_call(cp, call)

    @test result isa OCPPData.CallResult
    @test result.unique_id == "test-id-1"
    @test result.payload["status"] == "Accepted"
end

@testitem "Missing handler returns NotImplemented" tags = [:unit, :fast] begin
    using OCPPClient
    using OCPPClient: _handle_server_call
    using OCPPData

    cp = ChargePoint("CP001", "ws://localhost:9000/ocpp")
    call = OCPPData.Call("test-id-2", "UnknownAction", Dict{String,Any}())
    result = _handle_server_call(cp, call)

    @test result isa OCPPData.CallError
    @test result.unique_id == "test-id-2"
    @test result.error_code == "NotImplemented"
end

@testitem "Throwing handler returns InternalError" tags = [:unit, :fast] begin
    using OCPPClient
    using OCPPClient: _handle_server_call
    using OCPPData

    cp = ChargePoint("CP001", "ws://localhost:9000/ocpp")
    on!(cp, "Reset") do cp, req
        error("handler crashed")
    end

    call = OCPPData.Call("test-id-3", "Reset", Dict{String,Any}("type" => "Soft"))
    result = _handle_server_call(cp, call)

    @test result isa OCPPData.CallError
    @test result.unique_id == "test-id-3"
    @test result.error_code == "InternalError"
    @test occursin("handler crashed", result.error_description)
end

@testitem "_response_type returns correct type for V16" tags = [:unit, :fast] begin
    using OCPPClient
    using OCPPClient: _response_type
    using OCPPData

    spec = OCPPData.V16.Spec()
    @test _response_type(spec, "BootNotification") === OCPPData.V16.BootNotificationResponse
    @test _response_type(spec, "Heartbeat") === OCPPData.V16.HeartbeatResponse
    @test _response_type(spec, "Reset") === OCPPData.V16.ResetResponse
end

@testitem "_response_type returns correct type for V201" tags = [:unit, :fast] begin
    using OCPPClient
    using OCPPClient: _response_type
    using OCPPData

    spec = OCPPData.V201.Spec()
    @test _response_type(spec, "BootNotification") ===
          OCPPData.V201.BootNotificationResponse
    @test _response_type(spec, "Heartbeat") === OCPPData.V201.HeartbeatResponse
    @test _response_type(spec, "Reset") === OCPPData.V201.ResetResponse
end

@testitem "V201 handler dispatch returns CallResult" tags = [:unit, :fast] begin
    using OCPPClient
    using OCPPClient: _handle_server_call
    using OCPPData

    cp = ChargePoint("CP001", "ws://localhost:9000/ocpp"; spec = OCPPData.V201.Spec())
    on!(cp, "Reset") do cp, req
        return OCPPData.V201.ResetResponse(; status = OCPPData.V201.ResetAccepted)
    end

    call = OCPPData.Call("v201-1", "Reset", Dict{String,Any}("type" => "Immediate"))
    result = _handle_server_call(cp, call)

    @test result isa OCPPData.CallResult
    @test result.unique_id == "v201-1"
    @test result.payload["status"] == "Accepted"
end
