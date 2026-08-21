defmodule KanbanWeb.PrometheusQueryControllerTest do
  @moduledoc """
  Two real Chicago-style tests, no mocking:

  1. `:kind`-tagged (excluded by default, same pattern as
     `test/e2e/kind_deployment_test.exs`) -- exercises the real proxy
     against a real, live Prometheus. Run explicitly:

         mix test --include kind test/kanban_web/controllers/prometheus_query_controller_test.exs

     Requires `PROMETHEUS_URL` to point at a real reachable Prometheus
     (e.g. `kubectl port-forward` to the `prometheus` pod in
     `kind-xaas`, or a local PromEx-scraped instance on :9090).

  2. Untagged, runs by default -- proves the real 502 error path by
     pointing `PROMETHEUS_URL` at a real, instantly-refusing local TCP
     listener (a real closed port), not a mock of `Req`.
  """
  use KanbanWeb.ConnCase

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  @tag :kind
  test "GET /internal-api/prometheus/query proxies a real query to a real live Prometheus", %{conn: conn} do
    conn =
      conn
      |> with_internal_api_token()
      |> get("/internal-api/prometheus/query", query: "up")

    body = json_response(conn, 200)
    assert body["status"] in ["success", "error"]
  end

  test "GET /internal-api/prometheus/query returns a real 502 with a clear JSON error body when Prometheus is unreachable",
       %{conn: conn} do
    # Real, instantly-refusing local port: open then immediately close a
    # real TCP listener so the port is guaranteed unused and connections
    # to it are refused for real (not a mock of Req or the network).
    {:ok, listen_socket} = :gen_tcp.listen(0, [:binary, active: false])
    {:ok, port} = :inet.port(listen_socket)
    :ok = :gen_tcp.close(listen_socket)

    original = System.get_env("PROMETHEUS_URL")
    System.put_env("PROMETHEUS_URL", "http://127.0.0.1:#{port}")

    try do
      conn =
        conn
        |> with_internal_api_token()
        |> get("/internal-api/prometheus/query", query: "up")

      body = json_response(conn, 502)
      assert body["error"] == "prometheus_unreachable"
      assert body["detail"] =~ "127.0.0.1:#{port}"
    after
      if original do
        System.put_env("PROMETHEUS_URL", original)
      else
        System.delete_env("PROMETHEUS_URL")
      end
    end
  end
end
