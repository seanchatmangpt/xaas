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
      |> get("/internal-api/prometheus/query", query: "phoenix_endpoint_stop_duration_milliseconds_sum")

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
        |> get("/internal-api/prometheus/query", query: "phoenix_endpoint_stop_duration_milliseconds_sum")

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

  describe "real PromQL query allowlist" do
    # Shared real-closed-port setup: a real, instantly-refusing local
    # TCP listener. Used to prove -- via real network behavior, not an
    # interaction assertion -- whether the controller ever attempted a
    # real HTTP call to Prometheus for a given query.
    defp with_closed_port(fun) do
      {:ok, listen_socket} = :gen_tcp.listen(0, [:binary, active: false])
      {:ok, port} = :inet.port(listen_socket)
      :ok = :gen_tcp.close(listen_socket)

      original = System.get_env("PROMETHEUS_URL")
      System.put_env("PROMETHEUS_URL", "http://127.0.0.1:#{port}")

      try do
        fun.(port)
      after
        if original do
          System.put_env("PROMETHEUS_URL", original)
        else
          System.delete_env("PROMETHEUS_URL")
        end
      end
    end

    test "an allowed query (real emitted metric name) is forwarded -- real 502 on the real closed port proves a real HTTP attempt was made",
         %{conn: conn} do
      with_closed_port(fn port ->
        conn =
          conn
          |> with_internal_api_token()
          |> get("/internal-api/prometheus/query", query: "phoenix_endpoint_stop_duration_milliseconds_sum")

        # Reaching the real 502 (rather than a real 400) is the
        # state-based proof that this query passed the allowlist and
        # the controller went on to really attempt an HTTP call to
        # Prometheus on the real closed port.
        body = json_response(conn, 502)
        assert body["error"] == "prometheus_unreachable"
        assert body["detail"] =~ "127.0.0.1:#{port}"
      end)
    end

    test "a query for a metric name outside the real allowlist is real-400-rejected before any real HTTP call is attempted",
         %{conn: conn} do
      with_closed_port(fn _port ->
        conn =
          conn
          |> with_internal_api_token()
          |> get("/internal-api/prometheus/query", query: "node_filesystem_free_bytes")

        # Real 400, not the real 502 the closed-port path would produce
        # if an HTTP call had actually been attempted -- state-based
        # proof the rejection happened before any network call.
        body = json_response(conn, 400)
        assert body["error"] == "query_not_allowed"
        assert body["detail"] =~ "node_filesystem_free_bytes"
        assert body["detail"] =~ "allowlist"
      end)
    end

    test "a query with a real unbounded range-vector selector is real-400-rejected before any real HTTP call is attempted",
         %{conn: conn} do
      with_closed_port(fn _port ->
        conn =
          conn
          |> with_internal_api_token()
          |> get("/internal-api/prometheus/query", query: "rate(phoenix_endpoint_stop_duration_milliseconds_sum[365d])")

        body = json_response(conn, 400)
        assert body["error"] == "query_not_allowed"
        assert body["detail"] =~ "365d"
      end)
    end
  end
end
