Mix.Task.run("app.start")

# Real manual-timing benchmark (no Benchee dependency needed for a single
# scenario -- matches the "manual-timing" branch of the established
# bench/ convention) measuring the real p50/p99 latency of
# KanbanWeb.PrometheusQueryController's real 502 error path.
#
# Real technique, identical to
# test/kanban_web/controllers/prometheus_query_controller_test.exs: open
# a real local TCP listener, grab its real port, close it immediately so
# the port is guaranteed unused, and point PROMETHEUS_URL at it -- every
# request in this benchmark hits a real "connection refused" from a real
# closed local port, not a mock of Req or the network.
#
# Run:
#
#   cd ~/xaas && mix run bench/prometheus_proxy_error_path_bench.exs
#
# N real sequential HTTP requests are issued directly through the real
# Phoenix endpoint via Plug.Test/Phoenix.ConnTest-style conn building
# (no mocking of the controller or Req -- a real conn is dispatched
# through the real router pipeline, same code path a real client hits).

alias KanbanWeb.Endpoint

n = 200

{:ok, listen_socket} = :gen_tcp.listen(0, [:binary, active: false])
{:ok, port} = :inet.port(listen_socket)
:ok = :gen_tcp.close(listen_socket)

System.put_env("PROMETHEUS_URL", "http://127.0.0.1:#{port}")
System.put_env("INTERNAL_API_TOKEN", System.get_env("INTERNAL_API_TOKEN", "bench-only-internal-api-token"))

token = System.fetch_env!("INTERNAL_API_TOKEN")

request = fn ->
  conn =
    Plug.Test.conn(:get, "/internal-api/prometheus/query?query=up")
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)

  {micros, conn} =
    :timer.tc(fn ->
      Endpoint.call(conn, Endpoint.init([]))
    end)

  true = conn.status == 502
  micros
end

IO.puts("Warming up (10 real requests against real closed port #{port})...")
Enum.each(1..10, fn _ -> request.() end)

IO.puts("Running #{n} real sequential requests against the real 502 error path...")

latencies_micros =
  1..n
  |> Enum.map(fn _ -> request.() end)
  |> Enum.sort()

percentile = fn sorted, p ->
  idx = min(length(sorted) - 1, trunc(p / 100 * length(sorted)))
  Enum.at(sorted, idx)
end

p50 = percentile.(latencies_micros, 50)
p99 = percentile.(latencies_micros, 99)
mean = Enum.sum(latencies_micros) / length(latencies_micros)
min_v = List.first(latencies_micros)
max_v = List.last(latencies_micros)

IO.puts("""

Prometheus proxy error-path latency (#{n} real sequential requests, real closed port #{port}):
  min:  #{Float.round(min_v / 1000, 3)} ms
  p50:  #{Float.round(p50 / 1000, 3)} ms
  mean: #{Float.round(mean / 1000, 3)} ms
  p99:  #{Float.round(p99 / 1000, 3)} ms
  max:  #{Float.round(max_v / 1000, 3)} ms
""")
