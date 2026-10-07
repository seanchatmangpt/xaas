defmodule W728.MountedMcpApp do
  use Plug.Router
  plug XaasWeb.Plugs.AuditMcpToolCall
  plug :match
  plug :dispatch

  get "/list_books" do
    send_resp(conn, 200, "[]")
  end

  match _ do
    send_resp(conn, 400, "bad request")
  end
end

defmodule W728.TestRouter do
  use Plug.Router
  plug :match
  plug :dispatch

  forward "/mcp", to: W728.MountedMcpApp

  match _ do
    send_resp(conn, 404, "not found")
  end
end

defmodule Xaas.Operations.AuditLogDeepeningTest do
  @moduledoc """
  Real Chicago-style deepening tests for the `/mcp` audit trail:
  `Xaas.Operations.AuditLogEntry` rows written by
  `XaasWeb.Plugs.AuditMcpToolCall` — one row per `/mcp` HTTP request,
  deliberately scoped to `/mcp` (see the plug moduledoc and
  `XaasWeb.Router`'s `/mcp` scope).

  Driven through a real Plug.Router surface mounted inside this test
  file: the real `AuditMcpToolCall` plug is plugged *only* in the
  mounted `/mcp` app (mirroring `XaasWeb.Router`'s real pipeline
  shape), so requests dispatch through real HTTP pipeline semantics
  rather than `AuditMcpToolCall.call/2` being invoked by hand. Real
  rows in the real sandboxed `Xaas.Repo`, real `Ash.count!`/`Ash.read!`
  assertions, no mocks.

  No `@moduletag :eu_ai_act`: these rows are the `/mcp` observability
  fix from a closed ERRC item, not an Art 12 record-keeping surface —
  the EU-AI-Act record-keeping chain is `Xaas.Semantics.*`, and nothing
  in this resource's moduledoc or writers claims Art 12 provenance.
  """

  use XaasWeb.ConnCase

  alias Xaas.Operations.AuditLogEntry

  # The mounted /mcp-ish surface lives at the top of this file
  # (W728.MountedMcpApp / W728.TestRouter): the real plug runs only
  # inside the mounted /mcp app, matching the production router shape
  # (plug in the /mcp scope, before the MCP router is forwarded to).
  # `match _` at the end of the mounted app is the real
  # "malformed/unknown tool path" behavior: it never halts the audit
  # write, which runs before dispatch.

  # AuditLogEntry lives in Xaas.Repo; ConnCase's sandbox is scoped to
  # Xaas.LegacyRepo, so check out Xaas.Repo directly (same pattern as
  # test/xaas_web/plugs/audit_mcp_tool_call_test.exs).
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp call_router(conn), do: W728.TestRouter.call(conn, W728.TestRouter.init([]))

  defp mcp_conn(method, path) do
    method
    |> Plug.Test.conn(path)
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp mcp_conn(path), do: mcp_conn(:get, path)

  defp latest_entry do
    AuditLogEntry
    |> Ash.read!(authorize?: false)
    |> Enum.max_by(& &1.occurred_at, DateTime)
  end

  test "(a) one real /mcp request writes exactly one audit row with the real tool path and token-derived actor fields" do
    before_count = Ash.count!(AuditLogEntry, authorize?: false)

    conn =
      mcp_conn("/mcp/list_books?grade_band=middle")
      |> call_router()

    assert conn.status == 200 and conn.resp_body == "[]"

    assert Ash.count!(AuditLogEntry, authorize?: false) == before_count + 1

    entry = latest_entry()

    expected_caller_id =
      "token:" <>
        (:crypto.hash(:sha256, System.fetch_env!("INTERNAL_API_TOKEN"))
         |> Base.encode16(case: :lower)
         |> binary_part(0, 16))

    assert entry.action == "mcp.tool_call.invoked"
    assert entry.resource_type == "McpRequest"
    assert entry.resource_id == "/mcp/list_books"
    assert entry.actor_id == expected_caller_id
    assert entry.actor_description == "mcp caller #{expected_caller_id}"
    assert entry.metadata["method"] == "GET"
    assert entry.metadata["path"] == "/mcp/list_books"
    assert entry.metadata["query_string"] == "grade_band=middle"
    assert %DateTime{} = entry.occurred_at
  end

  test "(b) non-/mcp paths write nothing (scope pin)" do
    before_count = Ash.count!(AuditLogEntry, authorize?: false)

    conn =
      :get
      |> Plug.Test.conn("/api/books")
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
      |> call_router()

    assert conn.status == 404 and conn.resp_body == "not found"

    assert Ash.count!(AuditLogEntry, authorize?: false) == before_count
  end

  test "(c) malformed/unknown /mcp path is still audited — the real plug runs pre-dispatch, unconditionally" do
    before_count = Ash.count!(AuditLogEntry, authorize?: false)

    conn =
      mcp_conn(:post, "/mcp/definitely_not_a_tool")
      |> Plug.Conn.put_req_header("content-type", "application/json")
      |> Plug.Conn.put_req_header("content-length", "2")
      |> Plug.Conn.assign(:raw_body, "{\"x\":")
      |> call_router()

    assert conn.status == 400 and conn.resp_body == "bad request"

    assert Ash.count!(AuditLogEntry, authorize?: false) == before_count + 1

    entry = latest_entry()
    assert entry.action == "mcp.tool_call.invoked"
    assert entry.resource_id == "/mcp/definitely_not_a_tool"
    assert entry.metadata["method"] == "POST"
  end

  test "(d) rows are immutable per the resource's real actions: no :update or :destroy action exists" do
    conn = mcp_conn("/mcp/list_books")
    call_router(conn)
    entry = latest_entry()

    # The resource defines only :read and :create — there is no primary
    # update/destroy action at all, so even a direct Ash.update/destroy
    # call cannot reach the row (and the policy floor would forbid them
    # anyway).
    assert_raise RuntimeError, ~r/Required primary update action/, fn ->
      Ash.update(entry, %{})
    end

    # destroy/1 resolves its action lazily and returns the typed error
    # instead of raising -- real observed behavior, asserted as such.
    assert {:error, %Ash.Error.Invalid{errors: errors}} = Ash.destroy(entry)
    assert Enum.any?(errors, &String.contains?(inspect(&1), "NoPrimaryAction"))

    # The row really is still there, byte-identical in its key fields.
    reread = Ash.get!(AuditLogEntry, entry.id, authorize?: false)
    assert reread.action == entry.action
    assert reread.resource_id == entry.resource_id
    assert reread.actor_id == entry.actor_id
    assert reread.metadata == entry.metadata
  end
end
