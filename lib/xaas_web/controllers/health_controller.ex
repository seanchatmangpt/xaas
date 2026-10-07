defmodule XaasWeb.HealthController do
  @moduledoc """
  Real health-check aggregation for `/internal-api/health` -- net new,
  chosen from the fourth-pass ERRC refresh
  (`docs/claude/diataxis/explanation/errc-innovation-grid.md`): this repo
  had zero health/readiness aggregation endpoint anywhere before this.

  Runs four real checks, not stubs:

    1. `Xaas.LegacyRepo` connectivity -- a real `Ecto.Adapters.SQL.query!/3`
       (`SELECT 1`) against the real sandboxed/dev Postgres.
    2. The real Ontop SPARQL endpoint's reachability, using the exact
       same real HTTP client indirection `XaasWeb.OntopProxyPlug`
       already established (`Application.get_env(:xaas,
       :ontop_proxy_http_client, Req)` / `:ontop_base_url`) so tests can
       swap in the same kind of real, simple stand-in that plug's own
       test suite uses (see `test/xaas_web/plugs/ontop_proxy_plug_test.exs`)
       instead of assuming a live Ontop container.
    3. One real Ash resource-count query per real `Ash.Domain` this repo
       actually defines. Real, disclosed correction to the originating
       ERRC spec: it named 9 domains including `Hammer`/`Secrets`, but
       `Xaas.Hammer` (`use Hammer, backend: :ets`) and `Xaas.Secrets`
       (`use AshAuthentication.Secret`) are not `Ash.Domain` modules --
       neither has resources or a repo to count against. The real count
       of `use Ash.Domain` modules in `lib/xaas/` is 7:
       `Accounts`, `Billing`, `Governance`, `Ledger`, `Marketplace`,
       `Operations`, `Platform`. One representative resource per domain
       is counted via `Ash.count!/2` with `authorize?: false` (this is a
       system-level liveness probe, not a user-scoped read -- same
       system-context rationale `XaasWeb.Plugs.RequireInternalApiToken`
       already establishes for this whole `/internal-api` scope) so a
       real deny-by-default policy on any of the 7 resources can never
       make the health check itself report a false negative.
    4. `Xaas.Ultracode.TickHealth.check/1` -- real liveness for
       `Xaas.Ultracode.Run`'s AshOban `:tick` cron (see that module's
       moduledoc), reusing Oban's own real `oban_jobs` table rather than
       a bespoke event pipeline. `:stale` reports as this check's
       `"error"` status (a stale tick is real production evidence
       something is wrong, matching every other check's semantics here)
       carrying `last_tick_at`/`elapsed_minutes`/`stale_after_minutes` so
       an operator does not have to separately run
       `mix xaas.ultracode.tick_health` to see the same numbers.

  Returns real JSON with a per-check `status` (`"ok"` / `"skipped"` /
  `"error"`) and `latency_ms`, top-level `status` `"ok"` when every check
  is `"ok"` or config-gated-`"skipped"`, HTTP 200 when healthy and 503
  otherwise -- the same fail-closed convention this `/internal-api`
  scope already uses. The Ontop sub-check is config-gated on
  `config :xaas, :ontop_endpoint`: absent natively -> `"skipped"
  (:not_configured)`, present (docker-compose.ontop.yaml stack) ->
  real reachability probe where configured-but-down still fails.

  Warmup typing (W310h): the `ultracode_tick` sub-check distinguishes a
  genuinely dead `:tick` cron from the post-boot warmup window where the
  cron has simply not had its first fire opportunity yet -- a last-tick
  predating node boot reports `skipped (:warming_up)` for
  `stale_after_minutes + 2` minutes after boot, then a real error. See
  the comment above `check_ultracode_tick/0`.
  """

  use XaasWeb, :controller

  alias Xaas.{Accounts, Billing, Governance, Ledger, Marketplace, Operations, Platform}
  alias Xaas.Ultracode.TickHealth

  @domain_checks [
    {"accounts", Accounts.Org},
    {"billing", Billing.Subscription},
    {"governance", Governance.FreezeWindow},
    {"ledger", Ledger.Account},
    {"marketplace", Marketplace.Provider},
    {"operations", Operations.Incident},
    {"platform", Platform.Webhook}
  ]

  def index(conn, _params) do
    checks =
      %{}
      |> Map.put("repo", timed(&check_repo/0))
      |> Map.put("ontop", timed(&check_ontop/0))
      |> Map.put("ultracode_tick", timed(&check_ultracode_tick/0))
      |> Map.merge(domain_checks())

    # Fail-closed aggregate: "skipped" (config-gated check, not configured)
    # is not "down" -- only a real "error" degrades the endpoint.
    all_ok? =
      Enum.all?(checks, fn {_name, %{status: status}} -> status in ["ok", "skipped"] end)

    conn
    |> put_status(if all_ok?, do: 200, else: 503)
    |> json(%{
      status: if(all_ok?, do: "ok", else: "error"),
      checks: checks
    })
  end

  defp domain_checks do
    Map.new(@domain_checks, fn {name, resource} ->
      {"ash_domain:" <> name, timed(fn -> check_ash_count(resource) end)}
    end)
  end

  # Per-check wall-clock ceiling (W860). Every check runs in a bounded
  # `Task` reaped by `Task.await/2` after this many ms; on timeout the
  # check reports the typed `{:timeout, ceiling}` failure (an `"error"`
  # check with a `"timeout: ..."` string `detail`, same fail-closed
  # aggregate semantics as any other error) instead of hanging the whole
  # health request on a stuck collaborator (e.g. an Ontop that accepts
  # the TCP connection but never answers). 2000ms is comfortably above
  # every check's healthy latency (a `SELECT 1`, a local HTTP probe,
  # indexed `Ash.count!`s, one `oban_jobs` query -- all single-digit-ms
  # in practice) while bounding a hung request to ~2s.
  @check_timeout_ms 2000

  defp timed(fun) do
    start = System.monotonic_time(:microsecond)

    result =
      try do
        # Bounded execution (W860): the check body runs in a Task owned
        # by this request process; a check that never returns is given
        # up on after `@check_timeout_ms` (typed `{:timeout, ceiling}`
        # below). The task body itself classifies raise/exit/throw, so a
        # crashing check arrives as a *value* -- the original typed
        # shapes (structured {exception, message} / "exit: ..." strings)
        # are preserved exactly, and the task never exits abnormally.
        # `Process.unlink/1` before `await` is belt-and-braces so any
        # residual task death cannot kill the request ahead of the
        # handlers. The abandoned hung task dies with the request
        # process (a Task monitors its owner), so nothing leaks past the
        # ceiling.
        task =
          Task.async(fn ->
            try do
              fun.()
            rescue
              error -> {:raised, error}
            catch
              kind, reason -> {:caught, kind, reason}
            end
          end)

        Process.unlink(task.pid)
        Task.await(task, @check_timeout_ms)
      rescue
        error ->
          {:error, %{exception: inspect(error.__struct__), message: Exception.message(error)}}
      catch
        # `Task.await/2` exits `{:timeout, {Task, timeout}}` on expiry.
        :exit, {:timeout, {Task, timeout_ms}} ->
          {:timeout, timeout_ms}

        kind, reason -> {:error, "#{kind}: #{inspect(reason)}"}
      end

    latency_ms = (System.monotonic_time(:microsecond) - start) / 1000

    case result do
      :ok ->
        %{status: "ok", latency_ms: latency_ms}

      {:ok, extra} ->
        Map.merge(%{status: "ok", latency_ms: latency_ms}, extra)

      # Map payloads merge to top level (same shape as the `{:ok, extra}`
      # branch); bare atoms stay wrapped as `reason:` (ontop's
      # `{:skipped, :not_configured}` shape).
      {:skipped, extra} when is_map(extra) ->
        Map.merge(%{status: "skipped", latency_ms: latency_ms}, extra)

      {:skipped, reason} ->
        %{status: "skipped", latency_ms: latency_ms, reason: reason}

      {:error, reason} ->
        %{status: "error", latency_ms: latency_ms, detail: reason}

      # W860 typed timeout shape: same `"error"` + string `detail`
      # convention as the transport-error branch, with the real ceiling
      # in the detail.
      {:timeout, timeout_ms} ->
        %{
          status: "error",
          latency_ms: latency_ms,
          detail: "timeout: check exceeded #{timeout_ms}ms"
        }

      # Task-classified raise/exit/throw, normalized back to the exact
      # pre-W860 shapes (this clause pair replaces what the outer
      # rescue/catch used to type directly).
      {:raised, error} ->
        %{
          status: "error",
          latency_ms: latency_ms,
          detail: %{exception: inspect(error.__struct__), message: Exception.message(error)}
        }

      {:caught, kind, reason} ->
        %{status: "error", latency_ms: latency_ms, detail: "#{kind}: #{inspect(reason)}"}
    end
  end

  defp check_repo do
    Ecto.Adapters.SQL.query!(Xaas.LegacyRepo, "SELECT 1", [])
    :ok
  end

  # Config-gated: the Ontop sub-check only runs when `config :xaas,
  # :ontop_endpoint` is actually present (the docker-compose.ontop.yaml
  # stack sets it). Native dev without Ontop leaves it absent -> the
  # sub-check reports "skipped" (:not_configured), which is not a
  # failure; configured-but-unreachable still fails the aggregate.
  defp check_ontop do
    if ontop_configured?() do
      case req_module().request(method: "GET", url: ontop_base_url() <> "/sparql", retry: false) do
        {:ok, %{status: status}} when status in 200..499 -> :ok
        {:ok, %{status: status}} -> {:error, "unexpected status #{status}"}
        {:error, reason} -> {:error, inspect(reason)}
      end
    else
      {:skipped, :not_configured}
    end
  end

  defp ontop_configured?, do: Application.get_env(:xaas, :ontop_endpoint) != nil

  defp check_ash_count(resource) do
    count = Ash.count!(resource, authorize?: false)
    {:ok, %{count: count}}
  end

  # Warmup-window typing (W310h, per W174's own law "unconfigured != down"):
  # a freshly-booted server has had no cron fire opportunity yet, so the
  # newest `oban_jobs` evidence necessarily predates this node's start --
  # counting pre-boot history against the 5-minute staleness window made
  # every freshly-booted server report a deterministic 503 for up to the
  # first cron minute (observed x3 on W310g's fresh boot, 2026-10-06
  # 22:55Z: last_tick_at 22:36Z, elapsed 19.5min, while the tick cron was
  # in fact healthy and completed job 28635 one poll later). A last-tick
  # predating node boot is `skipped (:warming_up)` -- typed reason fields,
  # aggregate-stays-ok -- until `stale_after_minutes + 2` minutes after
  # boot; past that grace window, absence of post-boot tick evidence is a
  # real error again (`Xaas.Ultracode.TickHealth`'s "silence is not
  # liveness" law is preserved outside the boot window).
  @tick_warmup_margin_minutes 2

  defp check_ultracode_tick do
    result = TickHealth.check()
    boot_at = node_boot_at()

    warming_up? =
      is_nil(result.last_tick_at) or
        DateTime.compare(result.last_tick_at, boot_at) == :lt

    within_warmup_window? =
      DateTime.compare(
        DateTime.utc_now(),
        DateTime.add(boot_at, @tick_warmup_margin_minutes + result.stale_after_minutes, :minute)
      ) == :lt

    cond do
      not warming_up? and result.status == :healthy ->
        {:ok,
         %{
           last_tick_at: format_datetime(result.last_tick_at),
           elapsed_minutes: result.elapsed_minutes
         }}

      not warming_up? ->
        {:error,
         %{
           last_tick_at: format_datetime(result.last_tick_at),
           elapsed_minutes: result.elapsed_minutes,
           stale_after_minutes: result.stale_after_minutes,
           reason: "no #{result.worker} job completed or started executing recently enough"
         }}

      within_warmup_window? ->
        {:skipped,
         %{
           reason: :warming_up,
           last_tick_at: format_datetime(result.last_tick_at),
           node_boot_at: format_datetime(boot_at),
           warmup_until:
             format_datetime(
               DateTime.add(
                 boot_at,
                 @tick_warmup_margin_minutes + result.stale_after_minutes,
                 :minute
               )
             )
         }}

      true ->
        {:error,
         %{
           last_tick_at: format_datetime(result.last_tick_at),
           node_boot_at: format_datetime(boot_at),
           reason:
             "no #{result.worker} job has completed or started executing since node boot " <>
               "(#{format_datetime(boot_at)}); the :tick cron appears dead, not just warming up"
         }}
    end
  end

  # This node's real start wall-clock: `:erlang.statistics(:wall_clock)`
  # element 1 is cumulative uptime in ms, so `now - uptime` is the boot
  # instant. No new application-child or config key required.
  # `config :xaas, :health_node_boot_at_override` is a test-only seam so
  # the past-the-grace-window branch is deterministically exercisable
  # without sleeping out the real warmup window.
  defp node_boot_at do
    case Application.get_env(:xaas, :health_node_boot_at_override) do
      %DateTime{} = at ->
        at

      _ ->
        {uptime_ms, _since_last} = :erlang.statistics(:wall_clock)
        DateTime.add(DateTime.utc_now(), -uptime_ms, :millisecond)
    end
  end

  defp format_datetime(nil), do: nil
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp req_module, do: Application.get_env(:xaas, :ontop_proxy_http_client, Req)

  defp ontop_base_url,
    do: Application.get_env(:xaas, :ontop_base_url, "http://ontop:8080")
end
