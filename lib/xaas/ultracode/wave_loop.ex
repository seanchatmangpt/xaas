defmodule Xaas.Ultracode.WaveLoop do
  require Logger
  require Ash.Query

  alias Xaas.Ultracode.{Dispatch, Epoch, Receipt, Run}
  alias Xaas.Ultracode.WaveLoop.State

  @kind "ultracode-wave-loop/1"
  @kind_token "\"kind\":\"ultracode-wave-loop/1\""
  @provider "zcode"
  @default_state_path "/Users/sac/xaas/tmp/w8-loop/STATE.md"
  @default_telemetry_path "/Users/sac/xaas/tmp/w8-loop/loop.ndjson"
  # A step turn may legitimately run long (branch integrations with full
  # gates); bounded UNDER the hourly cadence so one tick can never overlap
  # the next through its own dispatch.
  @default_timeout_seconds 3300
  # Per-run missed-epoch tolerance: the hourly tick/missed-epoch machinery
  # must never reap a loop epoch mid-turn; the worker's own lease renewal
  # plus this bound keep the epoch alive for the whole dispatch.
  @epoch_timeout_seconds 7200

  @moduledoc """
  The fabric-native hourly wave loop: the Oban scheduler's own clock
  (`:wave_loop`, hourly, single-slot `:ultracode_wave_loop` queue) drives the
  operator's loop STATE file one REAL zcode worker step at a time.

  ## Why this is fabric-native (the verified finding)

  The operator ordered an hourly 8-agent loop; the zcode platform scheduler
  refuses to create it -- "Cannot create a scheduled task inside a session
  that already belongs to a scheduled task" -- and that enforcement is
  PLATFORM-SIDE, not in our fork (verified 2026-09-19: no CronCreate or
  scheduler code exists in `~/dev/zcode-cli/src`). The fabric's own Oban
  scheduler -- already proven by `:autonomic_wave`, `:semantic_wave` and
  `:engine_cycle` -- is therefore THE wave loop. The hourly cron is the
  loop's clock; event-drivenness is not required.

  ## One tick (the `:wave_loop` action body, `Xaas.Ultracode.WaveLoop.tick/1`)

    1. READ the STATE file (`/Users/sac/xaas/tmp/w8-loop/STATE.md`) and
       parse it through `Xaas.Ultracode.WaveLoop.State` -- a tolerant
       parser whose every unknown shape is a TYPED refusal, never a crash.
    2. SELECT the first actionable step: first table step that owes work
       (pending/blocked, or re-opened by the REMAINING note) whose deps
       (the note's chain + `BLOCKED-ON-` tokens) are all done.
    3. EXECUTE it by launching ONE real zcode CLI worker through the
       admitted `Xaas.Ultracode.Dispatch` boundary: a fresh `Run`
       (`execution_policy: :wave_loop_step`, `provider: "zcode"`,
       non-semantic, so the generic `/xaas` claim prompt path) whose GOAL
       carries the step id, the step's dispatch instructions VERBATIM from
       STATE.md, the standing table, the law section, and the mandatory
       "update STATE.md + append loop.ndjson" instruction. The worker
       claims the epoch through the fabric, works, and closes with
       evidence -- the loop never closes on the worker's behalf.
    4. SETTLE from the database and the sealed receipts (never the
       worker's exit code alone): a completed epoch advances the STATE
       row (respecting a worker's own DONE wording) and removes the step
       from the REMAINING note; a dead worker's stale epoch is reaped
       (`:mark_failed` + `:refused` receipt, the `Xaas.Ultracode.Engine`
       semantics) and the row goes BLOCKED with the log path. Every
       outcome appends EXACTLY ONE telemetry line
       (`kind: "ultracode-wave-loop/1"`).
    5. COMPLETE: when the STATE's remaining list is empty, the loop marks
       STATE COMPLETE and every later tick is a `:complete` no-op. The
       post-merge CI check inside that terminal claim is the closing step
       worker's acceptance (`gh api`), never the loop's -- loop ticks
       never run `mix test` themselves.

  ## Capacity and determinism laws

    * ONE loop worker at a time. A previous tick's still-running worker
      (a live lease on a `:wave_loop_step` epoch) makes this tick record
      `busy` and exit 0. A lease that has EXPIRED is not a running worker:
      the stale epoch is reaped first, then this tick proceeds.
    * STATE writes are atomic (temp file + rename in the same directory).
    * A corrupted/unreadable STATE file is a typed `:refused` tick with
      telemetry -- never a crash loop.
    * The tick carries zero ambient authority beyond the scheduler's own
      `:oban_scheduler` action admission (XAAS-2601 closed map); its
      internal row mutations follow the established per-call-site
      precedents (`authorize?: false` run construction like
      `DurationBudget`, `:ultracode_reactor` actor on reaping like
      `Engine`).

  ## Seams (the repo's application-env convention)

    * `config :xaas, :ultracode_wave_loop_state_path` (default
      #{@default_state_path})
    * `config :xaas, :ultracode_wave_loop_telemetry_path` (default
      #{@default_telemetry_path})
    * `config :xaas, :ultracode_wave_loop_timeout_seconds` (default
      #{@default_timeout_seconds}; under the hourly cadence)
    * `config :xaas, :ultracode_wave_loop_runner` -- the `:wave_loop`
      action's runner, `{Xaas.Ultracode.WaveLoop, :tick}` by default
    * `config :xaas, :ultracode_wave_loop_dispatcher` -- the dispatch
      boundary, `{Xaas.Ultracode.Dispatch, :dispatch}` by default; tests
      inject the seam exactly like every other runner seam in this repo.
  """

  alias Xaas.Ultracode.{Dispatch, Epoch, Receipt, Run}
  alias Xaas.Ultracode.WaveLoop.State

  @doc """
  One loop tick. ALWAYS returns `{:ok, report}` -- the report is the
  receipt (`:outcome` carrying the standing vocabulary: `:complete`,
  `:busy`, `:waiting_deps`, `:refused`, `:worker_completed`, `:blocked`,
  `:handed_off`, `:dispatch_refused`, `:error`); the Oban job never fails
  on loop-level facts, because a failing Oban retry loop is exactly the
  crash loop the law forbids.
  """
  @spec tick(keyword()) :: {:ok, map()}
  def tick(opts \\ []) do
    state_path = opt(opts, :state_path, :ultracode_wave_loop_state_path, @default_state_path)

    telemetry_path =
      opt(opts, :telemetry_path, :ultracode_wave_loop_telemetry_path, @default_telemetry_path)

    tick_no = next_tick_number(telemetry_path)

    try do
      do_tick(opts, state_path, telemetry_path, tick_no)
    rescue
      error ->
        Logger.error("[ultracode-wave-loop] tick #{tick_no} crashed: #{Exception.message(error)}")

        finish(tick_no, nil, :error, %{reason: Exception.message(error)}, telemetry_path)
    end
  end

  # ------------------------------------------------------------------
  # The tick
  # ------------------------------------------------------------------

  defp do_tick(opts, state_path, telemetry_path, tick_no) do
    with {:ok, raw} <- read_state(state_path),
         {:ok, state} <- State.parse(raw) do
      cond do
        State.complete?(state) ->
          finish(tick_no, nil, :complete, %{note: "STATE is complete"}, telemetry_path)

        true ->
          case State.first_actionable(state) do
            :complete ->
              finish(tick_no, nil, :complete, %{note: "no remaining steps"}, telemetry_path)

            {:waiting, step, unmet} ->
              finish(tick_no, step.id, :waiting_deps, %{unmet: unmet}, telemetry_path)

            {:ok, step} ->
              dispatch_step(step, state, opts, state_path, telemetry_path, tick_no)
          end
      end
    else
      {:error, {:state_read, reason}} ->
        finish(
          tick_no,
          nil,
          :refused,
          %{reason: "state unreadable: #{inspect(reason)}"},
          telemetry_path
        )

      {:error, {:malformed_state, _}} = refusal ->
        finish(tick_no, nil, :refused, %{reason: format_refusal(refusal)}, telemetry_path)
    end
  end

  defp dispatch_step(step, state, opts, state_path, telemetry_path, tick_no) do
    case acquire_slot() do
      {:busy, run_id, epoch_id} ->
        finish(tick_no, step.id, :busy, %{run_id: run_id, epoch_id: epoch_id}, telemetry_path)

      {:stale_reap_failed, reason} ->
        finish(tick_no, step.id, :stale_reap_failed, %{reason: inspect(reason)}, telemetry_path)

      :ok ->
        run_step(step, state, opts, state_path, telemetry_path, tick_no)
    end
  end

  defp run_step(step, state, opts, state_path, telemetry_path, tick_no) do
    goal =
      State.build_goal(state, step, %{state_path: state_path, telemetry_path: telemetry_path})

    subject = "wave-loop:step-#{step.id}@#{state_path}"

    with {:ok, run} <- create_loop_run(goal),
         {:ok, run} <- start_run(run, subject),
         {:ok, epoch} <- activate_first_epoch(run) do
      result = dispatch(epoch, opts)
      settle(step, epoch.id, result, state_path, telemetry_path, tick_no)
    else
      {:error, reason} ->
        # Construction refused: nothing ran, so the STATE row is untouched
        # and the next tick retries. Typed, never raised.
        finish(
          tick_no,
          step.id,
          :construction_refused,
          %{reason: inspect(reason)},
          telemetry_path
        )
    end
  end

  # ------------------------------------------------------------------
  # Capacity: ONE loop worker at a time
  # ------------------------------------------------------------------

  defp acquire_slot do
    case find_in_flight() do
      nil ->
        :ok

      %Epoch{id: epoch_id, run_id: run_id} = epoch ->
        if lease_live?(epoch) do
          {:busy, run_id, epoch_id}
        else
          case close_out_epoch(epoch_id, "stale_worker_lease_expired") do
            {:reaped, _previous_state} -> :ok
            {:already_terminal, _state} -> :ok
            other -> {:stale_reap_failed, other}
          end
        end
    end
  end

  defp find_in_flight do
    Epoch
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(
      state in [:expected, :running] and run.state == :running and
        run.execution_policy == ^:wave_loop_step
    )
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  defp lease_live?(%Epoch{lease_token: token, lease_expires_at: expires_at}) do
    not is_nil(token) and not is_nil(expires_at) and
      DateTime.compare(expires_at, DateTime.utc_now()) == :gt
  end

  # The Engine's settlement semantics, loop-scoped: only an epoch with no
  # live lease and no terminal state is reaped, and the reap is receipted.
  defp close_out_epoch(epoch_id, reap_reason) do
    epoch = Ash.get!(Epoch, epoch_id, action: :read_unscoped, authorize?: false)

    cond do
      epoch.state not in [:expected, :running] ->
        {:already_terminal, epoch.state}

      lease_live?(epoch) ->
        :handed_off

      true ->
        case Ash.update(
               Ash.Changeset.for_update(epoch, :mark_failed, %{}),
               actor: Xaas.SystemAuthority.new(:ultracode_reactor)
             ) do
          {:ok, _failed} ->
            {:ok, _} =
              seal_receipt(epoch, %{
                "reaped_by" => "xaas-wave-loop",
                "reap_reason" => reap_reason
              })

            {:reaped, epoch.state}

          {:error, _error} ->
            # The row moved concurrently (closed/refused/missed by someone
            # else between the read and this write). Report what is there.
            observed = Ash.get!(Epoch, epoch_id, action: :read_unscoped, authorize?: false).state
            {:settle_race, observed}
        end
    end
  end

  defp seal_receipt(epoch, evidence) do
    Receipt
    |> Ash.Changeset.for_create(
      :seal,
      %{
        epoch_id: epoch.id,
        subject: epoch.exact_subject,
        outcome: :refused,
        evidence: evidence,
        sealed_at: DateTime.utc_now()
      },
      authorize?: false
    )
    |> Ash.create()
  end

  # ------------------------------------------------------------------
  # Execution: the Run/Epoch factory + the dispatch boundary
  # ------------------------------------------------------------------

  defp create_loop_run(goal) do
    Run
    |> Ash.Changeset.for_create(
      :create,
      %{
        goal: goal,
        provider: @provider,
        max_cycles: 1,
        execution_policy: :wave_loop_step,
        epoch_timeout_seconds: @epoch_timeout_seconds
      },
      authorize?: false
    )
    |> Ash.create()
  end

  defp start_run(run, subject) do
    run
    |> Ash.Changeset.for_update(:start, %{exact_subject: subject}, authorize?: false)
    |> Ash.update()
  end

  defp activate_first_epoch(run) do
    with {:ok, epoch} <-
           Epoch
           |> Ash.Query.for_read(:read_unscoped)
           |> Ash.Query.filter(run_id == ^run.id and state == :expected)
           |> Ash.Query.sort(cycle: :desc)
           |> Ash.read_one(authorize?: false) do
      case epoch do
        nil ->
          {:error, {:no_first_epoch, run.id}}

        %Epoch{} ->
          epoch
          |> Ash.Changeset.for_update(:start, %{}, authorize?: false)
          |> Ash.update()
      end
    end
  end

  defp dispatch(epoch, opts) do
    dispatcher =
      Keyword.get(opts, :dispatcher) ||
        Application.get_env(:xaas, :ultracode_wave_loop_dispatcher, {Dispatch, :dispatch})

    dispatch_opts =
      opts
      |> Keyword.get(:dispatch_opts, [])
      |> Keyword.put_new(:timeout_seconds, loop_timeout())
      |> Keyword.put_new(:provider, @provider)

    case dispatcher do
      {mod, fun} when is_atom(mod) and is_atom(fun) ->
        apply(mod, fun, [epoch.id, dispatch_opts])

      fun when is_function(fun, 2) ->
        fun.(epoch.id, dispatch_opts)

      other ->
        {:error, {:bad_dispatcher, inspect(other)}}
    end
  end

  # ------------------------------------------------------------------
  # Settlement: STATE + telemetry from the receipt, never the exit alone
  # ------------------------------------------------------------------

  defp settle(step, epoch_id, result, state_path, telemetry_path, tick_no) do
    case result do
      {:ok, %{status: :ok, epoch_state: :completed} = res} ->
        apply_success(step, epoch_id, res, state_path, telemetry_path, tick_no)

      {:ok, %{status: :ok} = res} ->
        non_terminal(step, epoch_id, res, "worker_ended_without_closing", :worker_unclosed, %{
          state_path: state_path,
          telemetry_path: telemetry_path,
          tick_no: tick_no
        })

      {:ok, %{status: :rate_limited} = res} ->
        non_terminal(step, epoch_id, res, "worker_rate_limited", :rate_limited, %{
          state_path: state_path,
          telemetry_path: telemetry_path,
          tick_no: tick_no
        })

      {:ok, %{status: :timeout} = res} ->
        non_terminal(step, epoch_id, res, "worker_timeout", :timeout, %{
          state_path: state_path,
          telemetry_path: telemetry_path,
          tick_no: tick_no
        })

      {:ok, %{status: :failed} = res} ->
        non_terminal(
          step,
          epoch_id,
          res,
          "worker_exit_#{res.exit_code}",
          {:worker_exit, res.exit_code},
          %{
            state_path: state_path,
            telemetry_path: telemetry_path,
            tick_no: tick_no
          }
        )

      {:error, reason} ->
        # The dispatch boundary refused before anything ran (CLI/node/log).
        # Nothing proven, nothing reaped: the row stays pending for the
        # next tick; the telemetry carries the typed refusal.
        finish(
          tick_no,
          step.id,
          :dispatch_refused,
          %{reason: inspect(reason)},
          telemetry_path
        )
    end
  end

  defp non_terminal(
         step,
         epoch_id,
         res,
         reap_reason,
         outcome,
         %{state_path: state_path, telemetry_path: telemetry_path, tick_no: tick_no}
       ) do
    case close_out_epoch(epoch_id, reap_reason) do
      {:reaped, _previous_state} ->
        line = "wave-loop tick #{tick_no}: outcome=#{inspect(outcome)} " <> evidence_tail(res)

        apply_blocked(step, outcome, line, state_path, telemetry_path, tick_no)

      {:already_terminal, :completed} ->
        # Closed in the race window between Dispatch's state read and the
        # settle re-read: the completed-epoch verdict wins.
        apply_success(step, epoch_id, res, state_path, telemetry_path, tick_no)

      {:already_terminal, state} ->
        line = "wave-loop tick #{tick_no}: epoch closed as #{state} — " <> evidence_tail(res)
        apply_blocked(step, {:closed_as, state}, line, state_path, telemetry_path, tick_no)

      :handed_off ->
        # A live lease survived the worker's exit: the lease owner finishes
        # the epoch; the next tick's busy/stale path owns it. Row untouched.
        line =
          "wave-loop tick #{tick_no}: live lease survived, handed off — " <> evidence_tail(res)

        apply_stateless(tick_no, step.id, :handed_off, line, telemetry_path)

      {:settle_race, observed} ->
        apply_stateless(
          tick_no,
          step.id,
          :settle_race,
          "wave-loop tick #{tick_no}: settle race, epoch now #{observed}",
          telemetry_path
        )
    end
  end

  defp apply_success(step, epoch_id, res, state_path, telemetry_path, tick_no) do
    line =
      "wave-loop tick #{tick_no}: receipt epoch #{short(epoch_id)} " <> evidence_tail(res)

    with {:ok, raw} <- read_state(state_path),
         {:ok, raw} <- State.set_row(raw, step.id, "DONE", line),
         {:ok, raw} <- State.remove_from_remaining(raw, step.id),
         :ok <- atomic_write(state_path, raw),
         {:ok, fresh} <- State.parse(raw) do
      if State.complete?(fresh) do
        stamped = State.append_complete_marker(raw, "#{iso_now()} (#{short(epoch_id)})")

        case atomic_write(state_path, stamped) do
          :ok ->
            finish(
              tick_no,
              step.id,
              :worker_completed,
              Map.merge(receipt_detail(res), %{complete: true}),
              telemetry_path
            )

          {:error, reason} ->
            finish(
              tick_no,
              step.id,
              :state_update_refused,
              %{reason: format_any(reason)},
              telemetry_path
            )
        end
      else
        finish(tick_no, step.id, :worker_completed, receipt_detail(res), telemetry_path)
      end
    else
      {:error, reason} ->
        finish(
          tick_no,
          step.id,
          :state_update_refused,
          %{reason: format_any(reason)},
          telemetry_path
        )
    end
  end

  defp apply_blocked(step, outcome, line, state_path, telemetry_path, tick_no) do
    with {:ok, raw} <- read_state(state_path),
         {:ok, raw} <-
           State.set_row(
             raw,
             step.id,
             "BLOCKED (wave-loop tick #{tick_no}: #{inspect(outcome)})",
             line
           ),
         :ok <- atomic_write(state_path, raw) do
      finish(
        tick_no,
        step.id,
        :blocked,
        %{outcome: format_any(outcome), evidence: line},
        telemetry_path
      )
    else
      {:error, reason} ->
        finish(
          tick_no,
          step.id,
          :state_update_refused,
          %{reason: format_any(reason)},
          telemetry_path
        )
    end
  end

  # Outcomes that must NOT touch the STATE row (a lease owner is finishing
  # the work, or a settle race needs the next tick to resolve it).
  defp apply_stateless(tick_no, step_id, outcome, line, telemetry_path) do
    finish(tick_no, step_id, outcome, %{evidence: line}, telemetry_path)
  end

  defp evidence_tail(%{exit_code: exit_code, log_path: log_path}) do
    "exit=#{inspect(exit_code)} log=#{log_path}"
  end

  defp evidence_tail(_), do: ""

  defp receipt_detail(%{epoch_id: epoch_id, status: status, receipts: receipts}) do
    %{
      epoch_id: epoch_id,
      dispatch_status: status,
      receipts: receipts
    }
  end

  defp receipt_detail(_), do: %{}

  defp short(id), do: String.slice(id, 0, 8)

  # ------------------------------------------------------------------
  # STATE I/O + telemetry
  # ------------------------------------------------------------------

  defp read_state(path) do
    case File.read(path) do
      {:ok, raw} -> {:ok, raw}
      {:error, reason} -> {:error, {:state_read, reason}}
    end
  end

  # Atomic by construction: temp file + rename in the same directory, so a
  # reader (worker or operator) never observes a partial write.
  defp atomic_write(path, content) do
    dir = Path.dirname(path)
    tmp = Path.join(dir, ".wave-loop-#{System.unique_integer([:positive])}.tmp")

    with :ok <- File.mkdir_p(dir),
         :ok <- File.write(tmp, content),
         :ok <- File.rename(tmp, path) do
      :ok
    else
      {:error, reason} ->
        _ = File.rm(tmp)
        {:error, {:state_write, path, inspect(reason)}}
    end
  end

  # The tick number is the loop's own ledger position: one plus the number
  # of this kind's lines already in the telemetry file.
  defp next_tick_number(path) do
    case File.read(path) do
      {:ok, bin} ->
        bin
        |> String.split("\n", trim: true)
        |> Enum.count(&String.contains?(&1, @kind_token))
        |> Kernel.+(1)

      _ ->
        1
    end
  end

  defp finish(tick_no, step, outcome, detail, telemetry_path) do
    entry = %{
      "ts" => iso_now(),
      "kind" => @kind,
      "tick" => tick_no,
      "step" => step,
      "outcome" => outcome_name(outcome),
      "receipt" => stringify(detail)
    }

    _ =
      try do
        line = Jason.encode!(entry)
        _ = File.mkdir_p(Path.dirname(telemetry_path))
        File.write(telemetry_path, line <> "\n", [:append])
      rescue
        _ -> :ok
      end

    report = %{
      outcome: outcome,
      tick: tick_no,
      step: step,
      receipt: detail
    }

    Logger.info("[ultracode-wave-loop] tick=#{tick_no} step=#{inspect(step)} outcome=#{outcome}")

    {:ok, report}
  end

  defp stringify(detail) when is_map(detail) do
    Map.new(detail, fn {k, v} -> {to_string(k), stringify_value(v)} end)
  end

  defp stringify(detail), do: detail

  defp stringify_value(v) when is_map(v), do: stringify(v)
  defp stringify_value(v) when is_atom(v), do: to_string(v)
  defp stringify_value(v) when is_tuple(v) or is_list(v), do: format_any(v)
  defp stringify_value(v), do: v

  # Outcome names flatten into the telemetry line: atoms verbatim, tagged
  # tuples as "tag:detail" (never to_string/1 on a tuple -- that raises).
  defp outcome_name({tag, detail}) when is_atom(tag), do: "#{tag}:#{format_any(detail)}"
  defp outcome_name(atom) when is_atom(atom), do: Atom.to_string(atom)

  # ------------------------------------------------------------------
  # Options / misc
  # ------------------------------------------------------------------

  defp opt(opts, key, env_key, default) do
    Keyword.get(opts, key) || Application.get_env(:xaas, env_key, default)
  end

  defp loop_timeout do
    Application.get_env(:xaas, :ultracode_wave_loop_timeout_seconds, @default_timeout_seconds)
  end

  defp iso_now, do: DateTime.utc_now() |> DateTime.to_iso8601()

  defp format_refusal({:error, {:malformed_state, detail}}),
    do: "malformed STATE: #{format_any(detail)}"

  defp format_any(term), do: String.slice(inspect(term, limit: 20), 0, 500)
end
