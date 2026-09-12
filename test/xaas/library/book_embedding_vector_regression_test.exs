defmodule Xaas.Library.BookEmbeddingVectorRegressionTest do
  @moduledoc """
  Regression guard for the `Book.embedding` `Ash.Vector` bug class.

  ## Sweep context (docs/vision/vision-2030-2026-09-09-0338.md cycle)

  A repo-wide sweep for `Ash.Vector` occurrences outside excluded paths found
  no remaining unfixed call site: `lib/xaas/library/ranker.ex:242-247`
  (`compute_semantic_score/2`) already pattern-matches `%Ash.Vector{} = vec`
  and calls `Ash.Vector.to_list/1`; `lib/xaas/library/score_book.ex` does the
  same; `test/xaas/library/next_read_test.exs:85-90` already asserts
  `%Ash.Vector{} = book.embedding`. The only remaining occurrences are
  moduledoc/comment prose (`book.ex:9,57`, `local_nx.ex:17`).

  Per the cycle's fallback instruction, this file is the real regression
  guard: it exercises the actual create path, the actual update path, the
  real `/mcp` `list_books` JSON-RPC tool call, and the real `Xaas.Library.Ranker`
  and `XaasWeb.A2A.NextReadUserAgent` consumers end to end against a real
  sandboxed Postgres (no mocking), asserting at every hop that
  `Book.embedding` is a real `%Ash.Vector{}` struct -- never a bare list --
  and that no consumer crashes on the shape it actually receives. If a
  future change reintroduces a bare-list assumption anywhere on these real
  paths, this file fails fast instead of silently degrading.
  """
  use XaasWeb.ConnCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.{Book, Config, Ranker}
  require Ash.Query

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  # This file's own defaults (grade_level as a Decimal, a longer
  # synopsis template deliberately crafted for the embedding/vector path
  # this file regression-guards) differ from Xaas.Generator.create_book!/1's
  # own generic defaults (grade_level as a plain StreamData integer,
  # Faker-generated synopsis) -- kept local since every call site below
  # depends on the real synopsis text feeding the real embedding.
  defp create_book!(attrs) do
    tag = "vector-regression-#{System.unique_integer([:positive])}"

    Xaas.Generator.create_book!(%{
      title: Map.get(attrs, :title, "#{tag}-title"),
      author: Map.get(attrs, :author, "Regression Author"),
      isbn: Map.get(attrs, :isbn, "#{tag}-isbn"),
      grade_level: Map.get(attrs, :grade_level, Decimal.new("5.0")),
      genres: Map.get(attrs, :genres, ["Fiction"]),
      synopsis: Map.get(attrs, :synopsis, "A #{tag} synopsis about adventure and discovery."),
      available_copies: Map.get(attrs, :available_copies, 2),
      total_copies: Map.get(attrs, :total_copies, 2)
    })
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

  defp mcp_initialize!(conn) do
    conn =
      mcp_post(conn, %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => "2024-11-05",
          "capabilities" => %{},
          "clientInfo" => %{"name" => "vector_regression_test", "version" => "0.0.0"}
        }
      })

    body = json_response(conn, 200)
    assert body["result"]["protocolVersion"] == "2024-11-05"

    session_id = conn |> get_resp_header("mcp-session-id") |> List.first()
    assert is_binary(session_id) and byte_size(session_id) > 0
    session_id
  end

  test "1. real create path: Book.embedding is a real %Ash.Vector{}, never a bare list" do
    book = create_book!(%{})

    assert %Ash.Vector{} = book.embedding
    refute is_list(book.embedding)
    assert length(Ash.Vector.to_list(book.embedding)) == 384
  end

  test "2. real update path: Book.embedding stays a real %Ash.Vector{} after re-vectorizing synopsis" do
    book = create_book!(%{synopsis: "Original synopsis about a lighthouse keeper."})
    assert %Ash.Vector{} = book.embedding
    assert length(Ash.Vector.to_list(book.embedding)) == 384

    updated =
      book
      |> Ash.Changeset.for_update(:update, %{
        synopsis: "Completely different synopsis about a submarine crew."
      })
      |> Ash.update!(authorize?: false)

    assert %Ash.Vector{} = updated.embedding
    refute is_list(updated.embedding)
    updated_vector = Ash.Vector.to_list(updated.embedding)
    assert length(updated_vector) == 384

    # Reload independently to prove Postgres/Ecto round-trips it as a real
    # Ash.Vector on read too, not just on the in-memory changeset result.
    reloaded = Ash.get!(Book, updated.id, authorize?: false)
    assert %Ash.Vector{} = reloaded.embedding
    refute is_list(reloaded.embedding)
  end

  test "3. real /mcp list_books JSON-RPC call returns real books whose embeddings never crash JSON encoding or the reload path" do
    book = create_book!(%{title: "MCP Vector Avatar Book"})
    assert %Ash.Vector{} = book.embedding

    conn = build_conn()
    session_id = mcp_initialize!(conn)

    conn =
      build_conn()
      |> put_req_header("mcp-session-id", session_id)
      |> mcp_post(%{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/call",
        "params" => %{
          "name" => "list_books",
          "arguments" => %{"input" => %{}}
        }
      })

    body = json_response(conn, 200)
    assert body["result"]["isError"] == false

    [%{"type" => "text", "text" => encoded_text}] = body["result"]["content"]
    decoded = Jason.decode!(encoded_text)

    returned = Enum.find(decoded, &(&1["id"] == book.id))
    assert returned["title"] == "MCP Vector Avatar Book"

    # The MCP JSON-RPC response never crashed while encoding an
    # Ash.Vector-backed field, and the underlying record independently
    # reloads as a real %Ash.Vector{} (proving the tool call didn't force
    # or corrupt it into a bare list as a side effect).
    reloaded = Ash.get!(Book, book.id, authorize?: false)
    assert %Ash.Vector{} = reloaded.embedding
  end

  test "4. real Ranker.rank_recommendations/3 consumes Book.embedding as %Ash.Vector{} without crashing" do
    user = Ash.Seed.seed!(User, %{email: Faker.Internet.email()})

    book1 = create_book!(%{title: "Ranker Vector Book One", grade_level: Decimal.new("5.0")})
    book2 = create_book!(%{title: "Ranker Vector Book Two", grade_level: Decimal.new("5.0")})
    assert %Ash.Vector{} = book1.embedding
    assert %Ash.Vector{} = book2.embedding

    assert {:ok, recommendations} = Ranker.rank_recommendations(user.id, 5, limit: 10)
    assert is_list(recommendations)

    returned_ids = Enum.map(recommendations, & &1.book.id)
    assert book1.id in returned_ids
    assert book2.id in returned_ids

    for rec <- recommendations do
      assert is_float(rec.score) or is_integer(rec.score)
      assert %Ash.Vector{} = rec.book.embedding
    end

    _ = Config.default_school_id()
  end

  defp task_text(task) do
    (task.artifacts ++ [%{parts: []}])
    |> Enum.flat_map(& &1.parts)
    |> Enum.map_join(" ", fn %A2A.Part.Text{text: text} -> text end)
  end

  test "5. real A2A NextReadUserAgent browse avatar exercises the same embedding path end to end without crashing" do
    agent_name = :"vector_regression_a2a_agent_#{System.unique_integer([:positive])}"
    {:ok, pid} = XaasWeb.A2A.NextReadUserAgent.start_link(name: agent_name)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    user = Ash.Seed.seed!(User, %{email: Faker.Internet.email()})

    Xaas.Library.PersonaGrant.grant!(
      "internal_api_token",
      user.id,
      "vector_regression_test",
      authorize?: false
    )

    book = create_book!(%{title: "A2A Vector Avatar Book", grade_level: Decimal.new("5.0")})
    assert %Ash.Vector{} = book.embedding

    assert {:ok, task} = A2A.call(pid, "as:#{user.id} browse grade:5")
    assert task.status.state == :completed
    assert task_text(task) =~ book.title

    # The avatar call round-tripped through Ranker -> compute_semantic_score
    # (the real Ash.Vector-consuming call site) without raising, and the
    # underlying book still reloads as a real %Ash.Vector{} afterward.
    reloaded = Ash.get!(Book, book.id, authorize?: false)
    assert %Ash.Vector{} = reloaded.embedding
  end
end
