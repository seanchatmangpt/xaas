defmodule XaasWeb.McpToolsDeepeningTest do
  @moduledoc """
  Tool-surface court for the production `/mcp` MCP server
  (`lib/xaas_web/router.ex` `/mcp` scope -> `XaasWeb.McpScope.mount/0` ->
  real `AshAi.Mcp.Router` serving the 3 Library read tools declared in
  `Xaas.Library`'s `tools do` block). Complements the W728 audit-log
  courts (`test/xaas_web/plugs/audit_mcp_tool_call_test.exs`, plug-level)
  with the missing tool-surface layer: real ConnCase JSON-RPC 2.0 POSTs
  through the real pipeline (:api -> :require_internal_api_token ->
  :resolve_org_actor -> :audit_mcp_tool_call -> AshAi.Mcp.Router).

  No mocking: real bearer-token auth, real `initialize` session flow
  (protocol "2024-11-05", per `deps/ash_ai/lib/ash_ai/mcp/server.ex`
  `per_request_version?/2`), real Ash reads against real seeded `Book`
  rows in the real sandboxed Postgres, real `AuditLogEntry` rows counted
  in the same sandbox.

  Courts:
    (a) tools/list exposes exactly the 3 documented tool names
    (b) tools/call :list_books returns the real seeded rows
    (c) tools/call :books_by_grade_band filtering semantics on real rows
    (d) unknown tool -> the real typed JSON-RPC -32602 error
    (e) one real AuditLogEntry row per /mcp HTTP request (cross-check of
        W728's contract at the router level)
    (f) determinism: identical calls return identical decoded payloads
  """

  use XaasWeb.ConnCase

  require Ash.Query

  alias Xaas.Library.Book
  alias Xaas.Operations.AuditLogEntry

  @tool_names MapSet.new(["list_books", "books_by_grade_band", "active_curations_for_grade"])

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp mcp_post(conn, body) do
    conn
    |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> post("/mcp", Jason.encode!(body))
  end

  defp initialize!(conn) do
    conn =
      mcp_post(conn, %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => "2024-11-05",
          "capabilities" => %{},
          "clientInfo" => %{"name" => "mcp_tools_deepening_test", "version" => "0.0.0"}
        }
      })

    body = json_response(conn, 200)
    assert body["result"]["protocolVersion"] == "2024-11-05"

    session_id =
      conn
      |> get_resp_header("mcp-session-id")
      |> List.first()

    assert is_binary(session_id) and byte_size(session_id) > 0
    session_id
  end

  defp call_tool(_conn, session_id, name, args, id) do
    build_conn()
    |> put_req_header("mcp-session-id", session_id)
    |> mcp_post(%{
      "jsonrpc" => "2.0",
      "id" => id,
      "method" => "tools/call",
      "params" => %{"name" => name, "arguments" => args}
    })
    |> json_response(200)
  end

  defp tool_text(body) do
    assert body["jsonrpc"] == "2.0"
    assert body["result"]["isError"] == false

    [%{"type" => "text", "text" => encoded}] = body["result"]["content"]
    Jason.decode!(encoded)
  end

  defp audit_count do
    AuditLogEntry
    |> Ash.Query.filter(action == "mcp.tool_call.invoked")
    |> Ash.count!(authorize?: false)
  end

  # (a) tools/list exposes exactly the 3 documented tools.
  test "tools/list returns exactly the 3 documented Library tools", %{conn: conn} do
    session_id = initialize!(conn)

    body =
      build_conn()
      |> put_req_header("mcp-session-id", session_id)
      |> mcp_post(%{"jsonrpc" => "2.0", "id" => 2, "method" => "tools/list"})
      |> json_response(200)

    assert body["id"] == 2

    names =
      body["result"]["tools"]
      |> Enum.map(& &1["name"])
      |> MapSet.new()

    assert names == @tool_names
  end

  # (b) :list_books returns the real seeded rows.
  test "tools/call :list_books returns real seeded Book rows", %{conn: conn} do
    tag = "mcp-deepen-list-#{System.unique_integer([:positive])}"

    created =
      Book
      |> Ash.Changeset.for_create(:create, %{
        title: "#{tag}-A",
        author: "Deepen Author A",
        grade_level: Decimal.new("2.0")
      })
      |> Ash.create!(authorize?: false)

    session_id = initialize!(conn)

    decoded = conn |> call_tool(session_id, "list_books", %{}, 3) |> tool_text()

    row = Enum.find(decoded, &(&1["id"] == created.id))
    assert row, "expected seeded book #{created.id} in list_books output"
    assert row["title"] == "#{tag}-A"
    assert row["author"] == "Deepen Author A"
  end

  # (c) :books_by_grade_band filtering semantics on real rows.
  test "tools/call :books_by_grade_band filters on real grade_level rows", %{conn: conn} do
    tag = "mcp-deepen-band-#{System.unique_integer([:positive])}"

    create_book = fn title, grade ->
      Book
      |> Ash.Changeset.for_create(:create, %{
        title: title,
        author: "Band Author",
        grade_level: grade
      })
      |> Ash.create!(authorize?: false)
    end

    _low = create_book.("#{tag}-low", Decimal.new("1.0"))
    mid = create_book.("#{tag}-mid", Decimal.new("5.0"))
    _high = create_book.("#{tag}-high", Decimal.new("8.0"))

    session_id = initialize!(conn)

    body =
      call_tool(conn, session_id, "books_by_grade_band", %{"input" => %{"min_grade" => 4, "max_grade" => 6}}, 4)

    decoded = tool_text(body)

    titles = Enum.map(decoded, & &1["title"])
    assert "#{tag}-mid" in titles
    refute "#{tag}-low" in titles
    refute "#{tag}-high" in titles

    returned = Enum.find(decoded, &(&1["id"] == mid.id))
    assert returned["title"] == "#{tag}-mid"
  end

  # (d) unknown tool -> real typed JSON-RPC -32602 error.
  test "tools/call with an unknown tool name returns the real -32602 error", %{conn: conn} do
    session_id = initialize!(conn)

    body =
      build_conn()
      |> put_req_header("mcp-session-id", session_id)
      |> mcp_post(%{
        "jsonrpc" => "2.0",
        "id" => 5,
        "method" => "tools/call",
        "params" => %{"name" => "no_such_tool_xyz", "arguments" => %{}}
      })
      |> json_response(200)

    assert body["id"] == 5
    assert body["error"]["code"] == -32_602
    assert body["error"]["message"] =~ "Tool not found: no_such_tool_xyz"
  end

  # (e) one audit row per /mcp HTTP request (router-level cross-check of W728).
  test "each /mcp request writes exactly one AuditLogEntry row", %{conn: conn} do
    before = audit_count()

    session_id = initialize!(conn)
    assert audit_count() == before + 1

    _b1 = call_tool(conn, session_id, "list_books", %{}, 6)

    _b2 =
      call_tool(
        conn,
        session_id,
        "books_by_grade_band",
        %{"input" => %{"min_grade" => 1, "max_grade" => 12}},
        7
      )

    assert audit_count() == before + 3
  end

  # (f) determinism: identical calls, identical decoded payloads.
  test "identical tools/call requests return identical decoded payloads", %{conn: conn} do
    tag = "mcp-deepen-det-#{System.unique_integer([:positive])}"

    _seed =
      Book
      |> Ash.Changeset.for_create(:create, %{
        title: "#{tag}-x",
        author: "Det Author",
        grade_level: Decimal.new("3.0")
      })
      |> Ash.create!(authorize?: false)

    session_id = initialize!(conn)

    args = %{"input" => %{"min_grade" => 2, "max_grade" => 4}}
    first = call_tool(conn, session_id, "books_by_grade_band", args, 8)
    second = call_tool(conn, session_id, "books_by_grade_band", args, 9)

    assert tool_text(first) == tool_text(second)
    assert first["error"] == second["error"]
    assert first["error"] == nil
  end
end
