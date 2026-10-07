defmodule XaasWeb.HealthControllerTest do
  @moduledoc """
  Real Chicago-style test for `GET /internal-api/health`, run through the
  real router + real `XaasWeb.Plugs.RequireInternalApiToken` pipeline,
  real sandboxed `Xaas.LegacyRepo`/`Xaas.Repo` Postgres, and real
  `Ash.count!/2` reads against real Ash resources -- no mocking of the
  controller or the Ash resources.

  The one genuinely infeasible-in-sandbox collaborator is the real Ontop
  Java container (same disclosed exception
  `test/xaas_web/plugs/ontop_proxy_plug_test.exs` already states): a
  real, simple stand-in module implementing the same `request/1`
  contract `Req` exposes is swapped in via
  `Application.put_env(:xaas, :ontop_proxy_http_client, ...)` -- not a
  mock, no interaction/call-count assertions are made against it.

  The `ultracode_tick` check (`Xaas.Ultracode.TickHealth`, see its
  moduledoc) is exercised against a real inserted `%Oban.Job{}` row in
  the real sandboxed `oban_jobs` table, same as
  `test/xaas/ultracode/tick_health_test.exs` -- no stand-in for Oban
  itself.
  """

  use XaasWeb.ConnCase

  @tick_worker Oban.Worker.to_string(Xaas.Ultracode.Run.Workers.Tick)

  defmodule FakeOntopClient do
    @moduledoc "Real, simple stand-in returning a fixed successful response."
    def request(_opts), do: {:ok, %{status: 200, headers: [], body: "ok"}}
  end

  defmodule FakeOntopDownClient do
    @moduledoc "Real, simple stand-in simulating an unreachable Ontop."
    def request(_opts), do: {:error, %{reason: :econnrefused}}
  end

  defmodule FakeOntopRaisingClient do
    @moduledoc """
    Real, simple stand-in that raises -- same disclosed stand-in pattern as
    `FakeOntopClient`/`FakeOntopDownClient`, exercising the controller's real
    rescue path so the resulting error detail is machine-readable structure,
    not a flat stringified `Exception.message/1`.
    """

    def request(_opts), do: raise("ontop client exploded")
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.LegacyRepo)
    :ok
  end

  defp auth(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  # Configure the Ontop sub-check for tests that exercise its real
  # probe path (`config :xaas, :ontop_endpoint` gates the check).
  defp configure_ontop! do
    Application.put_env(:xaas, :ontop_endpoint, "http://ontop:8080")
    on_exit(fn -> Application.delete_env(:xaas, :ontop_endpoint) end)
    :ok
  end

  # Real fresh completed tick job so the happy-path test below reflects a
  # genuinely live cron, not the absence-of-evidence :stale case
  # `Xaas.Ultracode.TickHealth` is specifically designed to catch.
  defp insert_fresh_tick_job! do
    now = DateTime.utc_now()

    Xaas.Repo.insert!(%Oban.Job{
      state: "completed",
      queue: "default",
      worker: @tick_worker,
      args: %{},
      meta: %{},
      tags: [],
      errors: [],
      attempt: 1,
      max_attempts: 20,
      priority: 0,
      inserted_at: now,
      scheduled_at: now,
      completed_at: now
    })
  end

  test "requires the real bearer token, same as every other /internal-api route", %{conn: conn} do
    conn = get(conn, "/internal-api/health")

    assert conn.status == 401
  end

  test "GET /internal-api/health returns 200 with every real check ok when Ontop is reachable and the tick is fresh",
       %{
         conn: conn
       } do
    configure_ontop!()
    Application.put_env(:xaas, :ontop_proxy_http_client, FakeOntopClient)
    on_exit(fn -> Application.delete_env(:xaas, :ontop_proxy_http_client) end)
    insert_fresh_tick_job!()

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
    assert checks["ultracode_tick"]["status"] == "ok"
    assert checks["ultracode_tick"]["last_tick_at"] != nil
    assert is_number(checks["ultracode_tick"]["elapsed_minutes"])

    for domain <- ~w(accounts billing governance ledger marketplace operations platform) do
      key = "ash_domain:" <> domain

      assert checks[key]["status"] == "ok",
             "expected #{key} to be ok, got #{inspect(checks[key])}"

      assert is_integer(checks[key]["count"])
      assert checks[key]["count"] >= 0
    end
  end

  test "GET /internal-api/health real-reports ultracode_tick as skipped (:warming_up), aggregate 200, when the tick cron has not yet fired since boot",
       %{conn: conn} do
    configure_ontop!()
    Application.put_env(:xaas, :ontop_proxy_http_client, FakeOntopClient)
    on_exit(fn -> Application.delete_env(:xaas, :ontop_proxy_http_client) end)

    # Deliberately no insert_fresh_tick_job!() -- the real, empty
    # `oban_jobs` table (in this sandboxed transaction) is exactly the
    # freshly-booted-server case (W310g x3 deterministic 503): the cron
    # has had no fire opportunity yet, so per W174's law (unconfigured /
    # no-opportunity != down) this is a typed `skipped (:warming_up)`,
    # not an aggregate failure.
    conn =
      conn
      |> auth()
      |> get("/internal-api/health")

    assert conn.status == 200

    body = Jason.decode!(conn.resp_body)
    assert body["status"] == "ok"

    tick = body["checks"]["ultracode_tick"]
    assert tick["status"] == "skipped"
    assert tick["reason"] == "warming_up"
    assert tick["last_tick_at"] == nil
    assert is_binary(tick["node_boot_at"])
    assert is_binary(tick["warmup_until"])
    assert body["checks"]["repo"]["status"] == "ok"
  end

  test "GET /internal-api/health real-reports 503 once the warmup window has passed with no post-boot tick evidence (dead cron, not warming up)",
       %{conn: conn} do
    configure_ontop!()
    Application.put_env(:xaas, :ontop_proxy_http_client, FakeOntopClient)
    on_exit(fn -> Application.delete_env(:xaas, :ontop_proxy_http_client) end)

    # Deterministically move node boot past the grace window via the
    # controller's test-only boot-time seam -- no sleeping out the real
    # `stale_after_minutes + 2` minutes.
    Application.put_env(
      :xaas,
      :health_node_boot_at_override,
      DateTime.add(DateTime.utc_now(), -3600, :second)
    )

    on_exit(fn -> Application.delete_env(:xaas, :health_node_boot_at_override) end)

    conn =
      conn
      |> auth()
      |> get("/internal-api/health")

    assert conn.status == 503

    body = Jason.decode!(conn.resp_body)
    assert body["status"] == "error"

    tick = body["checks"]["ultracode_tick"]
    assert tick["status"] == "error"
    assert tick["detail"]["reason"] =~ "since node boot"
    assert body["checks"]["repo"]["status"] == "ok"
  end

  test "GET /internal-api/health real-reports 503 and the real failing check when Ontop is configured but unreachable",
       %{conn: conn} do
    configure_ontop!()
    Application.put_env(:xaas, :ontop_proxy_http_client, FakeOntopDownClient)
    on_exit(fn -> Application.delete_env(:xaas, :ontop_proxy_http_client) end)

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

  test "GET /internal-api/health returns 200 with ontop skipped (not failing) when Ontop is not configured",
       %{conn: conn} do
    # Deliberately no configure_ontop!() -- native dev leaves
    # `config :xaas, :ontop_endpoint` absent, and the fail-closed
    # aggregate treats a config-gated skipped check as not down.
    Application.delete_env(:xaas, :ontop_endpoint)
    insert_fresh_tick_job!()

    conn =
      conn
      |> auth()
      |> get("/internal-api/health")

    assert conn.status == 200

    body = Jason.decode!(conn.resp_body)
    assert body["status"] == "ok"

    ontop = body["checks"]["ontop"]
    assert ontop["status"] == "skipped"
    assert ontop["reason"] == "not_configured"
  end

  test "GET /internal-api/health renders a raised check as structured error detail, not a flat string",
       %{conn: conn} do
    configure_ontop!()
    Application.put_env(:xaas, :ontop_proxy_http_client, FakeOntopRaisingClient)
    on_exit(fn -> Application.delete_env(:xaas, :ontop_proxy_http_client) end)

    conn =
      conn
      |> auth()
      |> get("/internal-api/health")

    assert conn.status == 503

    body = Jason.decode!(conn.resp_body)
    assert body["status"] == "error"

    ontop = body["checks"]["ontop"]
    assert ontop["status"] == "error"
    assert is_map(ontop["detail"])
    assert ontop["detail"]["exception"] == "RuntimeError"
    assert is_binary(ontop["detail"]["message"])
    assert ontop["detail"]["message"] =~ "ontop client exploded"
    assert body["checks"]["repo"]["status"] == "ok"
  end

  test "an Ash resource-count check succeeds even though the underlying resources deny-by-default authorize",
       %{conn: conn} do
    configure_ontop!()
    Application.put_env(:xaas, :ontop_proxy_http_client, FakeOntopClient)
    on_exit(fn -> Application.delete_env(:xaas, :ontop_proxy_http_client) end)

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
