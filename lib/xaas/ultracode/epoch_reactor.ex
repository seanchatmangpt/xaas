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

  require Logger

  input(:epoch_id)

  # 守/柵 Observe -- load the real current-state Epoch row. No mutation, no
  # inference: this is the ground truth the rest of the DAG reasons over.
  step :observe do
    argument(:epoch_id, input(:epoch_id))

    run(fn %{epoch_id: epoch_id}, _context ->
      case Ash.get(Xaas.Ultracode.Epoch, epoch_id, action: :read_unscoped, load: [:run]) do
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
  #
  # Provider-pull edge: when the Run carries a `provider` (actuation lane),
  # a `:running` Epoch must NOT auto-complete -- its engineering work is
  # leased out to a provider worker and completes only through
  # `Xaas.Ultracode.Lease.close/3` on verified provider evidence. Until
  # then the cycle is `:await_provider`: a real no-op-with-receipt turn,
  # not a completion claim -- the receipt is a `:heartbeat` (the typed
  # non-standing tick class), never a standing claim. Legacy provider-less
  # Runs keep the original complete-next-cycle semantics unchanged (their
  # tick receipts are heartbeats too, for the same reason).
  step :plan do
    argument(:admission, result(:admit))

    run(fn %{admission: %{epoch: epoch}}, _context ->
      next_action =
        cond do
          epoch.state == :expected -> :start
          is_binary(epoch.run.provider) -> :await_provider
          true -> :complete
        end

      {:ok, %{epoch: epoch, next_action: next_action}}
    end)
  end

  # 実 Construct -- actually perform the planned Ash transition. This is the
  # one step in the DAG with a real side effect (a DB-persisted Epoch state
  # change via the resource's own admitted update actions), matching this
  # repo's Reactor-as-DO-kernel convention.
  #
  # ERRC raise: real `undo/3` closes a previously-open gap -- if a
  # downstream step (`:verify` or `:receipt`) errors after this step
  # already committed a real DB mutation, the Epoch was left permanently
  # transitioned with no receipt at all, violating this subsystem's own
  # `CompletedEpoch => Receipt` invariant. Reactor auto-invokes `undo`
  # for a succeeded step when a later step in the same run fails.
  step :construct do
    argument(:plan, result(:plan))

    run(fn %{plan: %{epoch: epoch, next_action: next_action}}, _context ->
      case next_action do
        :await_provider ->
          # The lease clock is the provider's to spend; this turn performs
          # no mutation and claims no completion -- the epoch stays
          # `:running` until Lease.close/3 lands verified evidence.
          {:ok, %{epoch: epoch, action_taken: :await_provider}}

        action ->
          changeset = Ash.Changeset.for_update(epoch, action, %{})

          case Ash.update(changeset, actor: Xaas.SystemAuthority.new(:ultracode_reactor)) do
            {:ok, updated_epoch} -> {:ok, %{epoch: updated_epoch, action_taken: action}}
            {:error, error} -> {:error, {:construct_failed, action, error}}
          end
      end
    end)

    undo(fn %{epoch: constructed_epoch, action_taken: action_taken}, _arguments, _context ->
      # A real, evidenced repair, not a force-revert that erases a real
      # attempt: when this step transitioned the Epoch to `:running`
      # (action_taken == :start) but a downstream step then failed, drive
      # it to the existing admitted `:mark_failed` action (an admissible
      # edge from `:running`) so the failed attempt is visible. When this
      # step transitioned the Epoch all the way to `:completed`
      # (action_taken == :complete), the transition genuinely succeeded
      # -- force-reverting it to `:failed` would misrepresent a real
      # success as a failure, and `:mark_failed`'s own precondition
      # validation only admits `[:expected, :running]` anyway (not
      # `:completed`) -- so state is left as-is; only the missing receipt
      # is repaired below.
      #
      # ERRC raise (concurrency falsifier): the `:start` compensation used
      # to apply `:mark_failed` straight to `constructed_epoch`, the
      # in-memory struct `:construct` returned -- a snapshot that can be
      # stale by the time Reactor actually invokes `undo` (a concurrent
      # `Xaas.Ultracode.Lease.close/4`/`refuse/3` on the same epoch, or a
      # second EpochReactor pass, can have already moved the real row on).
      # `EpochTransitionAllowed`'s `from:` check reads the CHANGESET's
      # `data` -- i.e. whatever struct is handed to
      # `Ash.Changeset.for_update/2` -- not a fresh read, so a stale
      # struct that still says `:running` would pass validation and
      # silently overwrite a real `:completed`/`:failed` row, corrupting
      # the very `CompletedEpoch => Receipt` invariant this undo exists to
      # protect. Fixed by re-fetching the real current row immediately
      # before compensating and refusing -- a typed, receipted refusal,
      # never a silent no-op and never a clobber -- when it has moved out
      # of the `:running` state `:construct` actually left it in.
      case action_taken do
        :await_provider ->
          undo_seal_receipt(constructed_epoch, :build_broken, %{
            "undo_reason" =>
              "a downstream EpochReactor step failed after :construct already committed",
            "action_taken" => Atom.to_string(action_taken)
          })

        :complete ->
          undo_seal_receipt(constructed_epoch, :build_broken, %{
            "undo_reason" =>
              "a downstream EpochReactor step failed after :construct already committed",
            "action_taken" => Atom.to_string(action_taken)
          })

        :start ->
          case Ash.get(Xaas.Ultracode.Epoch, constructed_epoch.id, action: :read_unscoped) do
            {:ok, %{state: :running} = fresh_epoch} ->
              fresh_epoch
              |> Ash.Changeset.for_update(:mark_failed, %{})
              |> Ash.update(actor: Xaas.SystemAuthority.new(:ultracode_reactor))
              |> case do
                {:ok, failed_epoch} ->
                  undo_seal_receipt(failed_epoch, :build_broken, %{
                    "undo_reason" =>
                      "a downstream EpochReactor step failed after :construct already committed",
                    "action_taken" => Atom.to_string(action_taken)
                  })

                {:error, error} ->
                  # Reactor's undo contract expects `:ok`/`:retry`/
                  # `{:error, _}` completion, not a raise -- log rather
                  # than crash.
                  Logger.error(
                    "[ultracode] undo: failed to mark_failed epoch " <>
                      "#{constructed_epoch.id}: #{inspect(error)}"
                  )

                  :ok
              end

            {:ok, %{state: real_state}} ->
              # The real row moved out from under this compensation --
              # refuse cleanly instead of clobbering it. Still a real,
              # receipted event (not a silent no-op): the refusal lands
              # as an :refused Receipt naming exactly what was observed.
              Logger.warning(
                "[ultracode] undo: refusing to compensate epoch " <>
                  "#{constructed_epoch.id} -- real row is #{inspect(real_state)}, " <>
                  "not the :running state :construct left it in (a concurrent " <>
                  "close/refuse/re-lease moved it); compensating would clobber a " <>
                  "settled row"
              )

              undo_seal_receipt(constructed_epoch, :refused, %{
                "undo_refused_reason" => "concurrent_state_change",
                "action_taken" => Atom.to_string(action_taken),
                "expected_state" => "running",
                "observed_state" => Atom.to_string(real_state)
              })

            {:error, error} ->
              Logger.error(
                "[ultracode] undo: failed to re-fetch epoch #{constructed_epoch.id} " <>
                  "before compensating: #{inspect(error)}"
              )

              :ok
          end
      end
    end)
  end

  # 偽 Verify -- Chicago-style, state-based check folded in here rather than
  # given a separate step: re-read the real persisted row (not the in-memory
  # struct `Construct` returned) and assert its `state` actually matches what
  # was planned. This is the falsifier -- if the DB disagrees with what
  # `Construct` believes it did, this step catches it and the outcome is
  # `:build_broken`, not a clean turn.
  #
  # Receipt-vocabulary law (2026-09-20, W7 receipt hygiene): a tick turn is
  # LIFECYCLE, not standing. A matched-state tick seals `outcome: :heartbeat`
  # -- the typed NON-STANDING receipt class (see
  # `Xaas.Ultracode.Receipt`'s moduledoc) -- because no terminal court ever
  # ran here: `:start` proves the epoch began running, `:await_provider` is a
  # no-op turn waiting for the provider, and a provider-less `:complete` is
  # the machinery closing its own lifecycle, never evidence the WORK passed
  # anything. The old shape sealed `:alive` on all three, so every tick a
  # leased Run waited on manufactured a standing-looking ALIVE receipt with
  # `await_provider` evidence -- pollution that only jsonb forensics could
  # distinguish from a court-manufactured `:alive`. `:heartbeat` receipts are
  # non-standing everywhere they are consumed (OCEL egress emits them as
  # `heartbeat_recorded`, never `receipt_closed`; run validation cannot
  # close an epoch with them; the autonomic judge repairs on them), and
  # `Validations.AliveRequiresCourt` refuses any tick-shaped `:alive` seal
  # at the Receipt boundary.
  step :verify do
    argument(:constructed, result(:construct))
    argument(:original, result(:observe))

    run(fn %{
             constructed: %{epoch: constructed_epoch, action_taken: action_taken},
             original: original
           },
           _context ->
      expected_state =
        if action_taken in [:start, :await_provider], do: :running, else: :completed

      case Ash.get(Xaas.Ultracode.Epoch, constructed_epoch.id, action: :read_unscoped) do
        {:ok, %{state: ^expected_state} = reloaded} ->
          {:ok,
           %{
             outcome: :heartbeat,
             epoch: reloaded,
             original_state: original.state,
             action_taken: action_taken,
             evidence: %{
               "expected_state" => Atom.to_string(expected_state),
               "observed_state" => Atom.to_string(reloaded.state),
               "action_taken" => Atom.to_string(action_taken)
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
      |> Ash.create(actor: Xaas.SystemAuthority.new(:ultracode_reactor))
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

  # Seals the compensating Receipt for a `:construct` undo. Shared by the
  # successful-compensation, refused-compensation, and no-mutation-needed
  # paths above so the evidence-sealing logic (and its own
  # degrade-don't-crash handling of a failed seal, matching Reactor's own
  # undo contract) exists exactly once.
  defp undo_seal_receipt(epoch, outcome, evidence) do
    Xaas.Ultracode.Receipt
    |> Ash.Changeset.for_create(:seal, %{
      epoch_id: epoch.id,
      subject: epoch.exact_subject,
      outcome: outcome,
      evidence: evidence,
      sealed_at: DateTime.utc_now()
    })
    |> Ash.create(actor: Xaas.SystemAuthority.new(:ultracode_reactor))
    |> case do
      {:ok, _receipt} ->
        :ok

      {:error, error} ->
        Logger.error(
          "[ultracode] undo: failed to seal #{outcome} Receipt for epoch " <>
            "#{epoch.id}: #{inspect(error)}"
        )

        :ok
    end
  end
end
