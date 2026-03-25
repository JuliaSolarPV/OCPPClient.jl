"""
PrecompileTools workloads to reduce time-to-first-execution (TTFX).
Precompiles request construction, payload serialization, and response
deserialization for all convenience methods.
"""

# Always precompile version-agnostic infrastructure
@compile_workload begin
    cp = ChargePoint("precompile", "ws://localhost:9999"; reconnect = false)
    subscribe!(cp, e -> nothing)
    _emit(cp, Connected(now(Dates.UTC)))
    _emit(cp, Disconnected(now(Dates.UTC), :normal))
end

if OCPPData.ENABLE_V16
    @compile_workload begin
        cp = ChargePoint("precompile-v16", "ws://localhost:9999"; reconnect = false)

        on!(cp, "Reset") do cp, req
            return OCPPData.V16.ResetResponse(; status = OCPPData.V16.GenericAccepted)
        end

        # BootNotification
        boot_req = OCPPData.V16.BootNotificationRequest(;
            charge_point_vendor = "Precompile",
            charge_point_model = "PC",
        )
        _to_payload(boot_req)
        _from_payload(
            OCPPData.V16.BootNotificationResponse,
            Dict{String,Any}(
                "currentTime" => "2024-01-01T00:00:00Z",
                "interval" => 300,
                "status" => "Accepted",
            ),
        )

        # Heartbeat
        _to_payload(OCPPData.V16.HeartbeatRequest())
        _from_payload(
            OCPPData.V16.HeartbeatResponse,
            Dict{String,Any}("currentTime" => "2024-01-01T00:00:00Z"),
        )

        # Authorize
        _to_payload(OCPPData.V16.AuthorizeRequest(; id_tag = "precompile"))
        _from_payload(
            OCPPData.V16.AuthorizeResponse,
            Dict{String,Any}("idTagInfo" => Dict{String,Any}("status" => "Accepted")),
        )

        # StatusNotification
        _to_payload(
            OCPPData.V16.StatusNotificationRequest(;
                connector_id = 1,
                status = OCPPData.V16.ChargePointAvailable,
                error_code = OCPPData.V16.NoError,
            ),
        )
        _from_payload(OCPPData.V16.StatusNotificationResponse, Dict{String,Any}())

        # StartTransaction
        _to_payload(
            OCPPData.V16.StartTransactionRequest(;
                connector_id = 1,
                id_tag = "precompile",
                meter_start = 0,
                timestamp = "2024-01-01T00:00:00.000Z",
            ),
        )
        _from_payload(
            OCPPData.V16.StartTransactionResponse,
            Dict{String,Any}(
                "transactionId" => 1,
                "idTagInfo" => Dict{String,Any}("status" => "Accepted"),
            ),
        )

        # StopTransaction
        _to_payload(
            OCPPData.V16.StopTransactionRequest(;
                transaction_id = 1,
                meter_stop = 100,
                timestamp = "2024-01-01T00:00:00.000Z",
            ),
        )
        _from_payload(OCPPData.V16.StopTransactionResponse, Dict{String,Any}())

        # MeterValues
        _to_payload(
            OCPPData.V16.MeterValuesRequest(;
                connector_id = 1,
                meter_value = OCPPData.V16.MeterValue[],
            ),
        )
        _from_payload(OCPPData.V16.MeterValuesResponse, Dict{String,Any}())

        # Routing
        _handle_server_call(
            cp,
            OCPPData.Call("pc-v16", "Reset", Dict{String,Any}("type" => "Soft")),
        )
    end
end

if OCPPData.ENABLE_V201
    @compile_workload begin
        cp = ChargePoint(
            "precompile-v201",
            "ws://localhost:9999";
            spec = OCPPData.V201.Spec(),
            reconnect = false,
        )

        on!(cp, "Reset") do cp, req
            return OCPPData.V201.ResetResponse(; status = OCPPData.V201.ResetAccepted)
        end

        # BootNotification
        _to_payload(
            OCPPData.V201.BootNotificationRequest(;
                reason = OCPPData.V201.BootReasonPowerUp,
                charging_station = OCPPData.V201.ChargingStation(;
                    model = "PC",
                    vendor_name = "Precompile",
                ),
            ),
        )
        _from_payload(
            OCPPData.V201.BootNotificationResponse,
            Dict{String,Any}(
                "currentTime" => "2024-01-01T00:00:00.000Z",
                "interval" => 300,
                "status" => "Accepted",
            ),
        )

        # Heartbeat
        _to_payload(OCPPData.V201.HeartbeatRequest())
        _from_payload(
            OCPPData.V201.HeartbeatResponse,
            Dict{String,Any}("currentTime" => "2024-01-01T00:00:00.000Z"),
        )

        # Routing
        _handle_server_call(
            cp,
            OCPPData.Call("pc-v201", "Reset", Dict{String,Any}("type" => "Immediate")),
        )
    end
end
