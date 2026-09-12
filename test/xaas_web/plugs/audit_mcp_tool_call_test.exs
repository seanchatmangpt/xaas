defmodule XaasWeb.Plugs.AuditMcpToolCallTest do
  @moduledoc """
  Real Chicago-style tests for `XaasWeb.Plugs.AuditMcpToolCall`: a real
  `Plug.Test.conn/3` request run through the actual `call/2`, a real
  `Ash.create!`-backed write to the real `Xaas.Operations.AuditLogEntry`
  resource in the real sandboxed `Xaas.Repo`, and real `Ash.read!`/
  `Ash.count!` assertions on the persisted row -- no mocking.

  Driven at the plug level (`AuditMcpToolCall.call/2` directly) rather
  than through the full `/mcp` router pipeline: the real
  `AshAi.Mcp.Router` forward this plug sits in front of expects a real
  MCP JSON-RPC tool-call envelope and a real registered tool
  implementation, which is unrelated surface area to what this plug
  itself does (write one audit row per HTTP request reaching it,
  unconditionally). Per the batch instructions, a direct plug-unit test
  is the acceptable first-layer test here since the plug is the real
  resource under test and the router-level precondition plugs
  (`RequireInternalApiToken`, `ResolveOrgActor`) are already covered by
  their own test files.
  """

  use XaasWeb.ConnCase

  alias Xaas.Operations.AuditLogEntry
  alias XaasWeb.Plugs.AuditMcpToolCall

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp mcp_conn(token) do
    :get
    |> Plug.Test.conn("/mcp/list_books?foo=bar")
    |> then(fn conn ->
      if token do
        Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> token)
      else
        conn
      end
    end)
  end

  test "a real request with a valid bearer token writes one real AuditLogEntry row with the real requested fields" do
    before_count = Ash.count!(AuditLogEntry, authorize?: false)

    token = System.fetch_env!("INTERNAL_API_TOKEN")
    conn = mcp_conn(token)

    result_conn = AuditMcpToolCall.call(conn, [])

    # Real state assertion: the plug passes the conn through unchanged
    # (does not halt or alter the response), matching its documented
    # non-blocking-audit behavior.
    assert result_conn == conn

    after_count = Ash.count!(AuditLogEntry, authorize?: false)
    assert after_count == before_count + 1

    expected_caller_id =
      "token:" <> (:crypto.hash(:sha256, token) |> Base.encode16(case: :lower) |> binary_part(0, 16))

    entry =
      AuditLogEntry
      |> Ash.read!(authorize?: false)
      |> Enum.max_by(& &1.occurred_at, DateTime)

    assert entry.action == "mcp.tool_call.invoked"
    assert entry.resource_type == "McpRequest"
    assert entry.resource_id == "/mcp/list_books"
    assert entry.actor_id == expected_caller_id
    assert entry.actor_description == "mcp caller #{expected_caller_id}"
    assert entry.metadata["caller_id"] == expected_caller_id
    assert entry.metadata["method"] == "GET"
    assert entry.metadata["path"] == "/mcp/list_books"
    assert entry.metadata["query_string"] == "foo=bar"
    assert %DateTime{} = entry.occurred_at
    assert DateTime.diff(DateTime.utc_now(), entry.occurred_at, :second) < 30
  end

  test "a real request with no authorization header still writes a real AuditLogEntry row, with actor_id \"unknown\"" do
    before_count = Ash.count!(AuditLogEntry, authorize?: false)

    conn = mcp_conn(nil)
    result_conn = AuditMcpToolCall.call(conn, [])

    assert result_conn == conn

    after_count = Ash.count!(AuditLogEntry, authorize?: false)
    assert after_count == before_count + 1

    entry =
      AuditLogEntry
      |> Ash.read!(authorize?: false)
      |> Enum.max_by(& &1.occurred_at, DateTime)

    assert entry.actor_id == "unknown"
    assert entry.actor_description == "mcp caller unknown"
    assert entry.metadata["caller_id"] == "unknown"
  end

  test "two distinct bearer tokens produce two distinct, real actor_id hashes (real per-token identity, no collision)" do
    conn_a = mcp_conn("token-a-#{System.unique_integer([:positive])}")
    conn_b = mcp_conn("token-b-#{System.unique_integer([:positive])}")

    AuditMcpToolCall.call(conn_a, [])
    AuditMcpToolCall.call(conn_b, [])

    [entry_b, entry_a | _] =
      AuditLogEntry
      |> Ash.read!(authorize?: false)
      |> Enum.sort_by(& &1.occurred_at, {:desc, DateTime})

    refute entry_a.actor_id == entry_b.actor_id
    assert String.starts_with?(entry_a.actor_id, "token:")
    assert String.starts_with?(entry_b.actor_id, "token:")
  end
end
