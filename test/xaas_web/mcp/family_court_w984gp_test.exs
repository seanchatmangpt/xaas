defmodule XaasWeb.Mcp.FamilyCourtW984gpTest do
  @moduledoc """
  Lane W984gp unclaimed-family probe court for the MCP surface
  (`lib/xaas_web/mcp_scope.ex`, `lib/xaas_web/mcp_descriptor.ex`,
  `lib/xaas_web/plugs/audit_mcp_tool_call.ex` behind the `/mcp` router
  scope). Census result:

  - `XaasWeb.McpDescriptor` -- UNCOVERED: zero module references in
    test/ before this file.
  - `XaasWeb.McpScope` -- indirectly covered (real `/mcp` HTTP traffic
    in `test/xaas_web/mcp_library_tools_test.exs` and
    `test/xaas_web/mcp_tools_deepening_test.exs` exercises the generated
    `mount/0` forward), but the descriptor<->router tool-set contract is
    not asserted anywhere.
  - `XaasWeb.Plugs.AuditMcpToolCall` -- covered at plug level
    (`test/xaas_web/plugs/audit_mcp_tool_call_test.exs`) and one-count
    at router level (`mcp_tools_deepening_test.exs`), but its
    `metadata` fidelity branch (method/path/query_string recording) and
    the router-level "no audit row for unauthenticated traffic" auth
    ordering are unexercised.

  Real Chicago-style: real ConnCase through the real endpoint and
  router, real bearer token per the existing INTERNAL_API_TOKEN
  convention, real sandboxed Postgres, zero mocks.
  """

  use XaasWeb.ConnCase

  import Ash.Expr
  require Ash.Query

  alias Xaas.Operations.AuditLogEntry

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp mcp_post(conn, body) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> post("/mcp", Jason.encode!(body))
  end

  defp audit_count do
    AuditLogEntry
    |> Ash.Query.filter(expr(action == "mcp.tool_call.invoked"))
    |> Ash.count!(authorize?: false)
  end

  # ============================================================================
  # A. XaasWeb.McpDescriptor -- describe/1 exact descriptor shape
  # ============================================================================

  describe "XaasWeb.McpDescriptor.describe/1" do
    @tag :w984gp
    test "returns the exact descriptor map for a registered MCP capability" do
      # Mutation rationale: deleting any field from the :list_books
      # descriptor row (e.g. dropping ash_action or observation_scope)
      # makes this exact-shape assertion fail.
      assert {:ok, descriptor} = XaasWeb.McpDescriptor.describe(:list_books)

      assert descriptor == %{
               name: "List books",
               description: "List books for a grade band (HDDL task: MCP-INSPECT-CATALOG)",
               exposed_via: :mcp,
               observation_scope: :read_only,
               mutation_scope: :none,
               requires_authority: false,
               reversible: true,
               receipt_semantics: :none,
               ash_action: "Xaas.Library.list_books/1"
             }
    end

    @tag :w984gp
    test "returns :error for an unregistered capability id" do
      # Mutation rationale: replacing `Map.fetch` with a fallback
      # descriptor for unknown ids makes this fail.
      assert :error = XaasWeb.McpDescriptor.describe(:no_such_capability_w984gp)
    end
  end

  # ============================================================================
  # B. XaasWeb.McpDescriptor -- fail-closed authority check
  # ============================================================================

  describe "XaasWeb.McpDescriptor.requires_authority?/1" do
    @tag :w984gp
    test "is fail-closed for an unregistered capability id" do
      # Mutation rationale: the documented deny-by-default branch
      # (`:error -> true` in mcp_descriptor.ex:106-111). Flipping it to
      # `:error -> false` makes an unregistered capability appear
      # authority-free -- this assertion is the guard.
      assert XaasWeb.McpDescriptor.requires_authority?(:no_such_capability_w984gp) == true
    end

    @tag :w984gp
    test "returns the registered descriptor values, including the a2a mutation row" do
      # Mutation rationale: flipping requires_authority on the
      # consequential :checkout row (or any read row) breaks this.
      assert XaasWeb.McpDescriptor.requires_authority?(:checkout) == true
      assert XaasWeb.McpDescriptor.requires_authority?(:list_books) == false
      assert XaasWeb.McpDescriptor.requires_authority?(:"hddl-plan") == false
    end
  end

  # ============================================================================
  # C. Descriptor <-> router contract (XaasWeb.McpScope.mount/0)
  # ============================================================================

  describe "descriptor/router tool-set contract" do
    @tag :w984gp
    test "real tools/list over POST /mcp exposes exactly the descriptor's :mcp rows" do
      # Mutation rationale: adding a tool to XaasWeb.McpScope.mount/0
      # without a descriptor row (or removing one descriptor marks as
      # :mcp) makes the two generated surfaces diverge -- this
      # cross-surface assertion is the only place that equality is
      # pinned. Exercises the real initialize + tools/list flow through
      # the real router and AshAi.Mcp.Router.
      mcp_ids =
        XaasWeb.McpDescriptor.capabilities()
        |> Enum.filter(fn {_id, d} -> d.exposed_via == :mcp end)
        |> Enum.map(fn {id, _} -> Atom.to_string(id) end)
        |> MapSet.new()

      conn =
        build_conn()
        |> with_internal_api_token()
        |> mcp_post(%{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => %{
            "protocolVersion" => "2024-11-05",
            "capabilities" => %{},
            "clientInfo" => %{"name" => "family_court_w984gp", "version" => "0.0.0"}
          }
        })

      body = json_response(conn, 200)
      assert body["result"]["protocolVersion"] == "2024-11-05"

      session_id =
        conn |> get_resp_header("mcp-session-id") |> List.first()

      assert is_binary(session_id) and byte_size(session_id) > 0

      tools =
        build_conn()
        |> with_internal_api_token()
        |> put_req_header("mcp-session-id", session_id)
        |> mcp_post(%{"jsonrpc" => "2.0", "id" => 2, "method" => "tools/list"})
        |> json_response(200)

      names =
        tools["result"]["tools"]
        |> Enum.map(& &1["name"])
        |> MapSet.new()

      assert names == mcp_ids
      assert MapSet.size(names) == 3
    end
  end

  # ============================================================================
  # D. Auth gating consistency with the internal-api floor
  # ============================================================================

  describe "/mcp auth gating consistency" do
    @tag :w984gp
    test "no bearer token -> 401 with the standard envelope and ZERO audit rows" do
      # Mutation rationale: (1) relaxing :require_internal_api_token to
      # accept unauthenticated /mcp traffic, or (2) moving
      # :audit_mcp_tool_call before the auth plug so unauthenticated
      # calls write rows -- either mutation fails this exactly-one-of
      # assertion (status stays 401, count stays 0).
      before = audit_count()

      conn =
        build_conn()
        |> mcp_post(%{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => %{"protocolVersion" => "2024-11-05", "capabilities" => %{}}
        })

      assert conn.status == 401
      assert %{"error" => "unauthorized"} = json_response(conn, 401)
      assert audit_count() == before
    end

    @tag :w984gp
    test "wrong bearer token and non-Bearer schemes are both 401 with zero audit rows" do
      # Mutation rationale: bearer_token/1 accepting an empty or
      # non-"Bearer " scheme header (require_internal_api_token.ex:129-134)
      # would flip one of these to non-401; audit rows appearing would
      # mean the audit plug ran before validation.
      before = audit_count()

      wrong =
        build_conn()
        |> put_req_header("authorization", "Bearer definitely-not-the-token")
        |> mcp_post(%{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => %{"protocolVersion" => "2024-11-05", "capabilities" => %{}}
        })

      assert wrong.status == 401

      basic =
        build_conn()
        |> put_req_header("authorization", "Basic dXNlcjpwYXNz")
        |> mcp_post(%{
          "jsonrpc" => "2.0",
      "id" => 1,
          "method" => "initialize",
          "params" => %{"protocolVersion" => "2024-11-05", "capabilities" => %{}}
        })

      assert basic.status == 401

      assert audit_count() == before
    end
  end

  # ============================================================================
  # E. AuditMcpToolCall metadata fidelity at the router level
  # ============================================================================

  describe "AuditMcpToolCall audit-row fidelity" do
    @tag :w984gp
    test "an authenticated /mcp call records method, path, and query_string" do
      # Mutation rationale: dropping any key from the plug's metadata map
      # (audit_mcp_tool_call.ex:69-74), or recording conn.request_path
      # into resource_id incorrectly, fails these assertions.
      before = audit_count()

      conn =
        build_conn()
        |> with_internal_api_token()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("accept", "application/json")
        |> post("/mcp?lane=w984gp", Jason.encode!(%{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => %{
            "protocolVersion" => "2024-11-05",
            "capabilities" => %{},
            "clientInfo" => %{"name" => "family_court_w984gp", "version" => "0.0.0"}
          }
        }))

      assert conn.status == 200

      entries =
        AuditLogEntry
        |> Ash.Query.filter(expr(action == "mcp.tool_call.invoked"))
        |> Ash.read!(authorize?: false)

      assert length(entries) == before + 1

      entry = entries |> Enum.max_by(& &1.occurred_at)
      token = System.fetch_env!("INTERNAL_API_TOKEN")

      expected_caller =
        "token:" <>
          (:crypto.hash(:sha256, token) |> Base.encode16(case: :lower) |> binary_part(0, 16))

      assert entry.actor_id == expected_caller
      assert entry.action == "mcp.tool_call.invoked"
      assert entry.resource_id == "/mcp"
      assert entry.metadata["method"] == "POST"
      assert entry.metadata["path"] == "/mcp"
      assert entry.metadata["query_string"] == "lane=w984gp"
      assert entry.metadata["caller_id"] == expected_caller
      assert entry.actor_description == "mcp caller #{expected_caller}"
    end
  end
end
