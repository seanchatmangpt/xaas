defmodule XaasWeb.ExecutionFabricDeepeningTest do
  @moduledoc """
  W745 execution-fabric deepening (lane W745, v26.10.6): Chicago-style
  qualification of the doctrine-central MCP surface
  (`POST /internal-api/execution/mcp`) — the only provider-worker path into
  the admitted `Xaas.Actuation.run/4` DO kernel.

  Real ConnCase HTTP requests behind the real `RequireInternalApiToken`
  gate, real sandboxed Run/Epoch/Receipt/ActuationIntent rows, a real
  (simple) capability source module injected through the resolver's own
  config seam. No mocks.

  Courts:

    (a) lease gating: consequential verbs without a valid lease answer the
        real typed refusals (exact wire shapes);
    (b) actuate with a valid lease + registered capability + registered
        {resource, action} pair routes into the admitted path far enough
        that a real refusal/receipt is durably observable in the sandbox
        (real ActuationIntent/Receipt rows, real Provider mutation);
    (c) unknown verb -> typed error; malformed envelope -> typed error;
    (d) the W723 auth-floor matrix applies to this surface (401 / 503);
    (e) refusal shapes are deterministic (same request twice -> identical
        body bytes);
    (+) the MCP `refuse` verb seals a real Receipt durably readable on the
        lawful `GET /execution/epochs/:id/receipts` read path.
  """

  use XaasWeb.ConnCase, async: false

  alias Xaas.Ultracode.{Epoch, Run}

  # A real (simple) capability source module — a hand-written real
  # interface implementation, not a mock — injected through the resolver's
  # own config seam, same pattern as execution_fabric_surface_test.exs.
  defmodule PublishSource do
    @moduledoc false
    @behaviour Xaas.Ultracode.CapabilityResolver.Source

    @impl true
    def candidates(_item, _ctx),
      do:
        {:ok,
         [
           %{capability_id: "sa2a:publish_change", satisfies: ["publish_change"]}
         ]}
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    keys = [:ultracode_capability_sources, :ultracode_actuation_registry]
    saved = Map.new(keys, &{&1, Application.fetch_env(:xaas, &1)})

    on_exit(fn ->
      Enum.each(saved, fn
        {key, {:ok, value}} -> Application.put_env(:xaas, key, value)
        {key, :error} -> Application.delete_env(:xaas, key)
      end)
    end)

    :ok
  end

  # ------------------------------------------------------------------
  # Transport helpers (real HTTP, real bearer gate)
  # ------------------------------------------------------------------

  defp mcp_post(conn, body) do
    conn
    |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> post("/internal-api/execution/mcp", Jason.encode!(body))
  end

  # text/plain: the endpoint's parsers never fetch body_params, so the
  # controller's raw-read + Jason.decode path runs on the real wire bytes.
  defp mcp_raw(conn, raw_body) do
    conn
    |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    |> put_req_header("content-type", "text/plain")
    |> post("/internal-api/execution/mcp", raw_body)
  end

  defp mcp_result(conn, method, params) do
    conn
    |> mcp_post(%{jsonrpc: "2.0", id: 1, method: method, params: params})
    |> json_response(200)
    |> Map.fetch!("result")
  end

  # Returns {is_error?, decoded_tool_payload}.
  defp tool_call(conn, name, arguments) do
    result = mcp_result(conn, "tools/call", %{"name" => name, "arguments" => arguments})

    [%{"text" => text}] = result["content"]
    {result["isError"] == true, Jason.decode!(text)}
  end

  # Claims a real lease over the real MCP surface (no git worktree needed:
  # the actuate/refuse paths never head-verify).
  defp claimed(conn, provider) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "W745 execution-fabric deepening.", provider: provider},
        authorize?: false
      )
      |> Ash.create()

    {:ok, epoch} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "XaasWeb.ExecutionFabricDeepeningTest",
          state: :running
        },
        authorize?: false
      )
      |> Ash.create()

    {false, claim} =
      tool_call(conn, "claim_next", %{
        provider: provider,
        provider_worker_id: "worker-w745",
        epoch_id: epoch.id
      })

    {run, epoch, claim}
  end

  # ------------------------------------------------------------------
  # (a) Lease gating: consequential verbs without a valid lease
  # ------------------------------------------------------------------

  test "a.1 actuate without a lease is the typed WORK_NOT_FOUND surface failure", %{
    conn: conn
  } do
    assert {true, %{"error" => "WORK_NOT_FOUND", "failure" => failure}} =
             tool_call(conn, "actuate", %{
               lease_token: "no-such-lease",
               capability: "publish_change",
               resource: "Xaas.Marketplace.Provider",
               action: "actuate_status",
               idempotency_key: "w745-no-lease"
             })

    assert failure["code"] == "WORK_NOT_FOUND"
    assert failure["details"]["reason"] == "no_lease"
    assert failure["details"]["detail"] == ~s("no-such-lease")
  end

  test "a.2 actuate with a live lease but no capability is the typed UNAUTHORIZED court", %{
    conn: conn
  } do
    provider = "w745-nocap-#{System.unique_integer([:positive])}"
    {_run, _epoch, claim} = claimed(conn, provider)

    assert {true, %{"error" => "UNAUTHORIZED", "failure" => failure}} =
             tool_call(conn, "actuate", %{
               lease_token: claim["lease_token"],
               resource: "Xaas.Marketplace.Provider",
               action: "actuate_status",
               idempotency_key: "w745-nocap"
             })

    assert failure["code"] == "UNAUTHORIZED"
    assert failure["details"]["reason"] == "capability_required"
    assert failure["details"]["required"] ==
             "UltraCode -> SA2A -> resolve_capability -> actuate(capability)"
  end

  test "a.3 admit_tool / heartbeat / close_candidate on an unknown lease are typed strings", %{
    conn: conn
  } do
    assert {true, %{"error" => ~s(no_lease:"no-such-lease")}} =
             tool_call(conn, "admit_tool", %{lease_token: "no-such-lease", tool: "Bash"})

    assert {true, %{"error" => ~s(no_lease:"no-such-lease")}} =
             tool_call(conn, "heartbeat", %{lease_token: "no-such-lease"})

    assert {true, %{"error" => ~s(no_lease:"no-such-lease")}} =
             tool_call(conn, "close_candidate", %{
               lease_token: "no-such-lease",
               final_head: "deadbeef",
               outcome: "alive"
             })
  end

  test "a.4 actuate argument-shape refusals: missing lease_token vs missing required fields", %{
    conn: conn
  } do
    # No lease_token at all -> the bare transport refusal.
    assert {true, %{"error" => ":lease_token_required"}} =
             tool_call(conn, "actuate", %{
               capability: "publish_change",
               resource: "Xaas.Marketplace.Provider",
               action: "actuate_status",
               idempotency_key: "w745-shape"
             })

    # Missing resource/action/idempotency_key never reaches the registry:
    # the capability court answers first (same UNAUTHORIZED court), so an
    # unregistered pair is never silently downgraded to a shape error.
    {_run, _epoch, claim} = claimed(conn, "w745-shape-#{System.unique_integer([:positive])}")

    assert {true, %{"error" => "UNAUTHORIZED"}} =
             tool_call(conn, "actuate", %{lease_token: claim["lease_token"]})
  end

  # ------------------------------------------------------------------
  # (b) Actuate with a valid lease shape -> the admitted DO kernel
  # ------------------------------------------------------------------

  test "b.1 actuate with valid lease + registered capability + registered pair routes into " <>
         "Xaas.Actuation.run/4 and lands durably observable intent + receipt + mutation", %{
    conn: conn
  } do
    Application.put_env(:xaas, :ultracode_capability_sources, %{"local" => PublishSource})

    provider = "w745-actuate-#{System.unique_integer([:positive])}"
    marketplace_provider = Xaas.Generator.create_provider!(%{org_id: "org-w745-actuate"})

    Application.put_env(:xaas, :ultracode_actuation_registry, %{
      provider => %{
        {"Xaas.Marketplace.Provider", "actuate_status"} =>
          {Xaas.Marketplace.Provider, :actuate_status, marketplace_provider.id}
      }
    })

    {_run, _epoch, claim} = claimed(conn, provider)
    token = claim["lease_token"]

    key = "w745-actuate-#{System.unique_integer([:positive])}"

    assert {false, actuation} =
             tool_call(conn, "actuate", %{
               lease_token: token,
               capability: "publish_change",
               resource: "Xaas.Marketplace.Provider",
               action: "actuate_status",
               input: %{"status" => "active"},
               idempotency_key: key
             })

    assert actuation["status"] == "succeeded"
    assert actuation["replay"] == false
    assert is_binary(actuation["intent_id"])
    assert is_binary(actuation["receipt_id"])
    # The receipt snapshot, not the live struct.
    assert is_map(actuation["result"])

    # Real durable rows through the real DO kernel.
    intent = Ash.get!(Xaas.Operations.ActuationIntent, actuation["intent_id"], authorize?: false)

    assert intent.authority["kind"] == "ultracode_lease_actuation"
    assert intent.authority["provider"] == provider
    assert intent.authority["epoch_id"] == claim["epoch_id"]
    assert intent.authority["lease_fingerprint"]
    refute intent.authority["lease_fingerprint"] == token

    receipt = Ash.get!(Xaas.Operations.ActuationReceipt, actuation["receipt_id"], authorize?: false)
    assert receipt.intent_id == intent.id

    # The real mutation landed through Xaas.Actuation.run/4.
    assert Xaas.Marketplace.Provider
           |> Ash.get!(marketplace_provider.id, authorize?: false)
           |> Map.fetch!(:status) == :active
  end

  test "b.2 a live lease + actuating capability but an UNREGISTERED pair is a typed refusal, " <>
         "never a silent DO", %{conn: conn} do
    Application.put_env(:xaas, :ultracode_capability_sources, %{"local" => PublishSource})

    provider = "w745-unreg-#{System.unique_integer([:positive])}"
    {_run, _epoch, claim} = claimed(conn, provider)

    assert {true, %{"error" => error}} =
             tool_call(conn, "actuate", %{
               lease_token: claim["lease_token"],
               capability: "publish_change",
               resource: "Xaas.Marketplace.Provider",
               action: "actuate_status",
               idempotency_key: "w745-unregistered"
             })

    assert error =~ "unregistered_actuation"
    assert error =~ ~s("Xaas.Marketplace.Provider")
    assert error =~ ~s("actuate_status")
  end

  # ------------------------------------------------------------------
  # (c) Unknown verb + malformed envelope
  # ------------------------------------------------------------------

  test "c.1 unknown verb is a typed tool error", %{conn: conn} do
    assert {true, %{"error" => ~s(unknown_tool:"deploy_everything")}} =
             tool_call(conn, "deploy_everything", %{})
  end

  test "c.2 malformed JSON-RPC envelope is a typed 400, never a crash page", %{conn: conn} do
    conn = mcp_post(conn, %{jsonrpc: "2.0", id: 2})
    assert conn.status == 400
    assert %{"error" => "bad_request", "detail" => ":invalid_request"} = json_response(conn, 400)
  end

  test "c.3 non-object JSON body is a typed 400 invalid_json", %{conn: conn} do
    # No JSON content-type => the endpoint's parsers never fetch
    # body_params, so the controller's raw-read + Jason.decode path runs and
    # a JSON body whose top level is not an object is the typed
    # :invalid_json refusal.
    conn = mcp_raw(conn, "[1,2,3]")

    assert conn.status == 400
    assert %{"error" => "bad_request", "detail" => ":invalid_json"} = json_response(conn, 400)
  end

  test "c.4 a malformed tool payload (non-binary lease_token) is a typed tool error, never a crash", %{
    conn: conn
  } do
    # A non-binary lease_token (42) fails the controller's
    # {"lease_token","reason"} map-shape clause and lands on the arity-1
    # catch-all: the typed arity refusal, not a raise and not an HTML
    # DebugPage. The fail-closed rescue arm stays for genuinely unexpected
    # Lease/Ash raises (its -32603 contract, unchanged).
    assert {true, %{"error" => ":lease_token_and_reason_required"}} =
             tool_call(conn, "refuse", %{"lease_token" => 42})
  end

  # ------------------------------------------------------------------
  # (d) W723 auth-floor matrix applies to this surface
  # ------------------------------------------------------------------

  test "d.1 missing bearer header is 401 with the exact documented body", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/internal-api/execution/mcp", Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "tools/list", params: %{}}))

    assert conn.status == 401
    assert conn.halted

    assert json_response(conn, 401) == %{
             "error" => "unauthorized",
             "detail" => "missing or invalid Bearer token"
           }

    refute conn.assigns[:current_org]
  end

  test "d.2 wrong bearer is 401; unset env fails closed 503 even with a wrong bearer", %{
    conn: conn
  } do
    conn =
      conn
      |> put_req_header("authorization", "Bearer not-the-real-token")
      |> put_req_header("content-type", "application/json")
      |> post("/internal-api/execution/mcp", Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "tools/list", params: %{}}))

    assert conn.status == 401

    assert json_response(conn, 401) == %{
             "error" => "unauthorized",
             "detail" => "missing or invalid Bearer token"
           }

    previous = System.fetch_env!("INTERNAL_API_TOKEN")
    System.delete_env("INTERNAL_API_TOKEN")

    try do
      conn2 =
        build_conn()
        |> put_req_header("authorization", "Bearer not-the-real-token")
        |> put_req_header("content-type", "application/json")
        |> post("/internal-api/execution/mcp", Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "tools/list", params: %{}}))

      assert conn2.status == 503
      assert conn2.halted

      assert json_response(conn2, 503) == %{
               "error" => "internal_api_misconfigured",
               "detail" => "INTERNAL_API_TOKEN is not set on the server"
             }
    after
      System.put_env("INTERNAL_API_TOKEN", previous)
    end
  end

  # ------------------------------------------------------------------
  # (e) Determinism of refusal shapes x2
  # ------------------------------------------------------------------

  test "e.1 refusal shapes are deterministic: same request twice, identical bodies", %{
    conn: conn
  } do
    body = %{
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: %{
        "name" => "actuate",
        "arguments" => %{
          "lease_token" => "no-such-lease",
          "capability" => "publish_change",
          "resource" => "Xaas.Marketplace.Provider",
          "action" => "actuate_status",
          "idempotency_key" => "w745-determinism"
        }
      }
    }

    responses =
      for _ <- 1..2 do
        conn
        |> mcp_post(body)
        |> json_response(200)
      end

    assert [first, second] = responses
    assert first == second

    text = first |> Map.fetch!("result") |> Map.fetch!("content") |> List.first() |> Map.fetch!("text")
    assert text =~ "WORK_NOT_FOUND"
    assert text =~ "no_lease"
  end

  test "e.2 unknown-tool refusal is deterministic across repeated calls", %{conn: conn} do
    call = %{jsonrpc: "2.0", id: 1, method: "tools/call", params: %{"name" => "no_such_verb", "arguments" => %{}}}

    bodies =
      for _ <- 1..2 do
        conn |> mcp_post(call) |> json_response(200)
      end

    assert [a, b] = bodies
    assert a == b
    assert a |> Map.fetch!("result") |> Map.fetch!("content") |> List.first() |> Map.fetch!("text") ==
             ~s({"error":"unknown_tool:\\"no_such_verb\\""})
  end

  # ------------------------------------------------------------------
  # (+) MCP refuse seals a real Receipt, durably readable on the lawful read path
  # ------------------------------------------------------------------

  test "refuse over MCP seals a durable Receipt readable on /execution/epochs/:id/receipts", %{
    conn: conn
  } do
    provider = "w745-refuse-#{System.unique_integer([:positive])}"
    {_run, epoch, claim} = claimed(conn, provider)

    assert {false, refused} =
             tool_call(conn, "refuse", %{
               lease_token: claim["lease_token"],
               reason: "unregistered_actuation"
             })

    assert refused == %{
             "status" => "refused",
             "epoch_id" => epoch.id,
             "outcome" => "refused"
           }

    # The epoch landed terminal through the atomic lease-guarded write.
    assert %Epoch{state: :failed} = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)

    # Durable Receipt row, read back on the REAL read surface (org-less
    # legacy tier keeps the unscoped read).
    conn_receipts =
      conn
      |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
      |> get("/internal-api/execution/epochs/#{epoch.id}/receipts")

    epoch_id = epoch.id

    assert %{"epoch_id" => ^epoch_id, "receipts" => [receipt]} = json_response(conn_receipts, 200)

    assert receipt["outcome"] == "refused"
    assert receipt["evidence"]["refusal_reason"] == "unregistered_actuation"
    assert receipt["epoch_id"] == epoch.id
  end
end
