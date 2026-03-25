@testsnippet IntegrationSetup begin
    using HTTP
    using JSON
    using OCPPData
    using OCPPClient
    using Dates
    using Sockets: getsockname

    """Get the actual bound port from an HTTP server started with port=0."""
    function get_port(server)
        _, port = getsockname(server.listener.server)
        return Int(port)
    end

    """Wait until cp.status matches expected, with timeout."""
    function wait_for_status(cp, expected::Symbol; timeout = 5.0)
        deadline = time() + timeout
        while time() < deadline
            cp.status == expected && return true
            sleep(0.1)
        end
        return cp.status == expected
    end

    """
    Start a mock OCPP WebSocket server that handles BootNotification and
    Heartbeat. Returns (server, port).
    """
    function start_mock_server()
        server = HTTP.WebSockets.listen!("127.0.0.1", 0) do ws
            for raw in ws
                msg = OCPPData.decode(String(raw))
                if msg isa OCPPData.Call
                    response = if msg.action == "BootNotification"
                        OCPPData.CallResult(
                            msg.unique_id,
                            Dict{String,Any}(
                                "currentTime" => "2024-01-01T00:00:00Z",
                                "interval" => 300,
                                "status" => "Accepted",
                            ),
                        )
                    elseif msg.action == "Heartbeat"
                        OCPPData.CallResult(
                            msg.unique_id,
                            Dict{String,Any}("currentTime" => "2024-01-01T00:00:00Z"),
                        )
                    else
                        OCPPData.CallResult(msg.unique_id, Dict{String,Any}())
                    end
                    HTTP.WebSockets.send(ws, OCPPData.encode(response))
                end
            end
        end
        port = get_port(server)
        return (server, port)
    end
end

@testitem "Connect and send BootNotification" tags = [:integration, :slow] setup =
    [IntegrationSetup] begin
    server, port = start_mock_server()
    try
        cp = ChargePoint("CP-TEST-001", "ws://127.0.0.1:$port"; reconnect = false)

        conn_task = @async connect!(cp)
        @test wait_for_status(cp, :connected)

        resp = boot_notification(
            cp;
            charge_point_vendor = "TestVendor",
            charge_point_model = "TestModel",
        )
        @test resp isa OCPPData.V16.BootNotificationResponse
        @test resp.status == OCPPData.V16.RegistrationAccepted
        @test resp.interval == 300
        @test cp.status == :booted

        disconnect!(cp)
        sleep(0.5)
        @test cp.status == :disconnected
    finally
        close(server)
    end
end

@testitem "Send Heartbeat" tags = [:integration, :slow] setup = [IntegrationSetup] begin
    server, port = start_mock_server()
    try
        cp = ChargePoint("CP-TEST-002", "ws://127.0.0.1:$port"; reconnect = false)
        conn_task = @async connect!(cp)
        wait_for_status(cp, :connected)

        resp = heartbeat(cp)
        @test resp isa OCPPData.V16.HeartbeatResponse
        @test resp.current_time == "2024-01-01T00:00:00Z"

        disconnect!(cp)
    finally
        close(server)
    end
end

@testitem "Server-initiated call dispatches to handler" tags = [:integration, :slow] setup =
    [IntegrationSetup] begin
    received_action = Ref("")

    server = HTTP.WebSockets.listen!("127.0.0.1", 0) do ws
        # Wait for client to connect, then send a Reset
        sleep(1.0)
        reset_call =
            OCPPData.Call("server-1", "Reset", Dict{String,Any}("type" => "Soft"))
        HTTP.WebSockets.send(ws, OCPPData.encode(reset_call))

        # Read the response
        raw = HTTP.WebSockets.receive(ws)
        msg = OCPPData.decode(String(raw))
        @test msg isa OCPPData.CallResult
        @test msg.unique_id == "server-1"
        @test msg.payload["status"] == "Accepted"
    end
    port = get_port(server)

    try
        cp = ChargePoint("CP-TEST-003", "ws://127.0.0.1:$port"; reconnect = false)

        on!(cp, "Reset") do cp, req
            received_action[] = "Reset"
            return OCPPData.V16.ResetResponse(; status = OCPPData.V16.GenericAccepted)
        end

        conn_task = @async connect!(cp)
        sleep(2.5)

        @test received_action[] == "Reset"

        disconnect!(cp)
    finally
        close(server)
    end
end

@testitem "send_call timeout" tags = [:integration, :slow] setup = [IntegrationSetup] begin
    # Server that never responds
    server = HTTP.WebSockets.listen!("127.0.0.1", 0) do ws
        for _ in ws
            # Do nothing — don't respond
        end
    end
    port = get_port(server)

    try
        cp = ChargePoint("CP-TEST-004", "ws://127.0.0.1:$port"; reconnect = false)
        conn_task = @async connect!(cp)
        wait_for_status(cp, :connected)

        @test_throws OCPPTimeoutError send_call(
            cp,
            "Heartbeat",
            Dict{String,Any}();
            timeout = 1.0,
        )

        disconnect!(cp)
    finally
        close(server)
    end
end

@testitem "Event subscription fires on connect/disconnect" tags = [:integration, :slow] setup =
    [IntegrationSetup] begin
    server, port = start_mock_server()
    try
        cp = ChargePoint("CP-TEST-005", "ws://127.0.0.1:$port"; reconnect = false)

        events = []
        subscribe!(cp, e -> push!(events, e))

        conn_task = @async connect!(cp)
        wait_for_status(cp, :connected)

        disconnect!(cp)
        sleep(0.5)

        event_types = [typeof(e) for e in events]
        @test Connected in event_types
        @test Disconnected in event_types
    finally
        close(server)
    end
end
