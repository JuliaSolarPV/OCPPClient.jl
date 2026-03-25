@testmodule CPHelpers begin
    using OCPPClient
    using OCPPData

    function make_cp(; kwargs...)
        return ChargePoint("CP001", "ws://localhost:9000/ocpp"; kwargs...)
    end
end

@testitem "ChargePoint constructor defaults" tags = [:unit, :fast] setup = [CPHelpers] begin
    using OCPPData

    cp = CPHelpers.make_cp()
    @test cp.id == "CP001"
    @test cp.url == "ws://localhost:9000/ocpp"
    @test cp.ws === nothing
    @test cp.status == :disconnected
    @test isempty(cp.handlers)
    @test isempty(cp.listeners)
    @test isempty(cp.pending_calls)
    @test cp.spec isa OCPPData.V16.Spec
    @test cp.reconnect == true
    @test cp.reconnect_interval == 5.0
end

@testitem "ChargePoint custom spec" tags = [:unit, :fast] begin
    using OCPPClient
    using OCPPData

    cp = ChargePoint(
        "CP002",
        "ws://localhost:9000/ocpp";
        spec = OCPPData.V16.Spec(),
        reconnect = false,
        reconnect_interval = 10.0,
    )
    @test cp.spec isa OCPPData.V16.Spec
    @test cp.reconnect == false
    @test cp.reconnect_interval == 10.0
end

@testitem "on! registers handler" tags = [:unit, :fast] setup = [CPHelpers] begin
    using OCPPClient

    cp = CPHelpers.make_cp()
    handler = (cp, req) -> nothing
    on!(cp, "Reset", handler)
    @test haskey(cp.handlers, "Reset")
    @test cp.handlers["Reset"] === handler
end

@testitem "subscribe! registers listener" tags = [:unit, :fast] setup = [CPHelpers] begin
    using OCPPClient

    cp = CPHelpers.make_cp()
    events = []
    subscribe!(cp, e -> push!(events, e))
    @test length(cp.listeners) == 1
end

@testitem "_emit notifies listeners" tags = [:unit, :fast] setup = [CPHelpers] begin
    using OCPPClient
    using OCPPClient: _emit
    using Dates

    cp = CPHelpers.make_cp()
    events = []
    subscribe!(cp, e -> push!(events, e))
    _emit(cp, Connected(now(Dates.UTC)))
    @test length(events) == 1
    @test events[1] isa Connected
end

@testitem "ChargePoint V201 spec" tags = [:unit, :fast] begin
    using OCPPClient
    using OCPPData

    cp = ChargePoint("CP003", "ws://localhost:9000/ocpp"; spec = OCPPData.V201.Spec())
    @test cp.spec isa OCPPData.V201.Spec
    @test cp.status == :disconnected
end

@testitem "_emit handles listener errors" tags = [:unit, :fast] setup = [CPHelpers] begin
    using OCPPClient
    using OCPPClient: _emit
    using Dates

    cp = CPHelpers.make_cp()
    good_events = []
    subscribe!(cp, e -> error("boom"))
    subscribe!(cp, e -> push!(good_events, e))
    _emit(cp, Connected(now(Dates.UTC)))
    # Second listener still called despite first throwing
    @test length(good_events) == 1
end
