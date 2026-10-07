defmodule Xaas.WorkbenchDeepeningTest do
  @moduledoc """
  Lane W748 deepening coverage for the GGen workbench surface
  (`/api/workbench/ggen` — CONSTRUCT-only forward of a bounded ggen argv
  vector + ephemeral file bundle to the private Fly worker).

  Chicago-style: real `Phoenix.ConnCase` requests through the real router
  (token floor included), and the Fly worker is stood in for by a real
  in-test Bandit HTTP server (the W674/W725 idiom) addressed via the real
  `GGEN_WORKBENCH_URL` env override — no mocks of owned code. Bytes are
  asserted on both sides: exact JSON body the receiver sees, exact response
  the HTTP client gets.

  Contracts asserted (read from `lib/xaas_web/router.ex` (workbench scope,
  token-floor-first pipe order), `lib/xaas_web/controllers/
  ggen_workbench_controller.ex`, and `lib/xaas/workbench/ggen_client.ex`,
  not assumed):

  - Forward contract: `POST /v1/ggen/run` on the worker with header
    `authorization: Bearer <GGEN_WORKBENCH_TOKEN>` and an exact JSON body
    `{"args": [...], "files": {path: value}, "timeout_ms": int}`. The
    classifier is `GgenClient.validate_payload/1`: shell metacharacters in
    argv stay literal argv (no escaping, no ambient shell), file keys are
    stringified relative paths, `timeout_ms` defaults to 120_000 and
    `args` to `["--version"]`.
  - CONSTRUCT-only: requests the classifier refuses (typed
    `{:refused, code, detail}`) never reach the worker; the controller
    maps them to 422 + `REFUSED[<code>]` (config refusals to 503).
  - Worker unreachable -> 502 `BLOCKED` with a real connection-refused
    transport exception.
  - Auth floor: the workbench scope pipes through
    `:require_internal_api_token`; absent/incorrect bearer -> 401, unset
    `INTERNAL_API_TOKEN` → 503 fail-closed.
  """
  use XaasWeb.ConnCase, async: false

  import Plug.Conn
  import Phoenix.ConnTest

  @token "test-only-internal-api-token"
  @workbench_token "w748-workbench-bearer"

  defmodule RecordingPlug do
    @moduledoc """
    Real Plug receiver standing in for the private Fly ggen worker.
    Captures method, full_path, raw body bytes, and authorization header
    into an Agent; answers with a fixed JSON construction receipt.
    """
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, opts) do
      agent = Keyword.fetch!(opts, :agent)
      {:ok, raw_body, conn} = Plug.Conn.read_body(conn)

      Agent.update(agent, fn state ->
        %{
          state
          | requests: [
              %{
                method: conn.method,
                full_path: conn.request_path,
                body: raw_body,
                auth: conn |> get_req_header("authorization") |> List.first()
              }
              | state.requests
            ]
        }
      end)

      body =
        Jason.encode!(%{
          standing: "ALIVE",
          construction_receipt: %{workspace_digest: "sha256:w748-fixtures"}
        })

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, body)
    end
  end

  setup context do
    {:ok, agent} = Agent.start_link(fn -> %{requests: []} end)

    {:ok, server_pid} =
      Bandit.start_link(plug: {RecordingPlug, [agent: agent]}, port: 0, ip: {127, 0, 0, 1})

    Process.unlink(server_pid)
    {:ok, {_addr, port}} = ThousandIsland.listener_info(server_pid)

    previous_url = System.get_env("GGEN_WORKBENCH_URL")
    previous_wb_token = System.get_env("GGEN_WORKBENCH_TOKEN")
    previous_api_token = System.get_env("INTERNAL_API_TOKEN")

    System.put_env("GGEN_WORKBENCH_URL", "http://127.0.0.1:#{port}")
    System.put_env("GGEN_WORKBENCH_TOKEN", @workbench_token)

    on_exit(fn ->
      restore_env("GGEN_WORKBENCH_URL", previous_url)
      restore_env("GGEN_WORKBENCH_TOKEN", previous_wb_token)
      restore_env("INTERNAL_API_TOKEN", previous_api_token)
      if Process.alive?(server_pid), do: Process.exit(server_pid, :shutdown)
    end)

    {:ok, Map.merge(context, %{agent: agent, port: port})}
  end

  defp restore_env(_name, nil), do: :ok
  defp restore_env(name, value), do: System.put_env(name, value)

  defp conn_with_token do
    build_conn()
    |> put_req_header("authorization", "Bearer #{@token}")
    |> put_req_header("content-type", "application/json")
  end

  defp agent_requests(agent), do: Agent.get(agent, & &1.requests)

  defp assert_single_request(agent) do
    case agent_requests(agent) do
      [request] -> request
      other -> flunk("expected exactly 1 worker request, saw #{length(other)}")
    end
  end

  defp assert_no_requests(agent) do
    assert agent_requests(agent) == []
  end

  # ---------------------------------------------------------------------------
  # (a) Valid bounded bundle forward: exact request bytes at the receiver
  # ---------------------------------------------------------------------------

  test "(a) valid bundle is forwarded with the exact documented contract body",
       %{agent: agent} do
    payload = %{
      "args" => ["sync", "run", "--dry-run", ";", "rm -rf /"],
      "files" => %{
        "ggen.toml" => "[project]\nname = \"consumer\"\n",
        "ontology.ttl" => "@prefix ex: <https://example.test/> .\n"
      },
      "timeout_ms" => 30_000
    }

    expected_forward =
      Jason.encode!(%{
        "args" => ["sync", "run", "--dry-run", ";", "rm -rf /"],
        "files" => %{
          "ggen.toml" => "[project]\nname = \"consumer\"\n",
          "ontology.ttl" => "@prefix ex: <https://example.test/> .\n"
        },
        "timeout_ms" => 30_000
      })

    conn = post(conn_with_token(), "/api/workbench/ggen", payload)

    assert conn.status == 200

    assert get_resp_header(conn, "link") == [
             ~s(</asyncapi.yaml>; rel="service-desc"; type="application/yaml")
           ]

    received = assert_single_request(agent)

    assert received.method == "POST"
    assert received.full_path == "/v1/ggen/run"
    assert received.auth == "Bearer #{@workbench_token}"

    # Exact bytes: shell metacharacters stay literal argv elements — no
    # escaping, no reordering, no ambient shell on either hop.
    assert received.body == expected_forward
  end

  test "(a2) client applies the documented defaults before the forward", %{agent: agent} do
    conn = post(conn_with_token(), "/api/workbench/ggen", %{"args" => ["--version"]})

    assert conn.status == 200

    received = assert_single_request(agent)

    assert received.body ==
             Jason.encode!(%{
               "args" => ["--version"],
               "files" => %{},
               "timeout_ms" => 120_000
             })
  end

  # ---------------------------------------------------------------------------
  # (b) CONSTRUCT-only: classifier-refused (mutation-classed) requests never
  # reach the worker
  # ---------------------------------------------------------------------------

  test "(b) UNSAFE_PATH bundle is refused 422 before any forward", %{agent: agent} do
    conn =
      post(conn_with_token(), "/api/workbench/ggen", %{
        "args" => ["sync", "run"],
        "files" => %{"../escape.ttl" => "not admitted"}
      })

    assert conn.status == 422

    assert json_response(conn, 422) == %{
             "standing" => "REFUSED[UNSAFE_PATH]",
             "refused" => true,
             "detail" => "file path escapes the ephemeral workspace: ../escape.ttl"
           }

    assert_no_requests(agent)
  end

  test "(b2) classifier refusal still advertises the asyncapi contract", %{agent: agent} do
    conn =
      post(conn_with_token(), "/api/workbench/ggen", %{
        "args" => ["sync", "run"],
        "files" => %{"../escape.ttl" => "nope"}
      })

    assert conn.status == 422

    assert get_resp_header(conn, "link") == [
             ~s(</asyncapi.yaml>; rel="service-desc"; type="application/yaml")
           ]

    assert_no_requests(agent)
  end

  # ---------------------------------------------------------------------------
  # (c) Worker unreachable -> typed BLOCKED, real connection failure
  # ---------------------------------------------------------------------------

  test "(c) dead worker port yields 502 BLOCKED with a real transport refusal" do
    # Bind and release a port so the connection refusal is real, not guessed.
    {:ok, socket} = :gen_tcp.listen(0, [:binary, packet: :raw, active: false, ip: {127, 0, 0, 1}])
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)

    previous_url = System.get_env("GGEN_WORKBENCH_URL")
    System.put_env("GGEN_WORKBENCH_URL", "http://127.0.0.1:#{port}")

    conn = post(conn_with_token(), "/api/workbench/ggen", %{"args" => ["--version"]})

    assert conn.status == 502

    body = json_response(conn, 502)
    assert body["standing"] == "BLOCKED"
    assert body["blocked"] == true
    assert body["detail"] =~ ~r/connection refused|econnrefused|timeout/i

    restore_env("GGEN_WORKBENCH_URL", previous_url)
  end

  # ---------------------------------------------------------------------------
  # (d) Auth floor per the W723 pinned matrix
  # ---------------------------------------------------------------------------

  test "(d1) missing bearer token -> 401, worker never contacted", %{agent: agent} do
    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post("/api/workbench/ggen", %{"args" => ["--version"]})

    assert conn.status == 401
    assert json_response(conn, 401)["error"] == "unauthorized"
    assert_no_requests(agent)
  end

  test "(d2) wrong bearer token -> 401, worker never contacted", %{agent: agent} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer not-the-real-token")
      |> put_req_header("content-type", "application/json")
      |> post("/api/workbench/ggen", %{"args" => ["--version"]})

    assert conn.status == 401
    assert json_response(conn, 401)["error"] == "unauthorized"
    assert_no_requests(agent)
  end

  test "(d3) unset INTERNAL_API_TOKEN -> 503 fail-closed, worker never contacted", %{
    agent: agent
  } do
    previous = System.get_env("INTERNAL_API_TOKEN")
    System.delete_env("INTERNAL_API_TOKEN")

    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post("/api/workbench/ggen", %{"args" => ["--version"]})

    assert conn.status == 503
    assert json_response(conn, 503)["error"] == "internal_api_misconfigured"
    assert_no_requests(agent)

    restore_env("INTERNAL_API_TOKEN", previous)
  end
end
