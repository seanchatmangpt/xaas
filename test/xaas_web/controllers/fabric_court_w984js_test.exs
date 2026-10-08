defmodule XaasWeb.Controllers.FabricCourtW984jsTest do
  @moduledoc """
  W984js unclaimed-family probe on the execution-fabric controller
  (`XaasWeb.ExecutionFabricController`) — branches left unexercised by the
  existing fabric census (W745/W945/W984ej-family courts). All real
  ConnCase HTTP through the router behind the real `RequireInternalApiToken`
  bearer gate, real sandboxed Postgres, zero mocks.

  Dispositions (each test carries its own mutation rationale):

    * JSON-RPC `-32601` method-not-found arm of `rpc/1` — uncovered;
      courted.
    * `notifications/` arm of `rpc/1` — uncovered; courted at the wire
      (W984js pinned the residue `"notification"`-200; W984kk repaired it
      to the JSON-RPC 2.0-mandated silence: bare 204, no body).
    * argument-shape catch-all clauses of `heartbeat`,
      `record_provider_event`, `close_candidate`, `cancel_work` —
      uncovered; courted (a.3/c.4 cover only unknown-lease and `refuse`).
    * `surface` / `resolve_capability` missing-argument arms — uncovered
      (existing courts hit only the unknown-lease path); courted.
    * `lease_token/1` empty-binary clause via the hook surface —
      uncovered; courted.
  """

  use XaasWeb.ConnCase, async: false

  # ------------------------------------------------------------------
  # Transport helpers (real HTTP, real bearer gate)
  # ------------------------------------------------------------------

  defp mcp_post(conn, body) do
    conn
    |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    |> put_req_header("content-type", "application/json")
    |> post("/internal-api/execution/mcp", Jason.encode!(body))
  end

  defp hook_post(conn, event, body) do
    conn
    |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    |> put_req_header("content-type", "application/json")
    |> post("/internal-api/execution/hooks/#{event}", Jason.encode!(body))
  end

  defp tool_error_text(conn, name, arguments) do
    conn
    |> mcp_post(%{jsonrpc: "2.0", id: 1, method: "tools/call", params: %{"name" => name, "arguments" => arguments}})
    |> json_response(200)
    |> Map.fetch!("result")
    |> Map.fetch!("content")
    |> List.first()
    |> Map.fetch!("text")
  end

  # ------------------------------------------------------------------
  # JSON-RPC envelope arms of rpc/1
  # ------------------------------------------------------------------

  test "unknown JSON-RPC method is the typed -32601 method-not-found envelope, not a 400", %{
    conn: conn
  } do
    # Mutation rationale: deleting the `rpc(%{"id" => id, "method" => method})`
    # arm (leaving only tools/call + notifications + the invalid_request
    # catch-all) turns this request into the generic 400 bad_request, and a
    # spec-conformant MCP client loses its -32601 signal.
    conn = mcp_post(conn, %{jsonrpc: "2.0", id: 3, method: "resources/list", params: %{}})

    assert conn.status == 200

    assert %{
             "jsonrpc" => "2.0",
             "id" => 3,
             "error" => %{"code" => -32_601, "message" => "method not found: resources/list"}
           } = json_response(conn, 200)
  end

  test "tools/call with no params object falls to the -32601 arm, never a crash", %{conn: conn} do
    # Mutation rationale: guards that the method catch-all (not the rescue
    # arm) is what answers a tools/call missing its params map.
    conn = mcp_post(conn, %{jsonrpc: "2.0", id: 4, method: "tools/call"})

    assert %{"jsonrpc" => "2.0", "id" => 4, "error" => %{"code" => -32_601}} =
             json_response(conn, 200)
  end

  test "a JSON-RPC notification is answered with spec-mandated silence: bare 204, no body", %{
    conn: conn
  } do
    # W984js pinned the residue ({:ok, :notification} -> 200 "notification");
    # W984kk repaired it: mcp_typed/2 now answers {:ok, :notification} with
    # send_resp(conn, 204, "") — the JSON-RPC 2.0-mandated silence (a
    # notification gets NO response), matching fabric_controller's
    # established 204 shape. Mutation rationale: deleting the
    # {:ok, :notification} else clause sends the notification back into
    # json(conn, :notification), producing the spec-violating 200 body.
    conn = mcp_post(conn, %{jsonrpc: "2.0", method: "notifications/initialized"})

    assert conn.status == 204
    assert conn.resp_body == ""
  end

  # ------------------------------------------------------------------
  # Argument-shape catch-all clauses of the lease tools
  # ------------------------------------------------------------------

  test "heartbeat with no lease_token is the typed bare-atom lease_token_required tool error", %{
    conn: conn
  } do
    # Mutation rationale: deleting the `dispatch_tool("heartbeat", _)`
    # catch-all raises FunctionClauseError (-32603 rescue) instead of the
    # typed transport refusal.
    text = tool_error_text(conn, "heartbeat", %{})

    assert text == ~s({"error":"lease_token_required"})
  end

  test "record_provider_event without an event map is a typed tool error, never a crash", %{
    conn: conn
  } do
    text = tool_error_text(conn, "record_provider_event", %{"lease_token" => "no-such-lease"})

    assert text == ~s({"error":"lease_token_and_event_required"})
  end

  test "close_candidate without final_head is a typed tool error, never a crash", %{conn: conn} do
    text = tool_error_text(conn, "close_candidate", %{"lease_token" => "no-such-lease"})

    assert text == ~s({"error":"lease_token_and_head_required"})
  end

  test "cancel_work with neither lease_token nor reason is a typed tool error, never a crash", %{
    conn: conn
  } do
    text = tool_error_text(conn, "cancel_work", %{})

    assert text == ~s({"error":"lease_token_and_reason_required"})
  end

  # ------------------------------------------------------------------
  # Runtime-surface tools: missing-argument arms
  # ------------------------------------------------------------------

  test "surface with no lease_token is the typed WORK_NOT_FOUND surface failure", %{conn: conn} do
    # Mutation rationale: deleting the `dispatch_tool("surface", _)` arm
    # raises FunctionClauseError instead of the closed Failure vocabulary.
    text = tool_error_text(conn, "surface", %{})

    assert %{"error" => "WORK_NOT_FOUND", "failure" => failure} = Jason.decode!(text)
    assert failure["code"] == "WORK_NOT_FOUND"
    assert failure["details"]["reason"] == "lease_token_required"
  end

  test "resolve_capability with neither lease_token nor capability is the typed NO_CAPABILITY surface failure", %{
    conn: conn
  } do
    text = tool_error_text(conn, "resolve_capability", %{})

    assert %{"error" => "NO_CAPABILITY", "failure" => failure} = Jason.decode!(text)
    assert failure["code"] == "NO_CAPABILITY"
    assert failure["details"]["reason"] == "lease_token_and_capability_required"
  end

  # ------------------------------------------------------------------
  # Hook surface: lease_token/1 empty-binary clause
  # ------------------------------------------------------------------

  test "pre_tool_use with an empty-string lease_token is the same typed 403 no_lease deny", %{
    conn: conn
  } do
    # Mutation rationale: the `lease_token/1` empty-binary clause ("a token
    # that is present but blank is no token") falling back to the
    # is_binary-only clause would hand "" to Lease.admit_tool — observed as a
    # different wire shape than the contract's bare "no_lease".
    conn = hook_post(conn, "pre_tool_use", %{"tool" => "Edit", "lease_token" => ""})

    assert conn.status == 403

    assert json_response(conn, 403) == %{"decision" => "deny", "reason" => "no_lease"}
  end
end
