defmodule XaasWeb.RpcSurfaceDeepeningTest do
  @moduledoc """
  W813 deepening court for the AshTypescript RPC surface:
  POST /internal-api/rpc/run and POST /internal-api/rpc/validate,
  mounted in lib/xaas_web/router.ex inside the token-gated /internal-api
  scope (W636 repointed the release-audit router reference from the stale
  lib/kanban_web/router.ex path to lib/xaas_web/router.ex).

  Real ConnCase over the real router, real AshTypescript pipeline, real
  sandboxed Postgres. No mocks.

  Cases:
    (a) rpc/run success envelope on a sandboxed read
    (b) rpc/validate typed validation payload on bad input
    (c) unknown action typed error
    (d) W723 auth floor on this route
    (e) W636 repoint still holds
    (f) determinism
  """

  use XaasWeb.ConnCase

  @token System.fetch_env!("INTERNAL_API_TOKEN")

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  ## ------------------------------------------------------------------
  ## Request helpers
  ## ------------------------------------------------------------------

  defp rpc_post(conn, body, opts \\ []) do
    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> @token)
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> Plug.Conn.put_req_header("accept", "application/json")
    |> maybe_actor(opts[:actor])
    |> post("/internal-api/rpc/run", Jason.encode!(body))
  end

  defp validate_post(conn, body, opts \\ []) do
    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> @token)
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> Plug.Conn.put_req_header("accept", "application/json")
    |> maybe_actor(opts[:actor])
    |> post("/internal-api/rpc/validate", Jason.encode!(body))
  end

  defp maybe_actor(conn, nil), do: conn

  defp maybe_actor(conn, actor) do
    # The controller delegates actor resolution to Ash.PlugHelpers, which
    # reads conn.private[:ash][:actor] (or the deprecated assigns path).
    Plug.Conn.put_private(conn, :ash, %{actor: actor})
  end

  defp create_provider!(org_id) do
    Ash.create!(
      Xaas.Marketplace.Provider,
      %{
        name: "w813-provider-#{System.unique_integer([:positive])}",
        slug: "w813-#{System.unique_integer([:positive])}",
        org_id: org_id
      },
      authorize?: false,
      action: :create
    )
  end

  defp decoded_body(conn), do: Jason.decode!(conn.resp_body)

  ## ------------------------------------------------------------------
  ## (a) rpc/run success envelope on a sandboxed read
  ## ------------------------------------------------------------------

  test "a1. rpc/run list_marketplace_providers returns the real success envelope" do
    provider = create_provider!("org-w813-a")

    conn =
      rpc_post(build_conn(), %{
        "action" => "list_marketplace_providers",
        "fields" => ["id", "name", "slug", "status"]
      },
      actor: %{org_id: provider.org_id}
    )

    assert conn.status == 200
    body = decoded_body(conn)

    assert body["success"] == true
    assert is_list(body["data"])

    returned = Enum.find(body["data"], fn row -> row["id"] == provider.id end)
    assert returned
    assert returned["name"] == provider.name
    assert returned["slug"] == provider.slug
    assert returned["status"] == "pending"
    # camelCase output formatter is the real configured contract: no
    # snake_case key ever reaches the client envelope.
    refute Enum.any?(Map.keys(returned), &String.contains?(&1, "_"))
  end

  test "a2. rpc/run without an actor is org-filter-scoped, not refused" do
    provider = create_provider!("org-w813-a2")

    conn =
      rpc_post(build_conn(), %{
        "action" => "list_marketplace_providers",
        "fields" => ["id", "name"]
      })

    assert conn.status == 200
    body = decoded_body(conn)

    # Real observed behavior: Xaas.Marketplace.Checks.ActorOrgFilter is a
    # FilterCheck, so a nil actor composes into `org_id == ^actor(:org_id)`
    # with a nil org_id — the read is not refused, it is scoped to an empty
    # set. Assert that real scoping, not a denial.
    assert body["success"] == true
    assert is_list(body["data"])
    refute Enum.any?(body["data"], fn row -> row["id"] == provider.id end)
  end

  ## ------------------------------------------------------------------
  ## (b) rpc/validate typed validation payload on bad input
  ## ------------------------------------------------------------------

  test "b1. rpc/validate rejects a bad required field with a typed validation payload" do
    provider = create_provider!("org-w813-b")

    conn =
      validate_post(build_conn(), %{
        "action" => "list_marketplace_providers",
        "fields" => ["id", "name"],
        "input" => %{"noSuchArg" => 1}
      },
      actor: %{org_id: provider.org_id}
    )

    assert conn.status == 200
    body = decoded_body(conn)

    assert body["success"] == false
    assert is_list(body["errors"]) and body["errors"] != []

    assert Enum.any?(body["errors"], fn err ->
             is_binary(err["type"]) and is_binary(err["message"]) and Map.has_key?(err, "path")
           end)
  end

  ## ------------------------------------------------------------------
  ## (c) unknown action typed error
  ## ------------------------------------------------------------------

  test "c1. rpc/run on an unknown action returns the typed action_not_found envelope" do
    conn = rpc_post(build_conn(), %{"action" => "definitely_not_a_real_rpc_action"})

    assert conn.status == 200
    body = decoded_body(conn)

    assert body["success"] == false
    assert [%{"type" => "action_not_found"} = err] = body["errors"]
    assert err["vars"]["actionName"] == "definitely_not_a_real_rpc_action" or
           err["vars"]["action_name"] == "definitely_not_a_real_rpc_action"
    assert is_binary(err["message"]) and err["message"] != ""
    assert is_list(err["path"]) and err["fields"] == []
  end

  test "c2. missing action parameter returns the typed missing_required_parameter envelope" do
    conn = rpc_post(build_conn(), %{})

    assert conn.status == 200
    body = decoded_body(conn)

    assert body["success"] == false
    assert [%{"type" => "missing_required_parameter"} = err] = body["errors"]
    assert err["vars"]["parameter"] == "action"
  end

  ## ------------------------------------------------------------------
  ## (d) W723 auth floor on this route
  ## ------------------------------------------------------------------

  test "d1. missing bearer is 401 with the exact W723 body" do
    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post("/internal-api/rpc/run", Jason.encode!(%{"action" => "list_marketplace_providers"}))

    assert conn.status == 401
    assert Jason.decode!(conn.resp_body) == %{
             "error" => "unauthorized",
             "detail" => "missing or invalid Bearer token"
           }
  end

  test "d2. wrong bearer is 401 with the exact W723 body" do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer wrong-token-#{System.unique_integer()}")
      |> put_req_header("content-type", "application/json")
      |> post("/internal-api/rpc/run", Jason.encode!(%{"action" => "list_marketplace_providers"}))

    assert conn.status == 401
    assert Jason.decode!(conn.resp_body) == %{
             "error" => "unauthorized",
             "detail" => "missing or invalid Bearer token"
           }
  end

  test "d3. absent INTERNAL_API_TOKEN env fails closed 503 on this route" do
    previous = System.get_env("INTERNAL_API_TOKEN")
    System.delete_env("INTERNAL_API_TOKEN")

    try do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer whatever")
        |> put_req_header("content-type", "application/json")
        |> post("/internal-api/rpc/run", "{}")

      assert conn.status == 503
      assert Jason.decode!(conn.resp_body) == %{
               "error" => "internal_api_misconfigured",
               "detail" => "INTERNAL_API_TOKEN is not set on the server"
             }
    after
      if previous do
        System.put_env("INTERNAL_API_TOKEN", previous)
      else
        System.delete_env("INTERNAL_API_TOKEN")
      end
    end
  end

  ## ------------------------------------------------------------------
  ## (e) W636 repoint still holds
  ## ------------------------------------------------------------------

  test "e1. kanban_web router is absent, xaas_web router carries the rpc mount" do
    refute File.exists?(Path.join([File.cwd!(), "lib", "kanban_web", "router.ex"]))

    router = File.read!(Path.join([File.cwd!(), "lib", "xaas_web", "router.ex"]))
    assert String.contains?(router, ~s("/rpc/run", AshTypescriptRpcController, :run))
    assert String.contains?(router, ~s("/rpc/validate", AshTypescriptRpcController, :validate))
  end

  test "e2. the release-audit task source is itself repointed (W636 regression)" do
    task = File.read!(Path.join([File.cwd!(), "lib", "mix", "tasks", "xaas.release_audit.ex"]))

    refute String.contains?(task, "lib/kanban_web/router.ex")
    assert String.contains?(task, "lib/xaas_web/router.ex")
  end

  ## ------------------------------------------------------------------
  ## (f) determinism
  ## ------------------------------------------------------------------

  test "f1. identical rpc/run requests produce identical envelopes" do
    provider = create_provider!("org-w813-f")

    request = %{
      "action" => "list_marketplace_providers",
      "fields" => ["id", "name", "slug", "status"]
    }

    conn1 =
      rpc_post(build_conn(), request,
        actor: %{org_id: provider.org_id}
      )

    conn2 =
      rpc_post(build_conn(), request,
        actor: %{org_id: provider.org_id}
      )

    assert conn1.status == 200
    assert conn2.status == 200

    body1 = decoded_body(conn1)
    body2 = decoded_body(conn2)

    assert body1["success"] == true
    assert body1["success"] == body2["success"]

    row1 = Enum.find(body1["data"], &(&1["id"] == provider.id))
    row2 = Enum.find(body2["data"], &(&1["id"] == provider.id))
    assert row1 == row2
  end
end
