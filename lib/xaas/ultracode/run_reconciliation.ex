defmodule Xaas.Ultracode.RunReconciliation do
  @moduledoc """
  One-shot admitted sweep that closes the wave-2 audit finding: item-level
  `ultracode_runs` rows that NEVER transitioned -- 1043 rows sitting
  `pending` (2026-09-21 dev DB) while their epochs and receipts carry the
  real terminality. The live edges now exist (`Xaas.Ultracode.ItemRuns`,
  called from the Autonomic item lifecycle); this module reconciles the
  historical rows against the SAME classify law, so the DB stops
  misstating reality and tooling that reads Run state directly is right.

  ## The sweep law

  A stuck run is a candidate iff ALL of:

    * `state` in `[:pending, :running]` (non-terminal: the finding);
    * NOT a standing-wave session (`wave_session: false` -- session Runs
      belong to `DurationBudget`'s own drain/complete law);
    * it HAS at least one epoch (no evidence, no terminality: an
      epoch-less row is never guessed closed -- skipped `:no_epochs`);
    * EVERY epoch is terminal (`:completed`/`:failed`/`:missed`) -- a run
      with live work under it is left alone (skipped
      `:epoch_not_terminal`), never closed over in-flight work.

  Each candidate is then judged by `Xaas.Ultracode.ItemRuns.classify_run/1`
  -- the same court-grounded mapping the live edge uses
  (`Autonomic.judge_receipt/1`: court pass + `head_verified` + honest
  standing) -- and closed through `ItemRuns.close!/3`, the guarded,
  admitted transition (`:transition_state` + `RunTransitionAllowed` +
  `SetTerminalAt`, `:ultracode_reactor` system authority, never
  `authorize?: false`; a `:pending` row lawfully walks `:pending ->
  :running -> terminal`). Historical exhaustion is NOT recoverable from
  the DB (attempts span separate run rows; the item ledger is a file), so
  the sweep classifies purely from epoch/receipt evidence and reports
  that honestly; the live `exhausted: true -> :abandoned` edge remains
  the item-level law going forward.

  Idempotent by construction: a second sweep finds the same rows already
  terminal -- `close!/3` guards them (`:already_terminal`) and the census
  reports zero transitions.
  """

  alias Xaas.Ultracode.{ItemRuns, Run}

  require Ash.Query

  @nonterminal_run_states [:pending, :running]

  @sample_limit 10

  @doc """
  Runs the sweep. `:dry_run` classifies and censuses without writing.

  Returns a report map: `before`/`after` state censuses (GROUP BY state
  over ALL `ultracode_runs`; identical when dry), `considered` (stuck
  non-session rows scanned), `candidates` (evidence-terminal rows
  judged), `transitions`/`would_transition`, `already_terminal`,
  `errors` (bounded sample), and `skipped` grouped by reason
  (`no_epochs`, `epoch_not_terminal`, `stuck_classification`) with a
  bounded sample per reason.
  """
  @spec sweep(keyword()) :: map()
  def sweep(opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run, false)

    before_census = state_census()
    runs = stuck_runs()
    {candidates, skipped} = partition(runs)

    results =
      if dry_run? do
        Enum.map(candidates, fn {run, {:terminal, state, standing}} ->
          {:ok, {:would_transition, run.id, run.state, state, standing}}
        end)
      else
        Enum.map(candidates, fn {run, {:terminal, state, standing}} ->
          ItemRuns.close!(run.id, state, standing)
        end)
      end

    %{
      dry_run: dry_run?,
      before: before_census,
      after: if(dry_run?, do: before_census, else: state_census()),
      considered: length(runs),
      candidates: length(candidates),
      transitions: Enum.count(results, &match?({:ok, {:transitioned, _}}, &1)),
      would_transition:
        Enum.count(results, fn
          {:ok, {:would_transition, _id, _from, _to, _standing}} -> true
          _other -> false
        end),
      already_terminal: Enum.count(results, &(&1 == {:ok, :already_terminal})),
      errors: Enum.filter(results, &match?({:error, _}, &1)) |> Enum.take(@sample_limit),
      skipped: skip_census(skipped)
    }
  end

  @doc """
  The GROUP BY state census over every `ultracode_runs` row -- the
  before/after numbers the reconcile receipt prints.
  """
  @spec state_census() :: %{atom() => non_neg_integer()}
  def state_census do
    Run
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.select([:state])
    |> Ash.read!()
    |> Enum.frequencies_by(& &1.state)
  end

  # Stuck rows: non-terminal, non-session. Reads are open by policy
  # (bypass action_type(:read)); every MUTATION below goes through the
  # admitted `:transition_state` action with the system authority.
  defp stuck_runs do
    Run
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(state in ^@nonterminal_run_states and wave_session == false)
    |> Ash.read!()
  end

  # Partition into evidence-terminal candidates and honestly-reported
  # skips. Epochs load through the relationship's own `:read_unscoped`
  # action; receipts through `ItemRuns.epoch_receipts!/1`.
  defp partition(runs) do
    Enum.reduce(runs, {[], []}, fn run, {candidates, skipped} ->
      case judge_run(run) do
        {:terminal, _state, _standing} = verdict ->
          {[{run, verdict} | candidates], skipped}

        {:skip, reason} ->
          {candidates, [{run.id, reason} | skipped]}

        {:stuck, reason} ->
          {candidates, [{run.id, {:stuck_classification, reason}} | skipped]}
      end
    end)
    |> then(fn {candidates, skipped} ->
      {Enum.reverse(candidates), Enum.reverse(skipped)}
    end)
  end

  defp judge_run(run) do
    epochs = Ash.load!(run, :epochs).epochs

    cond do
      epochs == [] ->
        {:skip, {:no_epochs, nil}}

      reason = skip_reason(epochs) ->
        {:skip, reason}

      true ->
        ItemRuns.classify_run(Enum.map(epochs, &{&1, ItemRuns.epoch_receipts!(&1.id)}))
    end
  end

  # nil when every epoch is terminal; the skip reason tuple otherwise.
  defp skip_reason(epochs) do
    Enum.find_value(epochs, fn epoch ->
      if epoch.state in ItemRuns.epoch_terminal_states() do
        nil
      else
        {:epoch_not_terminal, epoch.id, epoch.state}
      end
    end)
  end

  defp skip_census(skipped) do
    skipped
    |> Enum.group_by(fn {_run_id, reason} -> elem(reason, 0) end)
    |> Enum.into(%{}, fn {reason, entries} ->
      {reason, %{count: length(entries), sample: Enum.take(entries, @sample_limit)}}
    end)
  end
end
