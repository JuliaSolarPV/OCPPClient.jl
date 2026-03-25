"""
PrecompileTools workloads to reduce time-to-first-execution (TTFX).
Precompiles request construction, payload serialization, and response
deserialization for all convenience methods.
"""

@compile_workload begin
    # ChargePoint construction
    cp = ChargePoint("precompile", "ws://localhost:9999"; reconnect = false)

    # on! and subscribe! registration
    on!(cp, "Reset") do cp, req
        return OCPPData.V16.ResetResponse(; status = OCPPData.V16.GenericAccepted)
    end
    subscribe!(cp, e -> nothing)

    # Event construction and emission
    _emit(cp, Connected(now(Dates.UTC)))
    _emit(cp, Disconnected(now(Dates.UTC), :normal))

    # _to_payload / _from_payload for each V16 request/response type
    # BootNotification
    boot_req = OCPPData.V16.BootNotificationRequest(;
        charge_point_vendor = "Precompile",
        charge_point_model = "PC",
    )
    p = _to_payload(boot_req)
    boot_resp_payload = Dict{String,Any}(
        "currentTime" => "2024-01-01T00:00:00Z",
        "interval" => 300,
        "status" => "Accepted",
    )
    _from_payload(OCPPData.V16.BootNotificationResponse, boot_resp_payload)

    # Heartbeat
    hb_req = OCPPData.V16.HeartbeatRequest()
    _to_payload(hb_req)
    _from_payload(
        OCPPData.V16.HeartbeatResponse,
        Dict{String,Any}("currentTime" => "2024-01-01T00:00:00Z"),
    )

    # Authorize
    auth_req = OCPPData.V16.AuthorizeRequest(; id_tag = "precompile")
    _to_payload(auth_req)
    _from_payload(
        OCPPData.V16.AuthorizeResponse,
        Dict{String,Any}("idTagInfo" => Dict{String,Any}("status" => "Accepted")),
    )

    # StatusNotification
    sn_req = OCPPData.V16.StatusNotificationRequest(;
        connector_id = 1,
        status = OCPPData.V16.ChargePointAvailable,
        error_code = OCPPData.V16.NoError,
    )
    _to_payload(sn_req)
    _from_payload(OCPPData.V16.StatusNotificationResponse, Dict{String,Any}())

    # StartTransaction
    st_req = OCPPData.V16.StartTransactionRequest(;
        connector_id = 1,
        id_tag = "precompile",
        meter_start = 0,
        timestamp = "2024-01-01T00:00:00.000Z",
    )
    _to_payload(st_req)
    _from_payload(
        OCPPData.V16.StartTransactionResponse,
        Dict{String,Any}(
            "transactionId" => 1,
            "idTagInfo" => Dict{String,Any}("status" => "Accepted"),
        ),
    )

    # StopTransaction
    stop_req = OCPPData.V16.StopTransactionRequest(;
        transaction_id = 1,
        meter_stop = 100,
        timestamp = "2024-01-01T00:00:00.000Z",
    )
    _to_payload(stop_req)
    _from_payload(OCPPData.V16.StopTransactionResponse, Dict{String,Any}())

    # MeterValues
    mv_req = OCPPData.V16.MeterValuesRequest(;
        connector_id = 1,
        meter_value = OCPPData.V16.MeterValue[],
    )
    _to_payload(mv_req)
    _from_payload(OCPPData.V16.MeterValuesResponse, Dict{String,Any}())

    # Routing: _handle_server_call with a handler registered
    call = OCPPData.Call("pc-1", "Reset", Dict{String,Any}("type" => "Soft"))
    _handle_server_call(cp, call)
end
