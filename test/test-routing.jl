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
