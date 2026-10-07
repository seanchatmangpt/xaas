defmodule XaasWeb.GraphqlHttpSurfaceTest do
  @moduledoc """
  SPEC-30 (W819/W802-GAP-1; lane W975b design-wave 4) court: GraphQL is
  actually mounted over HTTP at POST /api/graphql behind the real
  `:require_internal_api_token` floor.

  Mirrors W750's block-(a) real-HTTP round trip: a ConnCase GET/POST
  through the real router, not `Absinthe.run/3`. Falsifier (W819): before
  this lane the surface answered 404, so a mounted-and-gated 200 with a
  real schema payload could not exist; the 401 leg pins the CLAUDE.md
  API-auth floor (no unauthenticated sibling route).
  """

  use XaasWeb.ConnCase, async: false

  @token System.fetch_env!("INTERNAL_API_TOKEN")

  # Xaas.Repo (the Ash resource repo) needs its own sandbox checkout --
  # ConnCase's setup covers Xaas.LegacyRepo only.
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp post_query(conn, query, opts \\ []) do
    body =
      if Keyword.get(opts, :variables) do
        Jason.encode!(%{query: query, variables: Keyword.get(opts, :variables)})
      else
        Jason.encode!(%{query: query})
      end

    conn
    |> put_req_header("authorization", "Bearer " <> @token)
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> post("/api/graphql", body)
  end

  test "refuses unauthenticated probe with 401 (token floor, not 404/406 leak)" do
    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json")
      |> post("/api/graphql", Jason.encode!(%{query: "{ sayHello }"}))

    assert conn.status == 401
  end

  test "authenticated POST returns a real schema payload (sayHello)" do
    conn = post_query(build_conn(), "{ sayHello }")

    assert conn.status == 200
    assert %{"data" => %{"sayHello" => "Hello from AshGraphql!"}} = json_response(conn, 200)
  end

  test "a wired-domain query returns real rows (libraryBooks)" do
    # Real collaborator: a persisted Book row, read back through the real
    # HTTP surface (Chicago: assert on final state over the wire, not on
    # interactions).
    {:ok, _book} =
      Xaas.Library.Book
      |> Ash.Changeset.for_create(:create, %{
        title: "GraphQL surface court copy",
        author: "W975b"
      })
      |> Ash.create(authorize?: false)

    conn = post_query(build_conn(), "{ libraryBooks { results { title author } } }")

    assert conn.status == 200

    %{"data" => %{"libraryBooks" => %{"results" => books}}} = json_response(conn, 200)
    assert Enum.any?(books, &(&1["title"] == "GraphQL surface court copy"))
  end

  test "registered before the /api catch-all forward (shadowing pin)" do
    # The court that kills the classic regression: if this scope moves
    # below `forward "/api"`, the forward matches first and this request
    # 404s (or falls into XaasWeb.ApiRouter's unknown-route behavior)
    # instead of answering GraphQL. Asserts the route table, not the
    # behavior above, so the regression is caught at the routing layer.
    paths =
      Phoenix.Router.routes(XaasWeb.Router)
      |> Enum.map(& &1.path)

    graphql_index =
      Enum.find_index(paths, &(&1 == "/api/graphql"))

    api_forward_index =
      Enum.find_index(paths, &(&1 == "/api"))

    assert graphql_index < api_forward_index
  end

  test "errors surface as 200-with-errors Absinthe envelope (not a crash)" do
    conn = post_query(build_conn(), "{ nonexistentField }")

    assert conn.status == 200
    %{"errors" => _} = json_response(conn, 200)
  end
end
