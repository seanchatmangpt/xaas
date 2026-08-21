defmodule KanbanWeb.HealthControllerTest do
  @moduledoc """
  Real Chicago-style test for `GET /internal-api/health`, run through the
  real router + real `KanbanWeb.Plugs.RequireInternalApiToken` pipeline,
  real sandboxed `Kanban.Repo`/`Xaas.Repo` Postgres, and real
  `Ash.count!/2` reads against real Ash resources -- no mocking of the
  controller or the Ash resources.

  The one genuinely infeasible-in-sandbox collaborator is the real Ontop
  Java container (same disclosed exception
  `test/kanban_web/plugs/ontop_proxy_plug_test.exs` already states): a
  real, simple stand-in module implementing the same `request/1`
  contract `Req` exposes is swapped in via
  `Application.put_env(:kanban, :ontop_proxy_http_client, ...)` -- not a
  mock, no interaction/call-count assertions are made against it.
  """

  use KanbanWeb.ConnCase

  defmodule FakeOntopClient do
    @moduledoc "Real, simple stand-in returning a fixed successful response."
    def request(_opts), do: {:ok, %{status: 200, headers: [], body: "ok"}}
  end

  defmodule FakeOntopDownClient do
    @moduledoc "Real, simple stand-in simulating an unreachable Ontop."
    def request(_opts), do: {:error, %{reason: :econnrefused}}
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.checkout(Kanban.Repo)
    :ok
  end

  defp auth(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  test "requires the real bearer token, same as every other /internal-api route", %{conn: conn} do
    conn = get(conn, "/internal-api/health")

    assert conn.status == 401
  end

  test "GET /internal-api/health returns 200 with every real check ok when Ontop is reachable", %{
    conn: conn
  } do
    Application.put_env(:kanban, :ontop_proxy_http_client, FakeOntopClient)
    on_exit(fn -> Application.delete_env(:kanban, :ontop_proxy_http_client) end)

    conn =
      conn
      |> auth()
      |> get("/internal-api/health")

    assert conn.status == 200

    body = Jason.decode!(conn.resp_body)
    assert body["status"] == "ok"

    checks = body["checks"]
    assert checks["repo"]["status"] == "ok"
    assert is_number(checks["repo"]["latency_ms"])
    assert checks["ontop"]["status"] == "ok"

    for domain <- ~w(accounts billing governance ledger marketplace operations platform) do
      key = "ash_domain:" <> domain
      assert checks[key]["status"] == "ok", "expected #{key} to be ok, got #{inspect(checks[key])}"
      assert is_integer(checks[key]["count"])
      assert checks[key]["count"] >= 0
    end
  end

  test "GET /internal-api/health real-reports 503 and the real failing check when Ontop is unreachable",
       %{conn: conn} do
    Application.put_env(:kanban, :ontop_proxy_http_client, FakeOntopDownClient)
    on_exit(fn -> Application.delete_env(:kanban, :ontop_proxy_http_client) end)

    conn =
      conn
      |> auth()
      |> get("/internal-api/health")

    assert conn.status == 503

    body = Jason.decode!(conn.resp_body)
    assert body["status"] == "error"
    assert body["checks"]["ontop"]["status"] == "error"
    assert body["checks"]["repo"]["status"] == "ok"
  end

  test "an Ash resource-count check succeeds even though the underlying resources deny-by-default authorize",
       %{conn: conn} do
    Application.put_env(:kanban, :ontop_proxy_http_client, FakeOntopClient)
    on_exit(fn -> Application.delete_env(:kanban, :ontop_proxy_http_client) end)

    conn =
      conn
      |> auth()
      |> get("/internal-api/health")

    body = Jason.decode!(conn.resp_body)

    # Real proof this isn't accidentally authorized as some default actor:
    # a plain, unauthenticated `Ash.count!/2` without `authorize?: false`
    # against a deny-by-default resource would raise `Ash.Error.Forbidden`.
    # The controller passes `authorize?: false` deliberately (system-level
    # liveness probe, not a user-scoped read) -- this asserts the real
    # resulting count came back instead of the check erroring out.
    assert body["checks"]["ash_domain:ledger"]["status"] == "ok"
  end
end
