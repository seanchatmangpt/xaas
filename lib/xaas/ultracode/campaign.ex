defmodule Xaas.Ultracode.Campaign do
  @moduledoc """
  The 8-hour, capacity-5 ultracode wave campaign: one command that starts a
  bounded, budget-law-governed standing wave of `Xaas.Ultracode.Autonomic`
  loops, plus the `status`/`stop` companions the operator (and the harness
  keep-alive automation) read.

  ## The budget law

  A campaign is bounded by THREE real budgets, all persisted on a real
  `Xaas.Ultracode.Run` row (the "campaign row") at admission time:

    * `deadline_at`  = start + `:duration`        (default 8h) -- wall clock;
    * `max_cycles`   = ceil(duration / interval)  (default 30m interval),
      optionally capped by `:max_waves` -- the wave-count budget;
    * `:capacity`    -- workers per wave (default 5, the operator-ordered
      standing wave size), recorded in the ledger's `campaign_start` event
      and handed to every wave's runner.

  The `:repo` opt is a SPEC: one registered alias (`"aps"`, the default),
  a comma-separated list (`"alpha,beta"`), or `"all"` (every alias in
  `config :xaas, :ultracode_repos` at wave time). Each wave's runner draws
  its items across the selected repos with the deterministic
  `Xaas.Ultracode.WavePlan` rotation (no starvation: while a repo has
  ready items it gets at least one per wave; optional per-repo caps via
  `config :xaas, :ultracode_wave_repo_caps`), and every item carries its
  repo alias through plan -> worktree -> dispatch goal -> receipt ->
  ledger -> OCEL. A single-alias spec behaves byte-for-byte as before.

  The loop discharges the budget by running waves serially: each wave is
  one synchronous `Autonomic.run/1` (sense -> dispatch -> fabric-verify ->
  promote -> receipt, exactly what `mix xaas.autonomic.run` and the
  `:autonomic_wave` Oban action drive), scheduled on a fixed slot grid so
  a wave that overruns its interval is followed immediately by the next
  one (catch-up), never skipped silently. The campaign completes when
  EITHER budget is exhausted; `mix xaas.ultracode.stop` abandons it
  between waves through the real `:transition_state` action
  (`:running -> :abandoned`, an admitted edge of
  `Xaas.Ultracode.Validations.RunTransitionAllowed`).

  ## Why a `:running` campaign row is inert to the Oban `:tick` Reactor

  `Xaas.Ultracode.Reactor`'s tick fetches every `:running` Run, but every
  step is epoch-driven: with no `Epoch` rows, `MissedEpochs` is a no-op,
  `:run_active_epochs` finds no active epoch, and `NextEpoch.advance_run/1`
  returns `:no_prior_epoch` without mutating anything (verified against
  that module's own code). The campaign row therefore never accumulates
  epochs and is never advanced, completed, or failed by the tick -- only
  this module transitions it.

  ## Surfaces

    * `start/1` -- the launch path (`mix xaas.ultracode.start`). Synchronous
      by design: it runs waves until a budget discharges or the operator
      stops it, then returns the terminal summary.
    * `status/1` -- campaign row + budget remaining + per-wave ledger
      digest + fabric-wide in-flight epoch counts (what the harness
      keep-alive automation greps).
    * `stop/1` -- `:running -> :abandoned` through the admitted edge; the
      loop observes it at the next poll (waves are serial and synchronous,
      so an in-flight wave finishes first -- disclosed, not a bug).

  ## Waves go through the existing runner seam

  The wave runner is read from the SAME application-env seam the
  `:autonomic_wave` Oban action uses (`config :xaas, :ultracode_wave_runner`,
  default `{Xaas.Ultracode.Autonomic, :run}`), so tests (and a bounded
  smoke) can capture or substitute waves without reaching the real
  dispatcher subprocess. The default runner is the real autonomic loop;
  every wave appends its events to the campaign's own ndjson ledger (one
  file under `config :xaas, :ultracode_ticket_dir`), which is the durable
  record `status/1` digests -- session state lives in files, not in
  conversation.

  Campaign rows are identified by the `ultracode-campaign/1` goal prefix, so
  `status`/`stop` can default to "the most recent campaign" without a
  second hand-edited registry anywhere.
  """

  require Ash.Query

  alias Xaas.Ultracode.{Epoch, Run, WavePlan}

  @goal_marker "ultracode-campaign/1"
  @default_capacity 5
  @default_suite "aps-dod"
  @default_repo "aps"

  @typedoc "Duration/interval string: a positive integer with an h/m/s unit."
  @type duration_string :: String.t()

  @type start_opts :: [
          {:capacity, pos_integer()}
          | {:duration, duration_string()}
          | {:wave_interval, duration_string()}
          | {:max_waves, non_neg_integer() | nil}
          | {:goal, String.t() | nil}
          | {:repo, String.t()}
          | {:suite, String.t()}
          | {:only, [String.t()] | nil}
          | {:max_attempts, pos_integer()}
          | {:base_sha, String.t() | nil}
          | {:run_id, String.t() | nil}
          | {:ledger, String.t() | nil}
          | {:runner, {module(), atom()} | (keyword() -> {:ok, map()} | {:error, term()})}
          | {:sleeper, (pos_integer() -> any())}
          | {:state_poll_ms, pos_integer()}
        ]

  # ------------------------------------------------------------------
  # Parsing (shared by the mix tasks)
  # ------------------------------------------------------------------

  @doc """
  Parses a campaign duration/interval string into seconds. Strictly
  `<digits><h|m|s>`; anything else is a typed error, never a guess.
  """
  @spec parse_duration(term()) :: {:ok, pos_integer()} | {:error, {:bad_duration, term()}}
  def parse_duration(value) when is_binary(value) do
    case Regex.run(~r/^(\d+)([hms])$/, value) do
      [_, digits, unit] ->
        n = String.to_integer(digits)

        if n > 0 do
          {:ok, n * unit_seconds(unit)}
        else
          {:error, {:bad_duration, value}}
        end

      _ ->
        {:error, {:bad_duration, value}}
    end
  end

  def parse_duration(value), do: {:error, {:bad_duration, value}}

  defp unit_seconds("h"), do: 3600
  defp unit_seconds("m"), do: 60
  defp unit_seconds("s"), do: 1

  @doc false
  def goal_marker, do: @goal_marker

  # ------------------------------------------------------------------
  # start: create -> admit -> discharge the budget wave by wave
  # ------------------------------------------------------------------

  @doc """
  Starts (or resumes, with `:run_id`) a campaign and runs it synchronously
  until a budget discharges or `stop/1` abandons it. Returns
  `{:ok, summary}` where summary carries the terminal disposition, or a
  typed `{:error, reason}` for admission-time refusals (another campaign
  already running, unregistered verifier suite, unconfigured ticket dir,
  bad durations).
  """
  @spec start(start_opts()) :: {:ok, map()} | {:error, term()}
  def start(opts) do
    opts = Enum.into(opts, %{})

    with {:ok, resolved} <- resolve_start(opts),
         :ok <- ensure_no_other_running_campaign(resumed_id(resolved)),
         {:ok, {campaign, campaign_dir, ledger}} <- open_campaign(resolved) do
      discharge(resolved, campaign, campaign_dir, ledger)
    end
  end

  defp open_campaign(%{run_id: nil} = resolved), do: admit_campaign(resolved)

  defp open_campaign(%{run_id: id}) when is_binary(id), do: resume_campaign(id)

  defp resumed_id(%{run_id: id}) when is_binary(id), do: id
  defp resumed_id(_), do: nil

  defp resolve_start(opts) do
    with {:ok, duration_s} <- parse_duration(Map.get(opts, :duration, "8h")),
         {:ok, interval_s} <- parse_duration(Map.get(opts, :wave_interval, "30m")),
         :ok <- ticket_dir_configured(opts),
         {:ok, capacity} <- check_capacity(Map.get(opts, :capacity, @default_capacity)),
         {:ok, wave_budget} <- check_wave_budget(opts, duration_s, interval_s),
         :ok <- check_repo_spec(Map.get(opts, :repo, @default_repo)),
         :ok <- check_wave_repo_caps() do
      {:ok,
       %{
         capacity: capacity,
         duration_s: duration_s,
         interval_s: interval_s,
         wave_budget: wave_budget,
         goal: Map.get(opts, :goal) || default_goal(capacity, duration_s, interval_s),
         repo: Map.get(opts, :repo, @default_repo),
         suite: Map.get(opts, :suite, @default_suite),
         only: Map.get(opts, :only),
         max_attempts: Map.get(opts, :max_attempts, 3),
         base_sha: Map.get(opts, :base_sha),
         runner: Map.get(opts, :runner) || default_runner(),
         sleeper: Map.get(opts, :sleeper) || (&Process.sleep/1),
         state_poll_ms: Map.get(opts, :state_poll_ms, 2_000),
         ledger: Map.get(opts, :ledger),
         run_id: Map.get(opts, :run_id)
       }}
    end
  end

  defp check_capacity(capacity) when is_integer(capacity) and capacity >= 1, do: {:ok, capacity}
  defp check_capacity(capacity), do: {:error, {:bad_capacity, capacity}}

  # The repo spec is validated for SHAPE at admission (bad shape = typed
  # refusal before the campaign row exists); REGISTRY membership resolves
  # per wave in `Autonomic` (`"all"` in particular means "registered at
  # wave time", so membership is not frozen at admission). The per-repo
  # wave caps (config) are likewise shape-validated at admission.
  defp check_repo_spec(spec) do
    case WavePlan.parse_spec(spec) do
      {:ok, _} -> :ok
      {:error, _} = err -> err
    end
  end

  defp check_wave_repo_caps do
    case WavePlan.validate_caps(Application.get_env(:xaas, :ultracode_wave_repo_caps)) do
      {:ok, _caps} -> :ok
      {:error, _} = err -> err
    end
  end

  defp check_wave_budget(opts, duration_s, interval_s) do
    case Map.get(opts, :max_waves) do
      nil -> {:ok, ceil(duration_s / interval_s)}
      max_waves when is_integer(max_waves) and max_waves >= 0 -> {:ok, max_waves}
      other -> {:error, {:bad_max_waves, other}}
    end
  end

  defp ticket_dir_configured(opts) do
    if is_binary(Map.get(opts, :ledger)) or ticket_dir() do
      :ok
    else
      {:error, :ticket_dir_unconfigured}
    end
  end

  defp ticket_dir do
    case Application.get_env(:xaas, :ultracode_ticket_dir) do
      dir when is_binary(dir) and dir != "" -> dir
      _ -> nil
    end
  end

  defp default_runner do
    Application.get_env(:xaas, :ultracode_wave_runner, {Xaas.Ultracode.Autonomic, :run})
  end

  defp default_goal(capacity, duration_s, interval_s) do
    "Standing wave: #{capacity} workers per wave, one wave every #{interval_s} " <>
      "seconds, for #{duration_s} seconds total (operator-ordered 8-hour " <>
      "capacity-5 loop; budgets enforced by Xaas.Ultracode.Campaign)."
  end

  # Refuses (typed, never a silent overlap) when another campaign row is
  # already :running -- two concurrent campaigns would both sense and
  # dispatch the same backlog family. The resume case excludes its own row.
  defp ensure_no_other_running_campaign(resume_id) do
    query =
      Run
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(state == :running and like(goal, ^"#{@goal_marker} %"))

    case Ash.read(query, authorize?: false) do
      {:ok, running} ->
        case Enum.reject(running, &(&1.id == resume_id)) do
          [] -> :ok
          [%{id: other} | _] -> {:error, {:campaign_already_running, other}}
        end

      {:error, _} = err ->
        err
    end
  end

  defp discharge(resolved, campaign, campaign_dir, default_ledger_path) do
    File.mkdir_p!(campaign_dir)
    ledger = resolved.ledger || default_ledger_path

    if is_nil(Map.get(resolved, :run_id)) do
      append(ledger, %{
        event: "campaign_start",
        campaign_run_id: campaign.id,
        capacity: resolved.capacity,
        duration_seconds: resolved.duration_s,
        wave_interval_seconds: resolved.interval_s,
        wave_budget: resolved.wave_budget,
        repo: resolved.repo,
        suite: resolved.suite,
        only: resolved.only,
        max_attempts: resolved.max_attempts
      })
    end

    started_at = campaign.inserted_at
    waves_done = campaign.cycle

    summary = run_slots(resolved, campaign, ledger, started_at, waves_done, _receipts = [])

    append(ledger, Map.merge(%{event: "campaign_end", campaign_run_id: campaign.id}, summary))

    {:ok, Map.merge(summary, %{run_id: campaign.id, ledger: ledger})}
  end

  # Admission: create the campaign row and transition it :running. Both the
  # suite-name validation (`VerifierSuiteRegistered`) and the transition
  # validation run for real here -- failures surface as typed
  # `{:error, reason}`, not raises, so the mix task can report them as the
  # refusals they are.
  defp admit_campaign(resolved) do
    deadline = DateTime.add(DateTime.utc_now(), resolved.duration_s, :second)

    with {:ok, campaign} <-
           Run
           |> Ash.Changeset.for_create(
             :create,
             %{
               goal: "#{@goal_marker} #{resolved.goal}",
               provider: "zcode",
               verifier_suite: resolved.suite,
               max_cycles: resolved.wave_budget,
               deadline_at: deadline
             },
             authorize?: false
           )
           # An unregistered verifier suite is an admission refusal, not a
           # runtime surprise ten waves in.
           |> Ash.create(),
         {:ok, campaign} <-
           campaign
           |> Ash.Changeset.for_update(:transition_state, %{state: :running}, authorize?: false)
           |> Ash.update() do
      {:ok, {campaign, campaign_dir(campaign.id), default_ledger(campaign.id)}}
    end
  end

  defp resume_campaign(id) do
    campaign = Ash.get!(Run, id, action: :read_unscoped, authorize?: false)

    cond do
      campaign.state != :running ->
        {:error, {:campaign_not_running, id, campaign.state}}

      not String.starts_with?(campaign.goal, @goal_marker) ->
        {:error, {:not_a_campaign, id}}

      true ->
        {:ok, {campaign, campaign_dir(id), default_ledger(id)}}
    end
  end

  @doc """
  Chronological "is `now` at or past `deadline`".

  PERMANENT TRIPWIRE (observed falsifier 2026-09-20, wave-3 launch smoke):
  a campaign finished instantly -- "completed, 0 waves" -- with two minutes
  of wall-clock budget remaining, because `Kernel.>=` on two `DateTime`
  structs does STRUCTURAL map comparison, and maps compare their values in
  sorted-key order, so `:microsecond` (a tuple) is compared BEFORE `:minute`
  or `:second`: `07:57:43.809677 >= 07:59:43.721198` evaluated `true` on
  the microsecond tuples alone. `DateTime` structs must therefore never be
  compared with ordering operators -- only via `DateTime.compare/2` (or
  numeric `DateTime.diff/3`). This guard exists so the same reasoning is
  never re-purchased.
  """
  @spec past?(DateTime.t(), DateTime.t() | nil) :: boolean()
  def past?(_now, nil), do: false

  def past?(%DateTime{} = now, %DateTime{} = deadline) do
    DateTime.compare(now, deadline) != :lt
  end

  @doc false
  def campaign_dir(run_id) do
    Path.join(
      ticket_dir() || Path.join(System.tmp_dir!(), "xaas-campaigns"),
      "campaign-#{String.slice(run_id, 0, 8)}"
    )
  end

  defp default_ledger(run_id), do: Path.join(campaign_dir(run_id), "ledger.ndjson")

  # The slot grid: wave k starts at started_at + (waves_done + k) * interval.
  # A wave that overruns its slot is followed immediately by the next one
  # (catch-up, the same observable behavior as the single-slot
  # `:ultracode_wave` Oban queue), never skipped.
  defp run_slots(resolved, campaign, ledger, started_at, waves_done, receipts) do
    campaign = reload(campaign.id)
    now = DateTime.utc_now()

    cond do
      campaign.state == :abandoned ->
        stopped_summary(campaign, waves_done, receipts)

      campaign.state != :running ->
        # Someone else transitioned the row mid-campaign; never fight it.
        stopped_summary(campaign, waves_done, receipts)

      past?(now, campaign.deadline_at) or waves_done >= campaign.max_cycles ->
        finish(campaign, waves_done, receipts)

      true ->
        wave_number = waves_done + 1
        slot_at = DateTime.add(started_at, waves_done * resolved.interval_s, :second)
        wait_for_slot(resolved, campaign, slot_at)

        # Stop may have landed while waiting for the slot.
        campaign = reload(campaign.id)

        if campaign.state != :running do
          stopped_summary(campaign, waves_done, receipts)
        else
          {wave_summary, receipt_path} = run_wave(resolved, campaign, ledger, wave_number)
          campaign = advance!(campaign)

          run_slots(resolved, campaign, ledger, started_at, waves_done + 1, [
            {wave_summary, receipt_path} | receipts
          ])
        end
    end
  end

  defp wait_for_slot(resolved, campaign, slot_at) do
    ms_until_slot = DateTime.diff(slot_at, DateTime.utc_now(), :millisecond)

    if ms_until_slot > 0 do
      resolved.sleeper.(min(resolved.state_poll_ms, ms_until_slot))

      # Poll stop state while waiting so stop responsiveness does not
      # depend on the interval length.
      if reload(campaign.id).state == :running do
        wait_for_slot(resolved, campaign, slot_at)
      end
    end
  end

  defp run_wave(resolved, campaign, ledger, wave_number) do
    wave_opts =
      [
        capacity: resolved.capacity,
        repo: resolved.repo,
        suite: resolved.suite,
        only: resolved.only,
        max_attempts: resolved.max_attempts,
        base_sha: resolved.base_sha,
        ledger: ledger,
        state_dir: Path.join(campaign_dir(campaign.id), "dispatch-wave-#{wave_number}")
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    append(ledger, %{
      event: "campaign_wave_start",
      campaign_run_id: campaign.id,
      wave: wave_number,
      opts: Map.new(wave_opts)
    })

    result = call_runner(resolved.runner, wave_opts)

    case result do
      {:ok, report} ->
        receipt_path = report["receipt_path"]

        append(ledger, %{
          event: "campaign_wave_done",
          campaign_run_id: campaign.id,
          wave: wave_number,
          standing: report["standing"],
          receipt: receipt_path,
          items: wave_items(report)
        })

        {%{wave: wave_number, standing: report["standing"], error: nil}, receipt_path}

      {:error, reason} ->
        append(ledger, %{
          event: "campaign_wave_failed",
          campaign_run_id: campaign.id,
          wave: wave_number,
          error: inspect(reason)
        })

        {%{wave: wave_number, standing: "BLOCKED", error: inspect(reason)}, nil}
    end
  end

  defp call_runner({mod, fun}, opts) when is_atom(mod) and is_atom(fun),
    do: apply(mod, fun, [opts])

  defp call_runner(fun, opts) when is_function(fun, 1), do: fun.(opts)

  defp wave_items(report) do
    case report["items"] do
      items when is_list(items) ->
        Enum.map(items, fn i ->
          base = %{
            "item" => i["item"],
            "status" => i["status"],
            "epoch_id" => i["epoch_id"],
            "receipt_id" => i["receipt_id"]
          }

          # Multi-repo waves tag each item with its repo; single-repo
          # reports carry no "repo" key and keep the historical line shape.
          if is_map_key(i, "repo"), do: Map.put(base, "repo", i["repo"]), else: base
        end)

      _ ->
        []
    end
  end

  defp advance!(campaign) do
    campaign
    |> Ash.Changeset.for_update(:advance_cycle, %{}, authorize?: false)
    |> Ash.update!()
  end

  defp reload(id), do: Ash.get!(Run, id, action: :read_unscoped, authorize?: false)

  defp finish(campaign, waves_done, receipts) do
    waves = chronological_waves(receipts)
    standings = Enum.map(waves, & &1.standing)

    standing =
      cond do
        standings == [] -> :unknown
        Enum.all?(standings, &(&1 == "ALIVE")) -> :admitted
        true -> :blocked
      end

    campaign
    |> Ash.Changeset.for_update(:transition_state, %{state: :completed, standing: standing},
      authorize?: false
    )
    |> Ash.update!()

    %{
      status: :completed,
      waves_executed: waves_done,
      wave_budget: campaign.max_cycles,
      standing: Atom.to_string(standing),
      waves: waves
    }
  end

  defp stopped_summary(campaign, waves_done, receipts) do
    waves = chronological_waves(receipts)

    %{
      status: :stopped,
      waves_executed: waves_done,
      wave_budget: campaign.max_cycles,
      standing: List.last(waves) && List.last(waves).standing,
      waves: waves
    }
  end

  defp chronological_waves(receipts) do
    receipts
    |> Enum.reverse()
    |> Enum.map(fn {summary, path} ->
      %{wave: summary.wave, standing: summary.standing, error: summary.error, receipt: path}
    end)
  end

  # ------------------------------------------------------------------
  # stop
  # ------------------------------------------------------------------

  @doc """
  Abandons a running campaign through the real `:transition_state` action
  (`:running -> :abandoned`, an admitted edge). With no id, targets the
  most recent `:running` campaign row. An in-flight wave finishes first
  (waves are serial and synchronous) -- the loop observes the abandonment
  at its next poll.
  """
  @spec stop(String.t() | nil) :: {:ok, Run.t()} | {:error, term()}
  def stop(nil) do
    case most_recent_campaign(:running) do
      {:ok, %Run{} = campaign} -> stop(campaign.id)
      {:error, _} = err -> err
    end
  end

  def stop(run_id) when is_binary(run_id) do
    campaign = Ash.get!(Run, run_id, action: :read_unscoped, authorize?: false)

    cond do
      not String.starts_with?(campaign.goal, @goal_marker) ->
        {:error, {:not_a_campaign, run_id}}

      campaign.state != :running ->
        {:error, {:campaign_not_running, run_id, campaign.state}}

      true ->
        campaign
        |> Ash.Changeset.for_update(:transition_state, %{state: :abandoned}, authorize?: false)
        |> Ash.update()
        |> case do
          {:ok, campaign} -> {:ok, campaign}
          {:error, _} = err -> err
        end
    end
  end

  # ------------------------------------------------------------------
  # status
  # ------------------------------------------------------------------

  @doc """
  Real status for the campaign the operator (or the harness keep-alive
  automation) asks about: the campaign row itself, the budget remaining,
  the per-wave ledger digest, and the fabric-wide in-flight epoch counts.
  With no id, defaults to the most recent campaign row in ANY state.
  """
  @spec status(String.t() | nil) :: {:ok, map()} | {:error, term()}
  def status(nil) do
    case most_recent_campaign(nil) do
      {:ok, %Run{} = campaign} -> status(campaign.id)
      {:error, _} = err -> err
    end
  end

  def status(run_id) when is_binary(run_id) do
    campaign = Ash.get!(Run, run_id, action: :read_unscoped, authorize?: false)
    ledger = default_ledger(run_id)
    events = read_ledger(ledger)
    waves = Enum.filter(events, &(&1["event"] in ["campaign_wave_done", "campaign_wave_failed"]))

    now = DateTime.utc_now()

    seconds_remaining = max(0, DateTime.diff(campaign.deadline_at || now, now, :second))

    {:ok,
     %{
       run_id: campaign.id,
       state: campaign.state,
       standing: campaign.standing,
       goal: campaign.goal,
       waves_executed: campaign.cycle,
       wave_budget: campaign.max_cycles,
       deadline_at: campaign.deadline_at,
       seconds_remaining: seconds_remaining,
       waves: Enum.map(waves, &%{wave: &1["wave"], standing: &1["standing"], error: &1["error"]}),
       ledger: ledger,
       ledger_present: File.regular?(ledger),
       in_flight: in_flight_epochs()
     }}
  end

  # Fabric-wide in-flight: every epoch currently `:running`, split by
  # whether a worker holds the lease. This is the number the harness
  # keep-alive automation compares against the capacity setpoint.
  defp in_flight_epochs do
    {:ok, epochs} =
      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(state == :running)
      |> Ash.read(authorize?: false)

    leased = Enum.count(epochs, &(&1.lease_token != nil))

    %{
      total: length(epochs),
      leased: leased,
      unleased: length(epochs) - leased
    }
  end

  defp most_recent_campaign(want_state) do
    query =
      Run
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(like(goal, ^"#{@goal_marker} %"))
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(1)

    query =
      if want_state do
        Ash.Query.filter(query, state == ^want_state)
      else
        query
      end

    case Ash.read(query, authorize?: false) do
      {:ok, [%Run{} = campaign]} -> {:ok, campaign}
      {:ok, []} -> {:error, :no_campaign_found}
      {:error, _} = err -> err
    end
  end

  # ------------------------------------------------------------------
  # Ledger (append-only ndjson; the durable session record)
  # ------------------------------------------------------------------

  defp append(ledger, event) do
    line =
      Jason.encode!(Map.put(event, :ts, DateTime.to_iso8601(DateTime.utc_now()))) <> "\n"

    File.mkdir_p!(Path.dirname(ledger))
    File.write!(ledger, line, [:append])
  end

  defp read_ledger(ledger) do
    if File.regular?(ledger) do
      ledger
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)
    else
      []
    end
  end
end
