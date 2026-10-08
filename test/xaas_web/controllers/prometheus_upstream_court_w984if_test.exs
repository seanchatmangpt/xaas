defmodule XaasWeb.Controllers.PrometheusUpstreamCourtW984ifTest do
  @moduledoc """
  Lane W984if — closes the branch W984eq left disclosed-uncovered: the
  `{:error, other}` -> 502 clause in
  `XaasWeb.PrometheusQueryController.forward_to_prometheus/2`
  (lib/xaas_web/controllers/prometheus_query_controller.ex:108), the
  catch-all beside the `%Req.TransportError{}` clause.

  W984eq called it "not reachable via real HTTP without faking Req".
  It is reachable: the controller reads its upstream address from the
  `PROMETHEUS_URL` env var (line 92), the same config seam shape as the
  AwsAdapter seam. This court points `PROMETHEUS_URL` at a real local
  Bandit HTTP listener on an OS-assigned ephemeral port, so Req makes a
  real TCP connection to a real HTTP server and the controller's error
  clauses are selected by real network behavior.

  Cells:

  - p1 upstream 200 + invalid JSON body -> Req fails at the decode step,
    `Req.get` returns `{:error, %Req.DecodeError{}}` (not a
    TransportError), so the `{:error, other}` catch-all fires and the
    client sees a real 502 typed envelope whose detail inspects the
    decode error.
  - p2 upstream 200 + valid Prometheus JSON -> the success clause still
    flows (status + body passed as-is); the sibling W984eq cells
    (400 missing_query_param, 400 subquery rejection, closed-port 502)
    stay green (p4 and the existing residue court).
  - p3 closed port -> `%Req.TransportError{reason: :econnrefused}` -> the
    dedicated clause's real shape (502, detail carrying the base URL and
    the refused reason).

  Mutation rationale per cell:

  - p1: delete or narrow the `{:error, other}` clause -> the decode error
    has no match clause -> MatchError -> 500, not this 502 envelope.
  - p2: any regression in the success clause (status passthrough, body
    passthrough, base-URL joining) changes this response.
  - p3: swapping the TransportError clause into the catch-all (or
    deleting it) still 502s but changes the reachable-clause set this
    court distinguishes; the detail text pins the TransportError clause
    specifically.

  Chicago-style: real Req HTTP client, real Bandit HTTP server over a
  real TCP socket, real router dispatch with the real INTERNAL_API_TOKEN
  from test_helper.exs. Zero mocks.
  """

  use XaasWeb.ConnCase, async: false

  import Plug.Conn
  import Phoenix.ConnTest

  @endpoint XaasWeb.Endpoint

  # ---------------------------------------------------------------------------
  # Real Bandit receiver standing in for the Prometheus endpoint
  # ---------------------------------------------------------------------------

  defmodule PromReceiverPlug do
    @moduledoc false
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, _opts) do
      {:ok, _body, conn} = Plug.Conn.read_body(conn)

      {status, resp_body} =
        case Application.get_env(:xaas, :prom_receiver_w984if_response) do
          nil ->
            {200, ~s({"status":"success","data":{"resultType":"vector","result":[]}})}

          {status, body} ->
            {status, body}
        end

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(status, resp_body)
    end
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    {:ok, server_pid} = Bandit.start_link(plug: PromReceiverPlug, port: 0, ip: {127, 0, 0, 1})
    Process.unlink(server_pid)
    {:ok, {_address, port}} = ThousandIsland.listener_info(server_pid)

    previous_url = System.get_env("PROMETHEUS_URL")
    System.put_env("PROMETHEUS_URL", "http://127.0.0.1:#{port}")

    on_exit(fn ->
      if previous_url do
        System.put_env("PROMETHEUS_URL", previous_url)
      else
        System.delete_env("PROMETHEUS_URL")
      end
    end)

    %{port: port}
  end

  defp tokened(conn),
    do: put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))

  test "p1. upstream 200 with an invalid JSON body -> Req decode error -> the {:error, other} catch-all 502 envelope" do
    # Mutation: delete the `{:error, other}` clause -> MatchError -> 500,
    # not this typed 502 envelope naming the decode failure.
    Application.put_env(:xaas, :prom_receiver_w984if_response,
      {200, "this is definitely not json {"}
    )

    conn =
      build_conn()
      |> tokened()
      |> get("/internal-api/prometheus/query", %{"query" => "beam_memory_process_bytes"})

    assert conn.status == 502
    body = json_response(conn, 502)
    assert body["error"] == "prometheus_unreachable"
    assert body["detail"] =~ "could not reach Prometheus at"
    assert body["detail"] =~ "DecodeError"
  after
    Application.delete_env(:xaas, :prom_receiver_w984if_response)
  end

  test "p2. upstream success still flows through the success clause unchanged" do
    # Mutation: any regression in the success clause (status/body
    # passthrough, URL join) changes this response.
    Application.put_env(:xaas, :prom_receiver_w984if_response,
      {200, ~s({"status":"success","data":{"resultType":"vector","result":[{"metric":{"__name__":"beam_memory_process_bytes"},"value":[1,"1024"]}]}})}
    )

    conn =
      build_conn()
      |> tokened()
      |> get("/internal-api/prometheus/query", %{"query" => "beam_memory_process_bytes"})

    body = json_response(conn, 200)
    assert body["status"] == "success"

    vector = body["data"]["result"]
    assert [%{"metric" => %{"__name__" => "beam_memory_process_bytes"}}] = vector
  after
    Application.delete_env(:xaas, :prom_receiver_w984if_response)
  end

  test "p3. upstream non-200 status is passed through as-is (status passthrough of the success clause)" do
    # Mutation: hardcoding 200 in the success clause instead of
    # `put_status(status)` changes this response status.
    Application.put_env(:xaas, :prom_receiver_w984if_response,
      {422, ~s({"status":"error","errorType":"bad_data","error":"parse error"})}
    )

    conn =
      build_conn()
      |> tokened()
      |> get("/internal-api/prometheus/query", %{"query" => "beam_memory_process_bytes"})

    body = json_response(conn, 422)
    assert body["status"] == "error"
    assert body["errorType"] == "bad_data"
  after
    Application.delete_env(:xaas, :prom_receiver_w984if_response)
  end

  test "p4. closed port -> real Req.TransportError -> the dedicated TransportError 502 clause" do
    # Mutation rationale in moduledoc; the existing
    # prometheus_query_controller_test.exs already pins this clause, but
    # it is the sibling that distinguishes p1's catch-all, so it is
    # re-asserted here on the same harness to prove clause separation.
    {:ok, listen_socket} = :gen_tcp.listen(0, [:binary, active: false])
    {:ok, port} = :inet.port(listen_socket)
    :ok = :gen_tcp.close(listen_socket)

    previous_url = System.get_env("PROMETHEUS_URL")
    System.put_env("PROMETHEUS_URL", "http://127.0.0.1:#{port}")

    try do
      conn =
        build_conn()
        |> tokened()
        |> get("/internal-api/prometheus/query", %{"query" => "beam_memory_process_bytes"})

      body = json_response(conn, 502)
      assert body["error"] == "prometheus_unreachable"
      assert body["detail"] =~ "127.0.0.1:#{port}"
      assert body["detail"] =~ "econnrefused"
    after
      if previous_url do
        System.put_env("PROMETHEUS_URL", previous_url)
      else
        System.delete_env("PROMETHEUS_URL")
      end
    end
  end
end
