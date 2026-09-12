defmodule XaasWeb.McpLibraryToolsTest do
  @moduledoc """
  Real Chicago-style integration test for the `/mcp` scope
  (`lib/xaas_web/router.ex:87-98`), which forwards to the real
  `AshAi.Mcp.Router` serving the tools declared in `Xaas.Library`'s
  `tools do` block (`lib/xaas/library.ex:20-24`):

      tool :list_books, Xaas.Library.Book, :read
      tool :books_by_grade_band, Xaas.Library.Book, :by_grade_band
      tool :active_curations_for_grade, Xaas.Library.Curation, :active_for_grade

  No mocking of the MCP layer: this drives the real JSON-RPC 2.0 protocol
  over a real HTTP POST against the real test-mode Phoenix endpoint,
  through the real `:require_internal_api_token` bearer-auth plug, into
  the real `AshAi.Mcp.Server`, executing the real `books_by_grade_band`
  Ash read action against real seeded `Book` rows in the real sandboxed
  Postgres -- and asserts on the real decoded JSON-RPC response body.

  Protocol shape confirmed by reading `deps/ash_ai/lib/ash_ai/mcp/server.ex`
  directly (not assumed): the router's `protocol_version_statement:
  "2024-11-05"` selects the initialize-based flow
  (`per_request_version?/2`, server.ex:119-133), which requires a real
  `initialize` call first (`process_message/3`, server.ex:680-704) before
  `tools/call` (server.ex:792-813) will resolve a tool by name.
  """

  use XaasWeb.ConnCase

  alias Xaas.Library.Book

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp mcp_post(conn, body) do
    conn
    |> with_internal_api_token()
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
          "clientInfo" => %{"name" => "mcp_library_tools_test", "version" => "0.0.0"}
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

  test "POST /mcp tools/call books_by_grade_band returns real seeded Book rows via real JSON-RPC", %{
    conn: conn
  } do
    tag = "mcp-library-tools-test-#{System.unique_integer([:positive])}"

    in_band =
      Book
      |> Ash.Changeset.for_create(:create, %{
        title: "#{tag}-in-band",
        author: "In Band Author",
        grade_level: Decimal.new("4.0")
      })
      |> Ash.create!(authorize?: false)

    _out_of_band =
      Book
      |> Ash.Changeset.for_create(:create, %{
        title: "#{tag}-out-of-band",
        author: "Out Of Band Author",
        grade_level: Decimal.new("9.0")
      })
      |> Ash.create!(authorize?: false)

    session_id = initialize!(conn)

    conn =
      build_conn()
      |> put_req_header("mcp-session-id", session_id)
      |> mcp_post(%{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/call",
        "params" => %{
          "name" => "books_by_grade_band",
          "arguments" => %{"input" => %{"min_grade" => 3, "max_grade" => 5}}
        }
      })

    body = json_response(conn, 200)

    assert body["jsonrpc"] == "2.0"
    assert body["id"] == 2
    assert body["result"]["isError"] == false

    [%{"type" => "text", "text" => encoded_text}] = body["result"]["content"]
    decoded = Jason.decode!(encoded_text)

    titles = Enum.map(decoded, & &1["title"])

    assert "#{tag}-in-band" in titles
    refute "#{tag}-out-of-band" in titles

    returned_book = Enum.find(decoded, &(&1["id"] == in_band.id))
    assert returned_book["author"] == "In Band Author"
  end

  test "POST /mcp tools/call rejects a request with no bearer token", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json")
      |> post("/mcp", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{"protocolVersion" => "2024-11-05", "capabilities" => %{}}
      })

    assert conn.status == 401
  end
end
