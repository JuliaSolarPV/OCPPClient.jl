using OCPPClient
using TestItemRunner
using HTTP
using Sockets: getsockname

# Pre-compile HTTP.jl WebSocket client/server code on the main task.
# Without this, the first @async connect! in integration tests compiles
# HTTP.jl internals for 15+ seconds without yielding, causing wait_for_status
# to time out on cold CI runners.
let
    server = HTTP.WebSockets.listen!("127.0.0.1", 0) do ws
        ;
    end
    _, port = getsockname(server.listener.server)
    try
        HTTP.WebSockets.open("ws://127.0.0.1:$(Int(port))/warmup") do ws
            ;
        end
    catch
    end
    close(server)
end

@run_package_tests verbose=true
