@testsnippet V201IntegrationSetup begin
    using HTTP
    using JSON
    using OCPPData
    using OCPPClient
    using Sockets: getsockname

    function get_port_v201(server)
        _, port = getsockname(server.listener.server)
        return Int(port)
    end

    function wait_for_status_v201(cp, expected::Symbol; timeout = 15.0)
        deadline = time() + timeout
        while time() < deadline
            cp.status == expected && return true
            sleep(0.1)
        end
        return cp.status == expected
    end

    """Mock server handling V201 convenience actions with appropriate responses."""
    function start_v201_mock_server()
        server = HTTP.WebSockets.listen!("127.0.0.1", 0) do ws
            for raw in ws
                msg = OCPPData.decode(String(raw))
                if msg isa OCPPData.Call
                    payload = if msg.action == "Authorize"
                        Dict{String,Any}(
                            "idTokenInfo" => Dict{String,Any}("status" => "Accepted"),
                        )
                    else
                        Dict{String,Any}()
                    end
                    HTTP.WebSockets.send(
                        ws,
                        OCPPData.encode(OCPPData.CallResult(msg.unique_id, payload)),
                    )
                end
            end
        end
        port = get_port_v201(server)
        return (server, port)
    end

    function make_v201_cp(port; id = "CP-V201-X")
        return ChargePoint(
            id,
            "ws://127.0.0.1:$port";
            spec = OCPPData.V201.Spec(),
            reconnect = false,
        )
    end
end

@testitem "V201 authorize" tags = [:integration, :slow] setup = [V201IntegrationSetup] begin
    server, port = start_v201_mock_server()
    try
        cp = make_v201_cp(port; id = "CP-V201-A01")
        conn_task = @async connect!(cp)
        wait_for_status_v201(cp, :connected)

        resp = authorize(
            cp;
            id_token = OCPPData.V201.IdToken(;
                id_token = "TAG001",
                type = OCPPData.V201.IdTokenISO14443,
            ),
        )
        @test resp isa OCPPData.V201.AuthorizeResponse

        disconnect!(cp)
    finally
        close(server)
    end
end

@testitem "V201 status_notification" tags = [:integration, :slow] setup = [V201IntegrationSetup] begin
    server, port = start_v201_mock_server()
    try
        cp = make_v201_cp(port; id = "CP-V201-S01")
        conn_task = @async connect!(cp)
        wait_for_status_v201(cp, :connected)

        resp = status_notification(
            cp;
            connector_id = 1,
            connector_status = OCPPData.V201.ConnectorAvailable,
            evse_id = 1,
        )
        @test resp isa OCPPData.V201.StatusNotificationResponse

        disconnect!(cp)
    finally
        close(server)
    end
end

@testitem "V201 transaction_event" tags = [:integration, :slow] setup = [V201IntegrationSetup] begin
    server, port = start_v201_mock_server()
    try
        cp = make_v201_cp(port; id = "CP-V201-TE01")
        conn_task = @async connect!(cp)
        wait_for_status_v201(cp, :connected)

        resp = transaction_event(
            cp;
            event_type = OCPPData.V201.Started,
            seq_no = 0,
            transaction_info = OCPPData.V201.Transaction(; transaction_id = "TXN001"),
            trigger_reason = OCPPData.V201.TriggerReasonAuthorized,
        )
        @test resp isa OCPPData.V201.TransactionEventResponse

        disconnect!(cp)
    finally
        close(server)
    end
end

@testitem "V201 meter_values" tags = [:integration, :slow] setup = [V201IntegrationSetup] begin
    server, port = start_v201_mock_server()
    try
        cp = make_v201_cp(port; id = "CP-V201-MV01")
        conn_task = @async connect!(cp)
        wait_for_status_v201(cp, :connected)

        mv = OCPPData.V201.MeterValue(;
            sampled_value = [OCPPData.V201.SampledValue(; value = 100.0)],
            timestamp = "2024-01-01T00:00:00.000Z",
        )
        resp = meter_values(cp; evse_id = 1, meter_value = [mv])
        @test resp isa OCPPData.V201.MeterValuesResponse

        disconnect!(cp)
    finally
        close(server)
    end
end
