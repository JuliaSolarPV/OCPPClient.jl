@testsnippet V16IntegrationSetup begin
    using HTTP
    using JSON
    using OCPPData
    using OCPPClient
    using Sockets: getsockname

    function get_port_v16(server)
        _, port = getsockname(server.listener.server)
        return Int(port)
    end

    function wait_for_status_v16(cp, expected::Symbol; timeout = 15.0)
        deadline = time() + timeout
        while time() < deadline
            cp.status == expected && return true
            sleep(0.1)
        end
        return cp.status == expected
    end

    """Mock server handling V16 convenience actions with appropriate responses."""
    function start_v16_mock_server()
        server = HTTP.WebSockets.listen!("127.0.0.1", 0) do ws
            for raw in ws
                msg = OCPPData.decode(String(raw))
                if msg isa OCPPData.Call
                    payload = if msg.action == "Authorize"
                        Dict{String,Any}(
                            "idTagInfo" => Dict{String,Any}("status" => "Accepted"),
                        )
                    elseif msg.action == "StartTransaction"
                        Dict{String,Any}(
                            "transactionId" => 42,
                            "idTagInfo" => Dict{String,Any}("status" => "Accepted"),
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
        port = get_port_v16(server)
        return (server, port)
    end
end

@testitem "V16 authorize" tags = [:integration, :slow] setup = [V16IntegrationSetup] begin
    server, port = start_v16_mock_server()
    try
        cp = ChargePoint("CP-V16-A01", "ws://127.0.0.1:$port"; reconnect = false)
        conn_task = @async connect!(cp)
        wait_for_status_v16(cp, :connected)

        resp = authorize(cp; id_tag = "TAG001")
        @test resp isa OCPPData.V16.AuthorizeResponse

        disconnect!(cp)
    finally
        close(server)
    end
end

@testitem "V16 status_notification" tags = [:integration, :slow] setup =
    [V16IntegrationSetup] begin
    server, port = start_v16_mock_server()
    try
        cp = ChargePoint("CP-V16-S01", "ws://127.0.0.1:$port"; reconnect = false)
        conn_task = @async connect!(cp)
        wait_for_status_v16(cp, :connected)

        resp = status_notification(
            cp;
            connector_id = 1,
            status = OCPPData.V16.ChargePointAvailable,
            error_code = OCPPData.V16.NoError,
        )
        @test resp isa OCPPData.V16.StatusNotificationResponse

        disconnect!(cp)
    finally
        close(server)
    end
end

@testitem "V16 start_transaction" tags = [:integration, :slow] setup = [V16IntegrationSetup] begin
    server, port = start_v16_mock_server()
    try
        cp = ChargePoint("CP-V16-ST01", "ws://127.0.0.1:$port"; reconnect = false)
        conn_task = @async connect!(cp)
        wait_for_status_v16(cp, :connected)

        resp = start_transaction(cp; connector_id = 1, id_tag = "TAG001", meter_start = 0)
        @test resp isa OCPPData.V16.StartTransactionResponse
        @test resp.transaction_id == 42

        disconnect!(cp)
    finally
        close(server)
    end
end

@testitem "V16 stop_transaction" tags = [:integration, :slow] setup = [V16IntegrationSetup] begin
    server, port = start_v16_mock_server()
    try
        cp = ChargePoint("CP-V16-SP01", "ws://127.0.0.1:$port"; reconnect = false)
        conn_task = @async connect!(cp)
        wait_for_status_v16(cp, :connected)

        resp = stop_transaction(cp; transaction_id = 42, meter_stop = 1000)
        @test resp isa OCPPData.V16.StopTransactionResponse

        disconnect!(cp)
    finally
        close(server)
    end
end

@testitem "V16 meter_values" tags = [:integration, :slow] setup = [V16IntegrationSetup] begin
    server, port = start_v16_mock_server()
    try
        cp = ChargePoint("CP-V16-MV01", "ws://127.0.0.1:$port"; reconnect = false)
        conn_task = @async connect!(cp)
        wait_for_status_v16(cp, :connected)

        mv = OCPPData.V16.MeterValue(;
            sampled_value = [OCPPData.V16.SampledValue(; value = "100.0")],
            timestamp = "2024-01-01T00:00:00Z",
        )
        resp = meter_values(cp; connector_id = 1, meter_value = [mv])
        @test resp isa OCPPData.V16.MeterValuesResponse

        disconnect!(cp)
    finally
        close(server)
    end
end
