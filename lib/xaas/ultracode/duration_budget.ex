defmodule Xaas.Ultracode.DurationBudget do
  @moduledoc """
  The duration-budget law for Ultracode runs: an 8-hour standing wave.

  The operator's order, materialized as executable law: keep a capacity-5
  agent loop running for exactly 8 hours -- continuous 30-minute waves --
  then stop dispatching, drain in-flight workers, transition the run to
  the terminal `:completed` state, and emit a final receipt. This module
  is the law's SINGLE SOURCE OF TRUTH; every enforcement site (the
  `:autonomic_wave` scheduler gate in `Xaas.Ultracode.Run`,
  `Xaas.Ultracode.Lease.claim_next/3`'s ready-work filter,
  `Xaas.Ultracode.NextEpoch`'s epoch dispatch) calls THESE functions, so
  there is exactly one statement of the boundary and no drift:

    * `deadline/1` -- `started_at + duration_budget_seconds`, the one
      boundary. Mirrored in the database by `Run.budget_deadline_at`'s
      expression calculation (same arithmetic, provably identical), so
      the DB-enforced candidate filter and this pure law cannot diverge.
    * `exhausted?/2` / `remaining_seconds/2` / `gate/2` -- pure,
      clock-injected (`now` is always an argument): no test sleeps real
      hours; a test fast-forwards the injected clock instead.
    * `find_or_begin_wave_session/1` / `record_wave/1` -- the standing
      wave session is a real `Xaas.Ultracode.Run` (`wave_session: true`):
      `started_at` written ONCE at begin; a later fire finds the same
      session, which is exactly the resume semantics the law requires
      (remaining budget is wall-clock from start, never reset -- a
      stopped session with budget left resumes; an exhausted one does
      not).
    * `drain_and_complete/2` -- the drain law: in-flight workers are
      never silently abandoned. Stale (`expected_at` older than the
      run's `epoch_timeout_seconds`) in-flight epochs are REAPED via the
      existing `Xaas.Ultracode.MissedEpochs.advance_run/1` rule; LIVE
      leases are left to finish. Only when no active epoch remains does
      the run transition to terminal `:completed` and the final receipt
      is built -- otherwise the caller gets `{:error, {:draining, _}}`
      and retries later. A run can therefore never silently exceed its
      budget (dispatch stops at the boundary) nor silently claim
      completion over live workers.

  Clock seam: `now/0` reads `Application.get_env(:xaas, :ultracode_clock)`
  -- `{Module, :fun}` or a zero-arity fun, default `{DateTime, :utc_now}`
  -- the same application-env convention as `:ultracode_wave_runner`.
  Tests inject a steppable clock; production code paths use the default
  unchanged.
  """

  require Ash.Query

  alias Xaas.Ultracode.{Epoch, MissedEpochs, Run}

  # The operator's order: 8 hours. Overridable globally via
  # `Application.put_env(:xaas, :ultracode_default_duration_budget_seconds, n)`
  # and per run via `Run.duration_budget_seconds` (the default below only
  # fills the attribute default and the session-begin path).
  @default_budget_seconds 28_800

  @wave_capacity 5
  @receipt_schema "xaas.run-duration-budget-receipt/1"

  # ------------------------------------------------------------------
  # Clock seam
  # ------------------------------------------------------------------

  @doc """
  The law's clock. `Application.get_env(:xaas, :ultracode_clock)` --
  `{Module, :fun}` or a zero-arity fun; default `{DateTime, :utc_now}`.
  Everything in this module that needs "now" goes through here (or takes
  `now` explicitly), so tests fast-forward time without sleeping.
  """
  @spec now() :: DateTime.t()
  def now do
    case Application.get_env(:xaas, :ultracode_clock, {DateTime, :utc_now}) do
      {mod, fun} when is_atom(mod) and is_atom(fun) -> apply(mod, fun, [])
      fun when is_function(fun, 0) -> fun.()
    end
  end

  @doc """
  The default budget in seconds (the 8-hour order), overridable via
  `:xaas, :ultracode_default_duration_budget_seconds`.
  """
  @spec default_budget_seconds() :: pos_integer()
  def default_budget_seconds do
    Application.get_env(
      :xaas,
      :ultracode_default_duration_budget_seconds,
      @default_budget_seconds
    )
  end

  @doc """
  The operator-ordered standing-wave size (capacity 5): five concurrent
  leased workers per wave.
  """
  @spec wave_capacity() :: pos_integer()
  def wave_capacity, do: @wave_capacity

  # ------------------------------------------------------------------
  # The pure law
  # ------------------------------------------------------------------

  @doc """
  The budget boundary: `started_at + duration_budget_seconds`. `nil` when
  the run was never started (`started_at: nil`) -- no budget in force,
  today's behavior. Identical arithmetic to `Run.budget_deadline_at`'s
  expression calculation (the DB-enforced form).
  """
  @spec deadline(Run.t()) :: DateTime.t() | nil
  def deadline(%Run{started_at: nil}), do: nil

  def deadline(%Run{started_at: started_at, duration_budget_seconds: seconds})
      when is_integer(seconds) do
    DateTime.add(started_at, seconds, :second)
  end

  @doc """
  Whole seconds of budget remaining at `now` (0 once the boundary passed).
  `nil` when no budget is in force.
  """
  @spec remaining_seconds(Run.t(), DateTime.t()) :: non_neg_integer() | nil
  def remaining_seconds(%Run{} = run, now) do
    case deadline(run) do
      nil -> nil
      deadline -> max(0, DateTime.diff(deadline, now, :second))
    end
  end

  @doc """
  Whether the budget is exhausted at `now`. `false` when no budget is in
  force (`started_at: nil`) -- absence of a start is not exhaustion.
  """
  @spec exhausted?(Run.t(), DateTime.t()) :: boolean()
  def exhausted?(%Run{} = run, now) do
    case deadline(run) do
      nil -> false
      deadline -> DateTime.compare(now, deadline) != :lt
    end
  end

  @doc """
  The one dispatch decision: `:allow` within budget,
  `{:refuse, :budget_exhausted, details}` past it. The scheduler (and any
  other dispatch site) MUST call this before dispatching new work; a
  refusal is final for that instant -- time only moves forward, so a run
  past its boundary can never become dispatchable again (a run cannot
  silently exceed its budget).
  """
  @spec gate(Run.t(), DateTime.t()) ::
          :allow | {:refuse, :budget_exhausted, map()}
  def gate(%Run{} = run, now) do
    if exhausted?(run, now) do
      {:refuse, :budget_exhausted,
       %{
         run_id: run.id,
         started_at: run.started_at,
         deadline_at: deadline(run),
         now: now,
         budget_seconds: run.duration_budget_seconds,
         overrun_seconds: overrun_seconds(run, now)
       }}
    else
      :allow
    end
  end

  defp overrun_seconds(%Run{started_at: nil}, _now), do: nil

  defp overrun_seconds(%Run{started_at: started_at, duration_budget_seconds: seconds}, now)
       when is_integer(seconds) do
    max(0, DateTime.diff(now, started_at, :second) - seconds)
  end

  # ------------------------------------------------------------------
  # The standing-wave session (a real Run row: begun once, resumed with
  # remaining budget, counted per wave, drained, completed, receipted)
  # ------------------------------------------------------------------

  @doc """
  Finds the currently-`:running` wave-session Run, or -- when none exists
  -- begins one: a real `Run` (`wave_session: true`) whose `started_at` is
  written ONCE, from the clock, at this first scheduler fire. Returns
  `{:ok, run, :begun}` or `{:ok, run, :resumed}` -- the phase is evidence:
  `:resumed` with budget left is the law's resume path (remaining budget
  computed from the ORIGINAL `started_at`, never reset); `:resumed` past
  the budget is refused downstream by `gate/2`.

  A TERMINAL session (the 8-hour run already completed) refuses a new one
  -- `{:refuse, :standing_wave_completed, session}`: the operator's order
  was "waves for exactly 8 hours, THEN STOP DISPATCHING", so the loop
  stays stopped after completion; re-arming is a new order, either by
  beginning a fresh session explicitly (`Run.:begin_wave_session`) or by
  opting in per environment via
  `Application.put_env(:xaas, :ultracode_wave_rearm, true)`.
  """
  @spec find_or_begin_wave_session(keyword()) ::
          {:ok, Run.t(), :begun | :resumed}
          | {:refuse, :standing_wave_completed, Run.t()}
          | {:error, term()}
  def find_or_begin_wave_session(opts \\ []) do
    budget = Keyword.get(opts, :budget_seconds, default_budget_seconds())

    case running_session() do
      {:ok, %Run{} = session} ->
        {:ok, session, :resumed}

      {:ok, nil} ->
        maybe_begin_session(budget)
    end
  end

  # At most one `:running` session by scheduler discipline (the
  # single-slot `:ultracode_wave` queue serializes fires); newest wins if
  # operator actions ever left two behind.
  defp running_session do
    Run
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(wave_session == true and state == :running)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read_one()
  end

  defp maybe_begin_session(budget) do
    rearm? = Application.get_env(:xaas, :ultracode_wave_rearm, false)

    case latest_session() do
      {:ok, nil} ->
        begin_session(budget)

      {:ok, %Run{state: :completed}} when rearm? ->
        begin_session(budget)

      {:ok, %Run{} = session} ->
        # Completed (re-arm off) or otherwise terminal -- the standing
        # wave ran its budget and STOPPED. Stays stopped.
        {:refuse, :standing_wave_completed, session}
    end
  end

  defp latest_session do
    Run
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(wave_session == true)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read_one()
  end

  defp begin_session(budget) do
    goal =
      "standing wave: capacity #{@wave_capacity}, duration budget #{budget}s " <>
        "(operator order: keep a #{@wave_capacity}-agent loop running for 8 hours)"

    with {:ok, run} <-
           Run
           |> Ash.Changeset.for_create(
             :create,
             %{goal: goal, max_cycles: 1, duration_budget_seconds: budget},
             authorize?: false
           )
           |> Ash.create(),
         {:ok, session} <-
           run
           |> Ash.Changeset.for_update(:begin_wave_session, %{}, authorize?: false)
           |> Ash.update() do
      {:ok, session, :begun}
    end
  end

  @doc """
  Counts one dispatched wave on the session Run (the `:record_wave`
  action) -- what the final receipt reports as "waves run".
  """
  @spec record_wave(Run.t()) :: {:ok, Run.t()} | {:error, term()}
  def record_wave(%Run{} = session) do
    session
    |> Ash.Changeset.for_update(:record_wave, %{}, authorize?: false)
    |> Ash.update()
  end

  # ------------------------------------------------------------------
  # Drain + terminal transition + final receipt
  # ------------------------------------------------------------------

  @doc """
  The drain law, applied to one Run past its budget (the scheduler calls
  it on the wave session; it works identically on any Run):

    1. REAP: in-flight-but-stale epochs (`:expected`/`:running`, past the
       run's own `epoch_timeout_seconds`) are reaped via the EXISTING
       `Xaas.Ultracode.MissedEpochs.advance_run/1` rule (epoch -> `:missed`
       + a sealed `:blocked` Receipt -- no new rule invented here).
    2. DRAIN-GUARD: LIVE in-flight epochs (unexpired leases, in-flight
       work) are left to FINISH -- the run is NOT completed over them;
       `{:error, {:draining, info}}` is returned and the caller retries
       on a later fire/tick.
    3. COMPLETE: with zero active epochs remaining, the run transitions
       to terminal `:completed` (existing `:transition_state` action,
       `standing: :admitted` matching `NextEpoch`'s completion precedent)
       and the final receipt is built (and persisted when a ticket dir is
       configured).

  Options: `:now` (injected clock), `:receipt_dir` (default: the
  configured `:xaas, :ultracode_ticket_dir` when set; `nil` skips the
  file write -- the receipt is always returned in the result).
  """
  @spec drain_and_complete(Run.t(), keyword()) ::
          {:ok, %{run: Run.t(), receipt: map()}} | {:error, {:draining, map()}}
  def drain_and_complete(%Run{} = run, opts \\ []) do
    now = Keyword.get(opts, :now, now())

    # Reap stale in-flight epochs per the existing rule. Live leases are
    # deliberately untouched: finish-or-reap is the drain contract.
    _reaped = MissedEpochs.advance_run(run)

    active = active_epoch_count(run)

    if active > 0 do
      {:error,
       {:draining,
        %{
          run_id: run.id,
          active_epochs: active,
          waves_run: run.waves_run,
          budget_seconds: run.duration_budget_seconds
        }}}
    else
      run = Ash.get!(Run, run.id, action: :read_unscoped, authorize?: false)

      {:ok, completed} =
        run
        |> Ash.Changeset.for_update(
          :transition_state,
          %{state: :completed, standing: :admitted},
          authorize?: false
        )
        |> Ash.update()

      receipt = final_receipt(completed, now, opts)
      {:ok, %{run: completed, receipt: receipt}}
    end
  end

  defp active_epoch_count(%Run{id: id}) do
    Epoch
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(run_id == ^id and state in [:expected, :running])
    |> Ash.count!()
  end

  @doc """
  The final receipt for one (completed) Run: waves run, epochs
  terminal-counted (per-state counts, so "nothing in flight" is
  checkable, not narrated), and duration actual vs budget. `within_budget`
  is computed, never asserted: a completion past the boundary (drain
  finished after the deadline) reports `false` with the overrun --
  evidence, not decoration.
  """
  @spec final_receipt(Run.t(), DateTime.t(), keyword()) :: map()
  def final_receipt(%Run{} = run, now, opts \\ []) do
    receipt =
      %{
        "schema" => @receipt_schema,
        "run_id" => run.id,
        "wave_session" => run.wave_session,
        "standing" => to_string(run.standing),
        "started_at" => iso(run.started_at),
        "deadline_at" => iso(deadline(run)),
        "finished_at" => iso(now),
        "budget_seconds" => run.duration_budget_seconds,
        "duration_actual_seconds" => duration_actual(run, now),
        "within_budget" => within_budget?(run, now),
        "waves_run" => run.waves_run,
        "epochs" => epoch_state_counts(run),
        "human_inputs" => 0
      }

    case receipt_dir(opts) do
      nil ->
        Map.put(receipt, "receipt_path", nil)

      dir ->
        path = Path.join(dir, "budget-receipt-#{run.id}.json")
        File.mkdir_p!(dir)
        File.write!(path, Jason.encode!(receipt, pretty: true))
        Map.put(receipt, "receipt_path", path)
    end
  end

  defp receipt_dir(opts) do
    case Keyword.fetch(opts, :receipt_dir) do
      {:ok, dir} -> dir
      :error -> Application.get_env(:xaas, :ultracode_ticket_dir)
    end
  end

  defp duration_actual(%Run{started_at: nil}, _now), do: nil

  defp duration_actual(%Run{started_at: started_at}, now) do
    DateTime.diff(now, started_at, :second)
  end

  defp within_budget?(%Run{started_at: nil}, _now), do: true

  defp within_budget?(%Run{started_at: started_at, duration_budget_seconds: seconds}, now)
       when is_integer(seconds) do
    DateTime.diff(now, started_at, :second) <= seconds
  end

  defp epoch_state_counts(%Run{id: id}) do
    Epoch
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(run_id == ^id)
    |> Ash.read!()
    |> Enum.map(& &1.state)
    |> then(fn states ->
      %{
        "expected" => count(states, :expected),
        "running" => count(states, :running),
        "completed" => count(states, :completed),
        "missed" => count(states, :missed),
        "failed" => count(states, :failed)
      }
    end)
  end

  defp count(states, state), do: Enum.count(states, &(&1 == state))

  defp iso(nil), do: nil
  defp iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
end
