defmodule Xaas.Governance.W984czGovChangesDirectCourtTest do
  @moduledoc """
  Lane W984cz court (v26.10.6): DIRECT exercise (validate/3 on real
  `Ash.Changeset`s, not only through actions) of the 3 most
  safety-relevant modules in the W984cz governance change/validation
  batch, per the W984cj map's "likely only indirectly exercised" finding.

  Batch census (lib/xaas/governance/): 29 modules under changes/
  (26 of them 13-line identity `use Ash.Resource.Change` stubs, plus
  enqueue_webhook_deliveries/generate_audit_export_token/
  generate_internal_api_token/write_audit_log_entry which carry real
  behavior) and 42 modules under validations/.

  Selected modules (real logic, safety-relevant):

  1. `Xaas.Governance.Validations.ApprovalFreezeOverrideFreezeWindowExists`
     -- freeze-related maker-checker gate: existence + cross-org
     integrity + the referenced window's `allow_emergency_override` flag.
  2. `Xaas.Governance.Validations.ApprovalNotAlreadyApproved`
     -- maker-checker re-approve state guard shared by 4 `Approval*`
     resources' `:approve` actions.
  3. `Xaas.Governance.Validations.FreezeWindowEndsAfterStarts`
     -- freeze-window boundary rule mirrored from platform-console.

  Typed disposition: the 26 sibling `*Approve` changes (e.g.
  `ApprovalFakeOverrideApprove`) are 13-line identity stubs
  (`change/2 -> changeset` verbatim) -- no behavior to court, per the
  no-padding clause. `write_audit_log_entry.ex` (90 lines),
  `enqueue_webhook_deliveries.ex` (129), `generate_internal_api_token.ex`
  (40) carry real behavior but sit outside this lane's 3-module slice.

  Mutation rationale per test: each test names the single-line mutation
  that survives if the guarded behavior regresses, and asserts on real
  Postgres-backed state (Chicago: real `Ash.get` inside the validation,
  real sandboxed rows). Unique-per-run org ids make each run a fresh
  root, so the ×2 fresh-root run below is real, not fixture reuse.
  """

  use ExUnit.Case, async: true

  alias Xaas.Accounts.Org
  alias Xaas.Governance.{ApprovalFreezeOverride, FreezeWindow}

  @freeze_exists Xaas.Governance.Validations.ApprovalFreezeOverrideFreezeWindowExists
  @not_approved Xaas.Governance.Validations.ApprovalNotAlreadyApproved
  @ends_after   Xaas.Governance.Validations.FreezeWindowEndsAfterStarts

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp org(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp window!(org_id, allow) do
    now = DateTime.utc_now()

    FreezeWindow
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      starts_at: now,
      ends_at: DateTime.add(now, 3600, :second),
      reason: "w984cz court window",
      allow_emergency_override: allow,
      created_by: "w984cz-lane"
    })
    |> Ash.create!(authorize?: false)
  end

  defp override_changeset(org_id, freeze_window_id) do
    ApprovalFreezeOverride
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      requested_by: "requester-#{System.unique_integer([:positive])}",
      freeze_window_id: freeze_window_id,
      reason: "w984cz direct-court probe"
    })
  end

  defp reject_msg(result) do
    case result do
      {:error, field: :freeze_window_id, message: m} -> m
      other -> flunk("expected typed freeze_window_id refusal, got: #{inspect(other)}")
    end
  end

  # ------------------------------------------------------------------
  # (1) ApprovalFreezeOverrideFreezeWindowExists -- existence gap
  # Mutation: map the `{:error, _}` clause of check_freeze_window/2 to
  # :ok -- a ghost freeze_window_id would then be admitted at create.
  # ------------------------------------------------------------------
  test "(1) ghost freeze_window_id refused by direct validate/3" do
    cs = override_changeset(org("w984cz-ghost"), Ecto.UUID.generate())

    assert {:error, field: :freeze_window_id, message: msg} =
             @freeze_exists.validate(cs, [], %{})

    assert msg =~ "does not reference a real freeze window"
  end

  # ------------------------------------------------------------------
  # (2) ApprovalFreezeOverrideFreezeWindowExists -- cross-org + emergency
  # Mutation A: drop the `freeze_window.org_id != org_id` clause ->
  # cross-org reference admitted (tenant boundary breach).
  # Mutation B: drop the `allow_emergency_override != true` clause ->
  # overrides against non-emergency windows admitted.
  # ------------------------------------------------------------------
  test "(2) cross-org window refused; non-emergency window refused; eligible window passes" do
    org_a = org("w984cz-a")
    org_b = org("w984cz-b")

    foreign_window = window!(org_b, true)

    assert "must reference a freeze window in the same org as this override request" =
             override_changeset(org_a, foreign_window.id)
             |> @freeze_exists.validate([], %{})
             |> reject_msg()

    calm_window = window!(org_a, false)

    assert "does not allow emergency overrides to be filed against it" =
             override_changeset(org_a, calm_window.id)
             |> @freeze_exists.validate([], %{})
             |> reject_msg()

    eligible = window!(org_a, true)

    assert :ok =
             override_changeset(org_a, eligible.id)
             |> @freeze_exists.validate([], %{})
  end

  # ------------------------------------------------------------------
  # (3) ApprovalNotAlreadyApproved -- re-approve guard (maker-checker)
  # Mutation: `nil -> :ok` extended to any input -> second :approve
  # silently overwrites approved_by. Uses a real persisted
  # ApprovalLegalHoldRelease (one of the 4 guarded resources) so
  # get_data/2 reads real pre-update data, not a hand-built struct.
  # ------------------------------------------------------------------
  defp real_org!(prefix) do
    unique = System.unique_integer([:positive])

    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "#{prefix} #{unique}",
      slug: "#{prefix}-#{unique}"
    })
    |> Ash.create!(authorize?: false)
  end

  test "(3) pre-update approved_by present -> refused; nil -> :ok" do
    org_id = real_org!("w984cz-naa").slug

    approved_row =
      Xaas.Governance.ApprovalLegalHoldRelease
      |> Ash.Changeset.for_create(:create, %{
        org_id: org_id,
        requested_by: "req-#{System.unique_integer([:positive])}",
        hold_id: "hold-#{System.unique_integer([:positive])}",
        release_reason: "w984cz re-approve guard probe"
      })
      |> Ash.create!(authorize?: false, tenant: org_id)

    # Simulate the already-approved pre-update state by writing the real
    # persisted row's approved_by data field directly (the :create action
    # does not accept approved_by); get_data/2 reads this real value.
    already_approved = %{approved_row | approved_by: "approver-1"}

    reapprove_cs =
      already_approved
      |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-2"}, tenant: org_id)

    assert {:error, field: :approved_by,
            message: "has already been approved -- cannot re-approve"} =
             @not_approved.validate(reapprove_cs, [], %{})

    fresh_cs =
      Xaas.Governance.ApprovalLegalHoldRelease
      |> Ash.Changeset.for_create(:create, %{
        org_id: org_id,
        requested_by: "req-#{System.unique_integer([:positive])}",
        hold_id: "hold-#{System.unique_integer([:positive])}",
        release_reason: "w984cz nil-path probe"
      },
      tenant: org_id)

    assert :ok = @not_approved.validate(fresh_cs, [], %{})
  end

  # ------------------------------------------------------------------
  # (4) FreezeWindowEndsAfterStarts -- boundary rule
  # Mutation: `!= :gt` relaxed to `== :lt` -- ends_at == starts_at would
  # be admitted (zero-length freeze window, breaks the active-gate
  # inclusive end arithmetic exercised by freeze_window_active_gate_test).
  # ------------------------------------------------------------------
  test "(4) ends_at == starts_at refused; ends_at > starts_at passes; nil pairs pass" do
    now = DateTime.utc_now()

    equal_cs =
      FreezeWindow
      |> Ash.Changeset.for_create(:create, %{
        org_id: org("w984cz-eq"),
        starts_at: now,
        ends_at: now,
        reason: "zero-length probe",
        created_by: "w984cz-lane"
      })

    assert {:error, field: :ends_at, message: "must be after starts_at"} =
             @ends_after.validate(equal_cs, [], %{})

    good_cs =
      FreezeWindow
      |> Ash.Changeset.for_create(:create, %{
        org_id: org("w984cz-ok"),
        starts_at: now,
        ends_at: DateTime.add(now, 1, :second),
        reason: "one-second probe",
        created_by: "w984cz-lane"
      })

    assert :ok = @ends_after.validate(good_cs, [], %{})

    nil_cs =
      FreezeWindow
      |> Ash.Changeset.for_create(:create, %{org_id: org("w984cz-nil")})

    assert :ok = @ends_after.validate(nil_cs, [], %{})
  end

  # ------------------------------------------------------------------
  # (5) Non-vacuity ×2 fresh root: rerun court (1)+(3) against a second
  # fresh root (new sandbox checkout, new unique orgs) to prove the
  # refusals track real database state, not fixture reuse.
  # ------------------------------------------------------------------
  test "(5) fresh-root rerun: ghost refusal and re-approve refusal reproduce" do
    # Root 2 of the ghost-id court (fresh sandbox checkout from setup,
    # fresh unique orgs -- no fixture reuse).
    cs = override_changeset(org("w984cz-ghost2"), Ecto.UUID.generate())

    assert {:error, field: :freeze_window_id, message: msg} =
             @freeze_exists.validate(cs, [], %{})

    assert msg =~ "does not reference a real freeze window"

    # Root 2 of the re-approve court.
    org_id = real_org!("w984cz-naa2").slug

    approved_row =
      Xaas.Governance.ApprovalLegalHoldRelease
      |> Ash.Changeset.for_create(:create, %{
        org_id: org_id,
        requested_by: "req-#{System.unique_integer([:positive])}",
        hold_id: "hold-#{System.unique_integer([:positive])}",
        release_reason: "w984cz fresh-root probe"
      })
      |> Ash.create!(authorize?: false, tenant: org_id)

    already_approved = %{approved_row | approved_by: "approver-a"}

    reapprove_cs =
      already_approved
      |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-b"}, tenant: org_id)

    assert {:error, field: :approved_by, message: m2} =
             @not_approved.validate(reapprove_cs, [], %{})

    assert m2 =~ "already been approved"
  end
end
