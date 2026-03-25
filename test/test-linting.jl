@testitem "Aqua" tags = [:linting] begin
    using Aqua: Aqua
    using OCPPClient
    Aqua.test_all(OCPPClient)
end

@testitem "JET" tags = [:linting] begin
    if v"1.12" <= VERSION < v"1.13"
        using JET: JET
        using OCPPClient
        using Dates: DateTime

        # Test specific entry points instead of test_package to avoid OOM.
        # OCPPData generates 500+ types from JSON schemas; analyzing the full
        # package via JET.test_package exhausts memory.
        jet_target = (target_modules = (OCPPClient,),)

        # Core constructor
        JET.test_call(ChargePoint, (String, String); jet_target...)

        # Lifecycle (type-level analysis only, no actual connection)
        JET.test_call(disconnect!, (ChargePoint,); jet_target...)
        JET.test_call(send_call, (ChargePoint, String, Dict{String,Any}); jet_target...)

        # Registration
        JET.test_call(on!, (ChargePoint, String, Function); jet_target...)
        JET.test_call(subscribe!, (ChargePoint, Function); jet_target...)

        # Event constructors
        JET.test_call(Connected, (DateTime,); jet_target...)
        JET.test_call(Disconnected, (DateTime, Symbol); jet_target...)

        # Error constructors & display
        JET.test_call(OCPPTimeoutError, (String,); jet_target...)
        JET.test_call(OCPPCallError, (String, String, Dict{String,Any}); jet_target...)
        JET.test_call(OCPPVersionError, (String,); jet_target...)
        JET.test_call(Base.showerror, (IO, OCPPTimeoutError); jet_target...)
        JET.test_call(Base.showerror, (IO, OCPPCallError); jet_target...)
        JET.test_call(Base.showerror, (IO, OCPPVersionError); jet_target...)

        # Note: convenience dispatch methods (boot_notification, heartbeat, etc.)
        # are excluded — they fan out into both V16 and V201 OCPPData type
        # hierarchies (500+ generated types), which exhausts memory.
    end
end
