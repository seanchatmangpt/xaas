defmodule Xaas.Ultracode.EpochReactor do
  @moduledoc """
  Real multi-step Reactor DAG for one `Epoch`'s engineering-workflow cycle.

  `Observe -> Admit -> Plan -> Construct -> Verify -> Receipt`, matching this
  repo's HDDL/DfCM doctrine (`守/柵/算/除/偽/延/実` -- Preserve/Fence/Calculus/
  Exclusions/Falsifier/Extension/Operationalize) mapped onto concrete Reactor
  steps rather than a sequential function. `Chicago`/`Learn` are folded into
  `Verify`/`Receipt` respectively (see those steps' docs) rather than given
  their own steps -- there is no distinct in-repo machinery yet for a
  standalone Chicago-style-verification-runner step or a learning/standing
  step beyond what `Verify` and `Receipt` already do, so splitting them out
  would be decoration, not real composition.

  Each step below is a real `step/2` block wired to the *previous step's
  result* via `result(:previous_step)` -- not a bag of independent inputs
  computed up front. `Verify` and `Receipt` both also read `result(:observe)`
  directly (the original `Epoch`) because they need the pre-mutation record
  alongside the constructed outcome, which is exactly what Reactor's DAG
  wiring (a step depending on more than one upstream result) exists for.

  This Reactor is invoked by `Xaas.Ultracode.Reactor` once per `Run`'s
  active (`:running`) `Epoch` -- see that module's `:run_active_epochs`
  step, which is what the AshOban `:tick` scheduled action on
  `Xaas.Ultracode.Run` actually calls.
  """

  use Reactor

  input(:epoch_id)

  # 守/柵 Observe -- load the real current-state Epoch row. No mutation, no
  # inference: this is the ground truth the rest of the DAG reasons over.
  step :observe do
    argument(:epoch_id, input(:epoch_id))

    run(fn %{epoch_id: epoch_id}, _context ->
      case Ash.get(Xaas.Ultracode.Epoch, epoch_id, load: [:run]) do
        {:ok, epoch} -> {:ok, epoch}
        {:error, error} -> {:error, {:observe_failed, error}}
      end
    end)
  end

  # 算/除 Admit -- refuse (not silently skip) any Epoch that is not in an
  # admissible state for this cycle. This is the fence: only an `:expected`
  # or `:running` Epoch may proceed past this point. `Epoch` has no
  # authority-ceiling field and this step performs no authority-ceiling
  # check -- `Xaas.Ultracode`'s own moduledoc records that `AuthorityCeiling`
  # is deliberately not modeled for this Run/Epoch/Receipt domain (a
  # same-named check exists elsewhere, on `Xaas.Actuation.FrontierEvidence`'s
  # evidence fragments, not here). If an authority-ceiling admission check
  # is wanted for Epoch, it needs a real field + real check added, not
  # implied by this comment.
  step :admit do
    argument(:epoch, result(:observe))

    run(fn %{epoch: epoch}, _context ->
      if epoch.state in [:expected, :running] do
        {:ok, %{epoch: epoch, admitted?: true}}
      else
        {:error, {:refused, :epoch_not_admissible, epoch.state}}
      end
    end)
  end

  # 延 Plan -- decide the real next action for this Epoch: transition an
  # `:expected` Epoch to `:running` (the `:start` action, which already
  # enforces `AtMostOneActiveEpoch(run)`), or, if already `:running`,
  # proceed straight to completion this cycle. The plan is real data
  # (an atom + the epoch), not a placeholder -- `Construct` branches on it.
  step :plan do
    argument(:admission, result(:admit))

    run(fn %{admission: %{epoch: epoch}}, _context ->
      next_action = if epoch.state == :expected, do: :start, else: :complete
      {:ok, %{epoch: epoch, next_action: next_action}}
    end)
  end

  # 実 Construct -- actually perform the planned Ash transition. This is the
  # one step in the DAG with a real side effect (a DB-persisted Epoch state
  # change via the resource's own admitted update actions), matching this
  # repo's Reactor-as-DO-kernel convention.
  step :construct do
    argument(:plan, result(:plan))

    run(fn %{plan: %{epoch: epoch, next_action: next_action}}, _context ->
      changeset = Ash.Changeset.for_update(epoch, next_action, %{})

      case Ash.update(changeset) do
        {:ok, updated_epoch} -> {:ok, %{epoch: updated_epoch, action_taken: next_action}}
        {:error, error} -> {:error, {:construct_failed, next_action, error}}
      end
    end)
  end

  # 偽 Verify -- Chicago-style, state-based check folded in here rather than
  # given a separate step: re-read the real persisted row (not the in-memory
  # struct `Construct` returned) and assert its `state` actually matches what
  # was planned. This is the falsifier -- if the DB disagrees with what
  # `Construct` believes it did, this step catches it and the outcome is
  # `:build_broken`, not `:alive`.
  step :verify do
    argument(:constructed, result(:construct))
    argument(:original, result(:observe))

    run(fn %{
             constructed: %{epoch: constructed_epoch, action_taken: action_taken},
             original: original
           },
           _context ->
      expected_state = if action_taken == :start, do: :running, else: :completed

      case Ash.get(Xaas.Ultracode.Epoch, constructed_epoch.id) do
        {:ok, %{state: ^expected_state} = reloaded} ->
          {:ok,
           %{
             outcome: :alive,
             epoch: reloaded,
             original_state: original.state,
             action_taken: action_taken,
             evidence: %{
               "expected_state" => Atom.to_string(expected_state),
               "observed_state" => Atom.to_string(reloaded.state)
             }
           }}

        {:ok, mismatched} ->
          {:ok,
           %{
             outcome: :build_broken,
             epoch: mismatched,
             original_state: original.state,
             action_taken: action_taken,
             evidence: %{
               "expected_state" => Atom.to_string(expected_state),
               "observed_state" => Atom.to_string(mismatched.state)
             }
           }}

        {:error, error} ->
          {:error, {:verify_failed, error}}
      end
    end)
  end

  # 実 Receipt -- seal the real `Xaas.Ultracode.Receipt` row evidencing this
  # cycle's outcome. Standing/learning ("Learn") is folded in here rather
  # than a separate step: the sealed receipt IS this repo's standing record
  # (per `Xaas.Ultracode.Receipt`'s `outcome`/`evidence` fields matching the
  # CLAUDE.md ALIVE/PARTIAL_ALIVE/BLOCKED/UNSUPPORTED/REFUSED vocabulary) --
  # there is no separate learning/standing resource to write to, so a
  # dedicated `Learn` step would just be this same `Ash.create!` call
  # relabeled.
  step :receipt do
    argument(:verification, result(:verify))
    argument(:epoch, result(:observe))

    run(fn %{verification: verification, epoch: original_epoch}, _context ->
      Xaas.Ultracode.Receipt
      |> Ash.Changeset.for_create(
        :seal,
        %{
          epoch_id: original_epoch.id,
          subject: original_epoch.exact_subject,
          outcome: verification.outcome,
          evidence: verification.evidence,
          sealed_at: DateTime.utc_now()
        }
      )
      |> Ash.create()
      |> case do
        {:ok, receipt} ->
          {:ok,
           %{
             epoch_id: original_epoch.id,
             action_taken: verification.action_taken,
             outcome: verification.outcome,
             receipt_id: receipt.id
           }}

        {:error, error} ->
          {:error, {:receipt_seal_failed, error}}
      end
    end)
  end

  return(:receipt)
end
