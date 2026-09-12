defmodule XaasWeb.McpActiveCurationsForGradeTest do
  @moduledoc """
  Real Chicago-style integration test for the `active_curations_for_grade`
  MCP tool (`lib/xaas/library.ex:20`), simulating a distinct MCP persona
  avatar from `XaasWeb.McpLibraryToolsTest`'s `books_by_grade_band` avatar:
  this one drives a real `tools/call` for
  `Xaas.Library.Curation.active_for_grade` with a real `grade_level`
  argument, over the real `/mcp` route (`lib/xaas_web/router.ex:87-98`),
  through the real `:require_internal_api_token` bearer-auth plug, into the
  real `AshAi.Mcp.Server`, executing the real Ash read action against real
  seeded `Curation` (and their parent `Book`) rows in the real sandboxed
  Postgres -- and asserts on the real decoded JSON-RPC response body.

  No mocking of the MCP layer, router, or Ash action.
  """

  use XaasWeb.ConnCase

  alias Xaas.Library.{Book, Curation}

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
          "clientInfo" => %{
            "name" => "mcp_active_curations_for_grade_test",
            "version" => "0.0.0"
          }
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

  test "POST /mcp tools/call active_curations_for_grade returns real seeded active Curation rows",
       %{conn: conn} do
    tag = "mcp-active-curations-test-#{System.unique_integer([:positive])}"

    book =
      Book
      |> Ash.Changeset.for_create(:create, %{
        title: "#{tag}-book",
        author: "Curated Author",
        grade_level: Decimal.new("4.0")
      })
      |> Ash.create!(authorize?: false)

    active_curation =
      Curation
      |> Ash.Changeset.for_create(:create, %{
        book_id: book.id,
        curated_by: "librarian-#{tag}",
        grade_band: "3-5",
        reason: "#{tag}-active-reason",
        state: :pinned,
        active: true
      })
      |> Ash.create!(authorize?: false)

    _inactive_curation =
      Curation
      |> Ash.Changeset.for_create(:create, %{
        book_id: book.id,
        curated_by: "librarian-#{tag}",
        grade_band: "3-5",
        reason: "#{tag}-inactive-reason",
        state: :suppressed,
        active: false
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
          "name" => "active_curations_for_grade",
          "arguments" => %{"input" => %{"grade_level" => 4}}
        }
      })

    body = json_response(conn, 200)

    assert body["jsonrpc"] == "2.0"
    assert body["id"] == 2
    assert body["result"]["isError"] == false

    [%{"type" => "text", "text" => encoded_text}] = body["result"]["content"]
    decoded = Jason.decode!(encoded_text)

    reasons = Enum.map(decoded, & &1["reason"])

    assert "#{tag}-active-reason" in reasons
    refute "#{tag}-inactive-reason" in reasons

    returned_curation = Enum.find(decoded, &(&1["id"] == active_curation.id))
    assert returned_curation["curated_by"] == "librarian-#{tag}"
    assert returned_curation["active"] == true
  end
end
