defmodule Xaas.Ultracode.TickHealth do
  @moduledoc """
  Real liveness check for `Xaas.Ultracode.Run`'s AshOban `:tick` cron
  (`oban do scheduled_actions do schedule :tick, "* * * * *" ... end end`,
  see that resource's moduledoc). Before this module, nothing observed
  whether the generated `Xaas.Ultracode.Run.Workers.Tick` Oban worker was
  actually still firing once per minute -- a crashed worker, a
  misconfigured/removed `Oban.Plugins.Cron` plugin entry, or the
  supervised `Oban` process itself going down (both real prior findings
  this session, see `Xaas.Application`'s moduledoc comments) would leave
  every `Xaas.Ultracode.Run` silently stalled with no signal anywhere.

  Reuses Oban's own real job table (`Oban.Job`, table `oban_jobs`, the
  exact schema `Oban.start_link/1` already requires and this repo already
  migrates via `Oban.Migrations.up/0` -- see
  `priv/repo/migrations/20260914120528_add_oban_jobs_table.exs`) rather
  than building a bespoke event pipeline or a second telemetry sink: the
  question "did the tick worker actually run recently" is exactly what
  `oban_jobs.state`/`completed_at`/`attempted_at` already answer for real,
  once a job has been enqueued and processed.

  ## What counts as "the tick is alive"

  The most recent real evidence of the `:tick` worker having *run* --
  either a `"completed"` row's `completed_at`, or (so a job stuck mid-run
  still counts as recent activity rather than reading as instantly stale)
  an `"executing"` row's `attempted_at` -- compared against
  `now - stale_after_minutes`. `stale_after_minutes` defaults to 5 -- a
  small multiple of the real 1-minute cron period declared in
  `Xaas.Ultracode.Run`'s `oban do` block, tolerant of one or two
  skipped/slow ticks without alarming on every transient blip, but real:
  5 consecutive missed 1-minute ticks is a genuine liveness problem, not
  scheduler jitter.

  A worker that has *never* completed or executed (fresh install, cron
  plugin never wired up -- literally the failure this module exists to
  catch, per `Xaas.Application`'s "SECOND real finding" comment) reports
  `:stale` with `last_tick_at: nil`, not `:healthy` by default absence of
  evidence -- silence is not liveness.
  """

  import Ecto.Query, warn: false

  @tick_worker Oban.Worker.to_string(Xaas.Ultracode.Run.Workers.Tick)

  # Xaas.Ultracode.Run's `schedule :tick, "* * * * *"` fires once per
  # minute; 5x that period is the default staleness tolerance (see
  # moduledoc).
  @default_stale_after_minutes 5

  @type status :: :healthy | :stale

  @type result :: %{
          status: status(),
          worker: String.t(),
          last_tick_at: DateTime.t() | nil,
          elapsed_minutes: float() | nil,
          stale_after_minutes: pos_integer()
        }

  @doc """
  Real liveness check. Queries `Oban.Job` (via `opts[:repo]`, default
  `Xaas.Repo` -- the real repo `config :xaas, Oban` pins, see
  `config/config.exs`) for the most recent `"completed"`/`"executing"`
  row matching `opts[:worker]` (default: the real generated tick worker
  module, `Xaas.Ultracode.Run.Workers.Tick`), and classifies `:healthy`
  vs `:stale` against `opts[:stale_after_minutes]` (default `#{@default_stale_after_minutes}`).

  ## Options

    * `:repo` -- the `Ecto.Repo` to query. Default `Xaas.Repo`.
    * `:worker` -- the Oban worker string to match. Default the real
      `:tick` worker.
    * `:stale_after_minutes` -- staleness threshold in minutes. Default
      `#{@default_stale_after_minutes}`.
    * `:now` -- the reference "current time" (`DateTime.t()`). Default
      `DateTime.utc_now/0`. Real seam for a Chicago-style test to assert
      classification without depending on wall-clock timing.
  """
  @spec check(keyword()) :: result()
  def check(opts \\ []) do
    repo = Keyword.get(opts, :repo, Xaas.Repo)
    worker = Keyword.get(opts, :worker, @tick_worker)
    stale_after_minutes = Keyword.get(opts, :stale_after_minutes, @default_stale_after_minutes)
    now = Keyword.get(opts, :now, DateTime.utc_now())

    last_tick_at = last_tick_activity(repo, worker)

    elapsed_minutes =
      case last_tick_at do
        nil -> nil
        at -> DateTime.diff(now, at, :second) / 60
      end

    status =
      case elapsed_minutes do
        nil -> :stale
        minutes when minutes <= stale_after_minutes -> :healthy
        _ -> :stale
      end

    %{
      status: status,
      worker: worker,
      last_tick_at: last_tick_at,
      elapsed_minutes: elapsed_minutes,
      stale_after_minutes: stale_after_minutes
    }
  end

  # Most recent real evidence the tick worker ran: the newer of the last
  # `"completed"` row's `completed_at` and the last `"executing"` row's
  # `attempted_at`. Two separate single-column queries (each already
  # narrow via the `worker`+`state` match) rather than one query with an
  # `OR`/`coalesce`, so each stays a plain indexable equality+order-by --
  # real Oban job volume for a single scheduled-action worker is tiny
  # (one row inserted per minute), so the second round trip is a real,
  # bounded, disclosed cost, not a scaling risk.
  defp last_tick_activity(repo, worker) do
    completed_at =
      Oban.Job
      |> where([j], j.worker == ^worker and j.state == "completed")
      |> order_by([j], desc: j.completed_at)
      |> select([j], j.completed_at)
      |> limit(1)
      |> repo.one()

    executing_at =
      Oban.Job
      |> where([j], j.worker == ^worker and j.state == "executing")
      |> order_by([j], desc: j.attempted_at)
      |> select([j], j.attempted_at)
      |> limit(1)
      |> repo.one()

    [completed_at, executing_at]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      timestamps -> Enum.max(timestamps, DateTime)
    end
  end
end
