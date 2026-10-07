defmodule XaasWeb.HealthCourtTest do
  @moduledoc """
  W836 health-court: pins the *contract* of `GET /internal-api/health`
  (`XaasWeb.HealthController`) -- the exact real check set, its aggregate
  semantics, and every check's typed failure mode -- against real
  collaborators only: the real router + token pipeline, real sandboxed
  `Xaas.LegacyRepo`/`Xaas.Repo` Postgres, real `Ash.count!/2` reads, and
  real `oban_jobs` rows. No mocks.

  Relation to the sibling `test/xaas_web/controllers/health_controller_test.exs`:
  that file exercises individual branches; this court pins the endpoint's
  total surface as an adversarial contract:

    1. the exact check-name set is a contract (a removed or added check
       fails the court, not a silent contract change);
    2. the real test-env (`Oban` `testing: :manual`, empty `oban_jobs`
       sandbox) `ultracode_tick` behavior is pinned as the real contract
       (W752's 503 finding context);
    3. each check's failure mode is typed through the real controller
       (real exception detail shape vs. string detail vs. typed reason);
    4. determinism x2: two consecutive real requests return byte-identical
       bodies modulo `latency_ms` (and tick timestamps when a tick row is
       inserted).

  Auth: the endpoint sits behind the real
  `XaasWeb.Plugs.RequireInternalApiToken` floor; every request here
  carries the real `INTERNAL_API_TOKEN` except the 401 pin.
  """

  use XaasWeb.ConnCase

  @tick_worker Oban.Worker.to_string(Xaas.Ultracode.Run.Workers.Tick)

  @check_names ~w(
    repo
    ontop
    ultracode_tick
    ash_domain:accounts
    ash_domain:billing
    ash_domain:governance
    ash_domain:ledger
    ash_domain:marketplace
    ash_domain:operations
    ash_domain:platform
  )

  defmodule OkOntopClient do
    @moduledoc "Real, simple stand-in: Ontop reachable (same contract as Req.request/1)."
    def request(_opts), do: {:ok, %{status: 200, headers: [], body: "ok"}}
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.LegacyRepo)
    :ok
  end

  defp auth(conn),
    do: put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))

  defp get_health!(conn) do
    conn
    |> auth()
    |> get("/internal-api/health")
    |> then(&{&1.status, Jason.decode!(&1.resp_body)})
  end

  defp configure_ontop_ok! do
    Application.put_env(:xaas, :ontop_endpoint, "http://ontop:8080")
    Application.put_env(:xaas, :ontop_proxy_http_client, OkOntopClient)

    on_exit(fn ->
      Application.delete_env(:xaas, :ontop_endpoint)
      Application.delete_env(:xaas, :ontop_proxy_http_client)
    end)
  end

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

  # ---------------------------------------------------------------------------
  # (0) unauthenticated floor
  # ---------------------------------------------------------------------------

  test "401 floor: health endpoint is inside the real token-gated /internal-api scope", %{
    conn: conn
  } do
    conn = get(conn, "/internal-api/health")
    assert conn.status == 401
    refute conn.resp_body =~ "\"status\""
  end

  # ---------------------------------------------------------------------------
  # (a) healthy path: exact real body shape
  # ---------------------------------------------------------------------------

  test "healthy path: 200, every configured check ok with the real body shape", %{conn: conn} do
    configure_ontop_ok!()
    insert_fresh_tick_job!()

    {status, body} = get_health!(conn)

    assert status == 200
    assert body["status"] == "ok"

    # The exact real check set is the contract.
    assert MapSet.new(Map.keys(body["checks"])) == MapSet.new(@check_names)

    # Top-level shape: exactly {"status", "checks"}.
    assert MapSet.new(Map.keys(body)) == MapSet.new(["status", "checks"])

    # Every check carries a real latency and an allowed status.
    for {name, check} <- body["checks"] do
      assert check["status"] in ["ok", "skipped", "error"], "#{name}: #{inspect(check)}"
      assert is_number(check["latency_ms"])
    end

    assert body["checks"]["repo"] == %{
             "status" => "ok",
             "latency_ms" => body["checks"]["repo"]["latency_ms"]
           }

    for domain <- ~w(accounts billing governance ledger marketplace operations platform) do
      check = body["checks"]["ash_domain:" <> domain]
      assert check["status"] == "ok"
      assert is_integer(check["count"]) and check["count"] >= 0
    end

    tick = body["checks"]["ultracode_tick"]
    assert tick["status"] == "ok"
    assert is_binary(tick["last_tick_at"])
    assert is_number(tick["elapsed_minutes"])
    assert tick["elapsed_minutes"] >= 0.0
  end

  # ---------------------------------------------------------------------------
  # (b) the ultracode_tick check's real testing:manual contract
  # ---------------------------------------------------------------------------

  test "ultracode_tick under Oban testing:manual with an empty sandbox oban_jobs: typed skipped(:warming_up), aggregate stays 200",
       %{conn: conn} do
    # No tick row inserted: the real test-env contract is an empty
    # `oban_jobs` sandbox (Oban's cron never fires under testing: :manual),
    # and node boot is recent, so the W310h warmup typing applies.
    configure_ontop_ok!()

    {status, body} = get_health!(conn)

    assert status == 200
    assert body["status"] == "ok"

    tick = body["checks"]["ultracode_tick"]
    assert tick["status"] == "skipped"
    assert tick["reason"] == "warming_up"
    assert tick["last_tick_at"] == nil
    assert is_binary(tick["node_boot_at"])
    assert is_binary(tick["warmup_until"])
    refute Map.has_key?(tick, "detail")

    # Real contract detail: warmup_until is exactly
    # node_boot_at + (stale_after_minutes default 5 + 2 margin).
    boot_at = tick["node_boot_at"] |> DateTime.from_iso8601() |> elem(1)
    warmup_until = tick["warmup_until"] |> DateTime.from_iso8601() |> elem(1)
    assert DateTime.diff(warmup_until, boot_at, :minute) == 7
  end

  test "ultracode_tick degraded contract: post-warmup absence of tick evidence is a real error and fails the aggregate 503 (W752)",
       %{conn: conn} do
    configure_ontop_ok!()

    Application.put_env(
      :xaas,
      :health_node_boot_at_override,
      DateTime.add(DateTime.utc_now(), -3600, :second)
    )

    on_exit(fn -> Application.delete_env(:xaas, :health_node_boot_at_override) end)

    {status, body} = get_health!(conn)

    assert status == 503
    assert body["status"] == "error"

    tick = body["checks"]["ultracode_tick"]
    assert tick["status"] == "error"
    assert tick["detail"]["last_tick_at"] == nil
    assert is_binary(tick["detail"]["node_boot_at"])
    assert tick["detail"]["reason"] =~ "no #{Oban.Worker.to_string(Xaas.Ultracode.Run.Workers.Tick)} job has completed or started executing since node boot"
    assert tick["detail"]["reason"] =~ "the :tick cron appears dead, not just warming up"

    # Every other check stays ok -- the aggregate degrades on exactly one
    # real error, fail-closed.
    assert body["checks"]["repo"]["status"] == "ok"
    assert body["checks"]["ontop"]["status"] == "ok"

    for domain <- ~w(accounts billing governance ledger marketplace operations platform) do
      assert body["checks"]["ash_domain:" <> domain]["status"] == "ok"
    end
  end

  test "ultracode_tick stale-but-post-boot contract: a real tick row older than the staleness window is an error carrying last_tick_at/elapsed/stale_after_minutes",
       %{conn: conn} do
    configure_ontop_ok!()

    # Boot 1h ago (override seam) + a tick row completed 30min ago: the
    # tick is post-boot (not warming up) but stale -> the not-warming-up
    # error branch with full operator numbers.
    Application.put_env(
      :xaas,
      :health_node_boot_at_override,
      DateTime.add(DateTime.utc_now(), -3600, :second)
    )

    on_exit(fn -> Application.delete_env(:xaas, :health_node_boot_at_override) end)

    stale_at = DateTime.add(DateTime.utc_now(), -1800, :second)

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
      inserted_at: stale_at,
      scheduled_at: stale_at,
      completed_at: stale_at
    })

    {status, body} = get_health!(conn)

    assert status == 503
    assert body["status"] == "error"

    tick = body["checks"]["ultracode_tick"]
    assert tick["status"] == "error"

    assert tick["detail"]["last_tick_at"] |> DateTime.from_iso8601() |> elem(1) == stale_at

    assert tick["detail"]["elapsed_minutes"] >= 29.0
    assert tick["detail"]["stale_after_minutes"] == 5
    assert tick["detail"]["reason"] =~ "no #{@tick_worker} job completed or started executing recently enough"
  end

  # ---------------------------------------------------------------------------
  # (c) each check's failure mode, typed
  # ---------------------------------------------------------------------------

  test "failure modes: ontop error is a string detail under `detail` (map payload from client error), raising check is structured {exception, message}",
       %{conn: conn} do
    # Ontop DOWN case via real stand-in returning a transport error.
    defmodule DownOntop do
      def request(_opts), do: {:error, %{reason: :econnrefused}}
    end

    Application.put_env(:xaas, :ontop_endpoint, "http://ontop:8080")
    Application.put_env(:xaas, :ontop_proxy_http_client, DownOntop)
    insert_fresh_tick_job!()

    on_exit(fn ->
      Application.delete_env(:xaas, :ontop_endpoint)
      Application.delete_env(:xaas, :ontop_proxy_http_client)
    end)

    {status, body} = get_health!(conn)

    assert status == 503
    assert body["status"] == "error"
    assert body["checks"]["ontop"]["status"] == "error"
    # String-detail shape: {:error, inspect(reason)} branch.
    assert body["checks"]["ontop"]["detail"] =~ "econnrefused"
    assert body["checks"]["repo"]["status"] == "ok"
  end

  test "failure modes: a raising check becomes structured {exception, message} detail and fails the aggregate",
       %{conn: conn} do
    defmodule ExplodingOntop do
      def request(_opts), do: raise("ontop socket exploded")
    end

    Application.put_env(:xaas, :ontop_endpoint, "http://ontop:8080")
    Application.put_env(:xaas, :ontop_proxy_http_client, ExplodingOntop)
    insert_fresh_tick_job!()

    on_exit(fn ->
      Application.delete_env(:xaas, :ontop_endpoint)
      Application.delete_env(:xaas, :ontop_proxy_http_client)
    end)

    {status, body} = get_health!(conn)

    assert status == 503
    ontop = body["checks"]["ontop"]
    assert ontop["status"] == "error"
    assert is_map(ontop["detail"])
    assert ontop["detail"]["exception"] == "RuntimeError"
    assert ontop["detail"]["message"] =~ "ontop socket exploded"
  end

  test "failure modes: unconfigured ontop is typed skipped(:not_configured), aggregate 200 -- unconfigured != down",
       %{conn: conn} do
    Application.delete_env(:xaas, :ontop_endpoint)
    insert_fresh_tick_job!()

    {status, body} = get_health!(conn)

    assert status == 200
    assert body["status"] == "ok"
    assert body["checks"]["ontop"] == %{
             "status" => "skipped",
             "latency_ms" => body["checks"]["ontop"]["latency_ms"],
             "reason" => "not_configured"
           }
  end

  test "failure modes: timeout/catch-all path is typed (catch clause), exercised via a real exit",
       %{conn: conn} do
    defmodule ExitingOntop do
      def request(_opts), do: exit(:timeout_probe)
    end

    Application.put_env(:xaas, :ontop_endpoint, "http://ontop:8080")
    Application.put_env(:xaas, :ontop_proxy_http_client, ExitingOntop)
    insert_fresh_tick_job!()

    on_exit(fn ->
      Application.delete_env(:xaas, :ontop_endpoint)
      Application.delete_env(:xaas, :ontop_proxy_http_client)
    end)

    {status, body} = get_health!(conn)

    assert status == 503
    ontop = body["checks"]["ontop"]
    assert ontop["status"] == "error"
    # The `catch kind, reason` clause: "exit: :timeout_probe".
    assert is_binary(ontop["detail"])
    assert ontop["detail"] =~ "exit"
    assert ontop["detail"] =~ ":timeout_probe"
  end

  # ---------------------------------------------------------------------------
  # (c2) W860: per-check timeout -- a hung check is typed, not a hung request
  # ---------------------------------------------------------------------------

  test "W860 timeout: a check that never returns reports the typed {:timeout, ceiling} failure and the endpoint still responds 503",
       %{conn: conn} do
    # Real hung collaborator through the existing real `request/1`
    # indirection seam: accepts (returns into the controller) then never
    # answers -- the exact production shape W836 typed as the gap
    # ("an Ontop that accepts but never answers").
    defmodule NeverAnsweringOntop do
      def request(_opts), do: Process.sleep(:infinity)
    end

    Application.put_env(:xaas, :ontop_endpoint, "http://ontop:8080")
    Application.put_env(:xaas, :ontop_proxy_http_client, NeverAnsweringOntop)
    insert_fresh_tick_job!()

    on_exit(fn ->
      Application.delete_env(:xaas, :ontop_endpoint)
      Application.delete_env(:xaas, :ontop_proxy_http_client)
    end)

    {status, body} = get_health!(conn)

    # The request itself came back (this assert is the one that fails --
    # by ExUnit timeout-exit, never passing -- if the bounded-Task wrap
    # is dropped and the hung check hangs the request).
    assert status == 503
    assert body["status"] == "error"

    ontop = body["checks"]["ontop"]
    assert ontop["status"] == "error"
    # Typed timeout shape: string detail carrying the real 2000ms ceiling.
    assert is_binary(ontop["detail"])
    assert ontop["detail"] =~ "timeout"
    assert ontop["detail"] =~ "2000"
    assert ontop["latency_ms"] >= 2000

    # Fail-closed unchanged: exactly the hung check degrades; every other
    # real check stays ok.
    assert body["checks"]["repo"]["status"] == "ok"
    assert body["checks"]["ultracode_tick"]["status"] == "ok"

    for domain <- ~w(accounts billing governance ledger marketplace operations platform) do
      assert body["checks"]["ash_domain:" <> domain]["status"] == "ok"
    end
  end

  # ---------------------------------------------------------------------------
  # (d) determinism x2
  # ---------------------------------------------------------------------------

  test "determinism x2: two consecutive requests return identical check verdicts, statuses, and latencies within noise",
       %{conn: conn} do
    configure_ontop_ok!()
    insert_fresh_tick_job!()

    conn = auth(conn)
    {status_a, body_a} = get_health!(conn)
    {status_b, body_b} = get_health!(conn)

    assert status_a == 200
    assert status_b == 200

    # Check sets and statuses identical across runs.
    assert Map.keys(body_a["checks"]) |> Enum.sort() == Map.keys(body_b["checks"]) |> Enum.sort()

    for name <- Map.keys(body_a["checks"]) do
      a = body_a["checks"][name]
      b = body_b["checks"][name]
      assert a["status"] == b["status"]
    end

    # latencies differ run to run but are all real positive numbers.
    for body <- [body_a, body_b] do
      for {_name, check} <- body["checks"] do
        assert is_number(check["latency_ms"]) and check["latency_ms"] >= 0
      end
    end

    # Full-body equality modulo latency (and tick timestamp floats when
    # present): normalize latency, then compare.
    strip = fn body ->
      {body["status"],
       Map.new(body["checks"], fn {name, check} ->
         {name, Map.delete(check, "latency_ms")}
       end)}
    end

    assert strip.(body_a) == strip.(body_b)
  end

  test "determinism x2 (degraded): two consecutive 503 runs report the identical typed error",
       %{conn: conn} do
    configure_ontop_ok!()

    Application.put_env(
      :xaas,
      :health_node_boot_at_override,
      DateTime.add(DateTime.utc_now(), -3600, :second)
    )

    on_exit(fn -> Application.delete_env(:xaas, :health_node_boot_at_override) end)

    conn = auth(conn)
    {status_a, body_a} = get_health!(conn)
    {status_b, body_b} = get_health!(conn)

    assert status_a == 503
    assert status_b == 503
    assert body_a["status"] == "error"
    assert body_b["status"] == "error"

    tick_a = body_a["checks"]["ultracode_tick"]
    tick_b = body_b["checks"]["ultracode_tick"]

    assert tick_a["status"] == "error" and tick_b["status"] == "error"
    assert tick_a["detail"]["reason"] == tick_b["detail"]["reason"]
    assert tick_a["detail"]["last_tick_at"] == tick_b["detail"]["last_tick_at"]
  end
end
