defmodule Xaas.Ultracode.ItemRuns do
  @moduledoc """
  The item-attempt Run lifecycle: the real state-machine transitions for
  the per-work-item, per-attempt `ultracode_runs` rows the Autonomic loop
  creates (`Autonomic.create_run_and_epoch/5`).

  ## The finding this closes

  Item-level Run rows were created `:pending` and NEVER transitioned: a
  real DB cross-check (wave-2 audit, 2026-09-21) found 1043 rows sitting
  `pending` while their epochs and receipts carried the actual
  terminality — the DB misstated reality, and any tooling reading Run
  state directly was wrong (the audit task had to be written around the
  gap). Root cause: the Autonomic loop wrote terminality into its own
  ndjson ledger (`item_done` / `item_blocked`) and into Epoch/Receipt
  rows, but never back onto the Run row.

  ## The mapping law (one law, two consumers)

  `classify/2` derives the terminal Run state from the SAME evidence the
  Autonomic judge already accepts (`Autonomic.judge_receipt/1` -- the
  fabric's court verdict, never the worker's claim), so the live edge
  (below) and the historical sweep
  (`Xaas.Ultracode.RunReconciliation`) cannot drift:

    * epoch `:completed` + closing `head_verified` receipt + judge
      `:accept` (court pass over an honest `:alive`/`:partial_alive`
      standing) -> Run `:completed`, standing `:admitted` -- exactly the
      `item_done` outcome;
    * epoch `:completed` + NO closing receipt -> Run `:failed`, standing
      `:blocked` (court infrastructure: the epoch closed without a
      closing receipt -- `Autonomic.judge/2`'s own repair law);
    * epoch `:completed` + court FAIL (falsified evidence) -> Run
      `:failed`, standing `:refused`;
    * epoch `:completed` + court PASS but the judge still repairs (strict
      seam) -> Run `:failed`, standing `:blocked` (the head was verified;
      the item simply was not promoted -- "refused" would be a lie);
    * epoch `:failed` -> Run `:failed`, standing `:refused` (worker
      refusal / falsified attempt -- the same standing `NextEpoch`'s
      stale recovery uses for a `:failed` last epoch);
    * epoch `:missed` -> Run `:abandoned`, standing `:blocked` (the work
      never ran; the same standing `NextEpoch` uses for a `:missed` last
      epoch);
    * epoch still `:expected`/`:running` -> `{:stuck, ...}` -- the run is
      left untouched (no terminality is invented over live work);
    * item exhaustion (`item_blocked`: every attempt burned) -> Run
      `:abandoned`, standing `:blocked` -- the state machine's existing
      lawful edge for abandoned work (`{:running, :abandoned}`, the same
      edge and standing `Run.:stop` uses for work stopped mid-flight).
      Applies to the FINAL attempt's run; earlier attempts' runs carry
      their own per-attempt verdict.

  ## The lawful walk (`close!/3`)

  All transitions go through the admitted `:transition_state` action --
  `RunTransitionAllowed`'s real allow-list, `SetTerminalAt` writing
  `terminal_at`, and `Xaas.Checks.SystemActor` authorization with the
  `:ultracode_reactor` service (the same actor every other Run kernel
  mutation carries; never `authorize?: false`). Two admitted edges are
  composed: a historical `:pending` row walks `:pending -> :running`
  (TRUE: the attempt ran -- its epoch is terminal below it) then
  `:running -> terminal`; a live row opened by `open!/1` closes
  directly. Every close is GUARDED (`never fires twice`): the fresh row
  state is read first and a terminal row short-circuits to
  `{:ok, :already_terminal}`; a lost race against a concurrent closer is
  absorbed the same way instead of raising.
  """

  alias Xaas.Ultracode.{Autonomic, Epoch, Receipt, Run}

  @epoch_terminal_states [:completed, :failed, :missed]
  @run_terminal_states [:completed, :failed, :abandoned]

  # XAAS-2601 exact-subject map: {Run, :transition_state, :ultracode_reactor}.
  # The same admitted kernel authority `NextEpoch`/`MissedEpochs` carry.
  defp system_actor, do: Xaas.SystemAuthority.new(:ultracode_reactor)

  @doc """
  Marks an item-attempt Run `:running` (`:pending -> :running`, the
  admitted edge) -- called by the Autonomic loop the moment the
  attempt's Epoch exists in `:running` state, so an in-flight attempt
  reads `:running` instead of the misstating `:pending`. Guarded and
  idempotent: `:running`/terminal rows are left alone.
  """
  @spec open!(Run.t() | String.t()) ::
          {:ok, {:opened, :running} | :already_running | :already_terminal}
          | {:error, :run_not_found | term()}
  def open!(run_or_id) do
    with {:ok, run} <- fresh_run(run_or_id) do
      case run.state do
        :pending -> transition(run, :running, run.standing)
        :running -> {:ok, :already_running}
        terminal when terminal in @run_terminal_states -> {:ok, :already_terminal}
      end
    end
  end

  @doc """
  Closes an item-attempt Run into an explicit terminal state with an
  explicit standing. The GUARDED, idempotent transition: a row already
  terminal never fires twice (`{:ok, :already_terminal}`); a `:pending`
  row (every historical stuck row, and any row whose `open!/1` was
  missed) is lawfully walked through `:running` first -- both edges
  admitted, both real (the attempt ran, then it ended).
  """
  @spec close!(Run.t() | String.t(), :completed | :failed | :abandoned, atom()) ::
          {:ok, {:transitioned, atom()} | :already_terminal}
          | {:error,
             :run_not_found
             | :invalid_terminal_state
             | :transition_refused
             | {:walk_failed, term()}}
  def close!(run_or_id, terminal_state, standing)

  def close!(run_or_id, terminal_state, standing)
      when terminal_state in @run_terminal_states and is_atom(standing) do
    with {:ok, run} <- fresh_run(run_or_id) do
      case run.state do
        terminal when terminal in @run_terminal_states ->
          {:ok, :already_terminal}

        :running ->
          transition(run, terminal_state, standing)

        :pending ->
          # The lawful walk: the attempt DID run (evidence below it is
          # terminal), so `:pending -> :running` is a true statement,
          # then `:running -> terminal` closes it. Both edges are
          # admitted by `RunTransitionAllowed`; neither is `authorize?:
          # false`.
          with {:ok, _} <- open!(run.id) do
            fresh_run(run.id) |> already_terminal_or(terminal_state, standing)
          end
      end
    end
  end

  def close!(_run_or_id, _terminal_state, _standing), do: {:error, :invalid_terminal_state}

  @doc """
  The live Autonomic edge for one attempt's Run: re-reads the attempt's
  epoch FRESH (the worker may have closed it after the in-memory struct
  was taken), classifies from the sealed receipts, and closes the run.

  `exhausted: true` (the caller's attempt just burned the last one --
  the very next recursion is `item_blocked`) closes the run
  `:abandoned`/`:blocked` regardless of the epoch verdict: the ITEM gave
  up on this attempt's work, which is exactly what `:abandoned` means.
  Otherwise the mapping law of `classify/2` applies. A `{:stuck, ...}`
  verdict leaves the run open (`{:ok, {:left_open, reason}}`) -- no
  terminality is invented over an epoch that has not ended.
  """
  @spec close_attempt!(Run.t() | String.t(), Epoch.t() | String.t(), keyword()) ::
          {:ok,
           {:transitioned, atom()} | {:walked, atom()} | :already_terminal | {:left_open, term()}}
          | {:error, term()}
  def close_attempt!(run_or_id, epoch_or_id, opts \\ []) do
    exhausted? = Keyword.get(opts, :exhausted, false)

    with {:ok, epoch} <- fresh_epoch(epoch_or_id),
         receipts = epoch_receipts!(epoch.id) do
      verdict =
        if exhausted? do
          {:terminal, :abandoned, :blocked}
        else
          classify(epoch, receipts)
        end

      case verdict do
        {:terminal, state, standing} -> close!(run_or_id, state, standing)
        {:stuck, reason} -> {:ok, {:left_open, reason}}
      end
    end
  end

  @doc """
  The mapping law: one terminal epoch + its receipts -> the Run's
  terminal `{state, standing}`. See the moduledoc. `{:stuck, reason}`
  for an epoch that has not ended -- never a guessed terminality.
  """
  @spec classify(Epoch.t(), [Receipt.t()]) ::
          {:terminal, :completed | :failed | :abandoned, :admitted | :refused | :blocked}
          | {:stuck, term()}
  def classify(%Epoch{} = epoch, receipts) do
    case epoch.state do
      :completed -> classify_completed_epoch(epoch, receipts)
      :failed -> {:terminal, :failed, :refused}
      :missed -> {:terminal, :abandoned, :blocked}
      other -> {:stuck, {:epoch_not_terminal, epoch.id, other}}
    end
  end

  # `:completed` epoch: terminality rides the SAME judge the Autonomic
  # loop promotes with (`Autonomic.judge_receipt/1` -- court pass +
  # head_verified + honest standing), so live and reconciled rows are
  # decided by one predicate, never two.
  defp classify_completed_epoch(_epoch, receipts) do
    closing = Enum.find(receipts, &Map.has_key?(&1.evidence, "head_verified"))

    case closing do
      nil ->
        # `Autonomic.judge/2`'s own law: completed without a closing
        # receipt is an infrastructure failure, not a done item.
        {:terminal, :failed, :blocked}

      receipt ->
        case Autonomic.judge_receipt(receipt) do
          :accept ->
            {:terminal, :completed, :admitted}

          {:repair, _reason} ->
            fv = receipt.evidence["fabric_verifier"]

            if is_map(fv) and fv["status"] == "pass" do
              # The court PASSED the exact head but the item was not
              # promoted (strict-seam repair): verified work, unpromoted
              # item -- `:blocked`, not `:refused`.
              {:terminal, :failed, :blocked}
            else
              # Court fail / no verdict at all: falsified evidence ->
              # `:refused`; unproducible verdict -> `:blocked`.
              {:terminal, :failed, :refused}
            end
        end
    end
  end

  @doc """
  Combines per-epoch verdicts into one Run verdict (an item-attempt run
  is one-epoch by construction -- `max_cycles: 1` -- but a run with a
  replacement epoch must classify honestly): any done epoch completes
  the run; otherwise the strongest failure verdict wins; only all-`missed`
  lands on `:abandoned`; any non-terminal epoch leaves the run `stuck`.
  """
  @spec classify_run([{Epoch.t(), [Receipt.t()]}]) ::
          {:terminal, :completed | :failed | :abandoned, :admitted | :refused | :blocked}
          | {:stuck, term()}
  def classify_run([]), do: {:stuck, :no_epochs}

  def classify_run(epoch_receipts) do
    verdicts = Enum.map(epoch_receipts, fn {epoch, receipts} -> classify(epoch, receipts) end)

    stuck = Enum.find(verdicts, &match?({:stuck, _}, &1))

    cond do
      stuck != nil ->
        stuck

      Enum.any?(verdicts, &match?({:terminal, :completed, _}, &1)) ->
        {:terminal, :completed, :admitted}

      Enum.any?(verdicts, &match?({:terminal, :failed, :refused}, &1)) ->
        {:terminal, :failed, :refused}

      Enum.any?(verdicts, &match?({:terminal, :failed, _}, &1)) ->
        {:terminal, :failed, :blocked}

      true ->
        {:terminal, :abandoned, :blocked}
    end
  end

  # ------------------------------------------------------------------
  # Internals
  # ------------------------------------------------------------------

  defp transition(run, state, standing) do
    case run
         |> Ash.Changeset.for_update(:transition_state, %{state: state, standing: standing})
         |> Ash.update(actor: system_actor()) do
      {:ok, updated} -> {:ok, {:transitioned, updated.state}}
      {:error, _error} -> {:error, :transition_refused}
    end
  end

  defp already_terminal_or({:ok, run}, terminal_state, standing) do
    case run.state do
      terminal when terminal in @run_terminal_states -> {:ok, :already_terminal}
      _ -> transition(run, terminal_state, standing)
    end
  end

  defp already_terminal_or({:error, reason}, _terminal_state, _standing),
    do: {:error, {:walk_failed, reason}}

  defp fresh_run(run_or_id)

  defp fresh_run(%Run{id: id}), do: fresh_run(id)

  defp fresh_run(id) when is_binary(id) do
    case Run |> Ash.get(id, action: :read_unscoped) do
      {:ok, run} -> {:ok, run}
      {:error, _not_found} -> {:error, :run_not_found}
    end
  end

  defp fresh_epoch(epoch_or_id)

  defp fresh_epoch(%Epoch{id: id}), do: fresh_epoch(id)

  defp fresh_epoch(id) when is_binary(id) do
    case Epoch |> Ash.get(id, action: :read_unscoped) do
      {:ok, epoch} -> {:ok, epoch}
      {:error, _not_found} -> {:error, :epoch_not_found}
    end
  end

  @doc false
  def epoch_receipts!(epoch_id) do
    Receipt
    |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch_id})
    |> Ash.read!()
  end

  @doc false
  def epoch_terminal_states, do: @epoch_terminal_states
end
