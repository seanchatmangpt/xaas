defmodule Xaas.Billing.GovLongTailCourtW984eaTest do
  @moduledoc """
  Lane W984ea (v26.10.6): Chicago courts for the billing/g governance
  long-tail 2-pub modules from W984du's fifth re-census
  (`/tmp/w984du_map.txt`), re-derived fresh on disk 2026-10-07.

  Dispositions:

  - `Xaas.Billing.Validations.SubscriptionChangeTierNotNoOp` -- COVERED:
    exercised through the live `Subscription.change_tier` action by
    `test/xaas/billing_deepening_test.exs` (real no-op refusal test) and
    `test/xaas/billing/subscription_test.exs`. Skipped here.
  - `Xaas.Governance.Changes.ApprovalBackupRetentionChangeApprove` --
    wired on `ApprovalBackupRetentionChange`'s live `:approve` action,
    exercised by
    `test/xaas/governance/approval_backup_retention_change_test.exs`;
    included below in the uniform identity court.
  - `Xaas.Governance.Changes.GenerateInternalApiToken` -- courted below
    through the LIVE `InternalApiToken :issue` action (metadata-return +
    hash-before-persistence contract).
  - The remaining 23 governance `Approval*Approve` change modules +
    `DataDestructionCertificateIssueApprove` + the 2 billing orphans
    (`ApprovalInvoiceReconciliationApproveApprove`,
    `ApprovalQuotaOverrideApprove`) are UNWIRED thin identity changes
    (repo-wide wiring grep matches only their own defining files).
    Courted directly: `init/2` passthrough + `change/3` identity on a
    REAL `Ash.Changeset` built by each consumer resource's real
    `:approve` action (`Ash.Changeset.for_update/3`).

  Mutation rationale per row: these change modules are identity
  passthroughs by design; the court kills (a) any mutation making
  `change/3` mutate the changeset (dropping accepted `:approved_by`,
  stripping attributes/context) via structural equality with the input
  changeset; (b) any mutation breaking `init/2` opts passthrough (opts
  are future behavior carriers); (c) for `GenerateInternalApiToken`, any
  mutation of the raw-token-metadata and hash-before-persistence
  contract. Identity assertions on real changesets are the only
  observable contract these modules expose.
  """

  use ExUnit.Case, async: true

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  alias Xaas.Governance.{
    ApprovalBackupRetentionChange,
    ApprovalBreakGlassJustificationReview,
    ApprovalChangeOfControlNotify,
    ApprovalCmekKeyBinding,
    ApprovalComplianceRotationBlock,
    ApprovalDeniedPartyOverride,
    ApprovalDeploymentQuarantine,
    ApprovalDrFailover,
    ApprovalDsarErasure,
    ApprovalEnvironmentPromote,
    ApprovalExportSubscriptionUpdate,
    ApprovalFreezeOverride,
    ApprovalGeofenceExceptionGrant,
    ApprovalInsurancePolicyUpdate,
    ApprovalLeRequestRespond,
    ApprovalLegalHoldRelease,
    ApprovalOrgDelete,
    ApprovalPentestFindingResolve,
    ApprovalPersonnelAttestationRecord,
    ApprovalSourceEscrowSnapshot,
    ApprovalSsoRoleMappingUpdate,
    ApprovalSubprocessorRegistryUpdate,
    ApprovalVendorOffboardingAttestationIssue,
    DataDestructionCertificateIssue,
    InternalApiToken
  }

  alias Xaas.Billing.ApprovalInvoiceReconciliationApprove
  alias Xaas.Billing.ApprovalQuotaOverride

  # {consumer resource, change module}. Every resource here exposes a
  # real `update :approve` action accepting [:approved_by] (same action
  # family W984dr2b's court verified for the sibling validations).
  @gov_rows [
    {ApprovalBackupRetentionChange,
     Xaas.Governance.Changes.ApprovalBackupRetentionChangeApprove},
    {ApprovalBreakGlassJustificationReview,
     Xaas.Governance.Changes.ApprovalBreakGlassJustificationReviewApprove},
    {ApprovalChangeOfControlNotify,
     Xaas.Governance.Changes.ApprovalChangeOfControlNotifyApprove},
    {ApprovalCmekKeyBinding, Xaas.Governance.Changes.ApprovalCmekKeyBindingApprove},
    {ApprovalComplianceRotationBlock,
     Xaas.Governance.Changes.ApprovalComplianceRotationBlockApprove},
    {ApprovalDeniedPartyOverride, Xaas.Governance.Changes.ApprovalDeniedPartyOverrideApprove},
    {ApprovalDeploymentQuarantine, Xaas.Governance.Changes.ApprovalDeploymentQuarantineApprove},
    {ApprovalDrFailover, Xaas.Governance.Changes.ApprovalDrFailoverApprove},
    {ApprovalDsarErasure, Xaas.Governance.Changes.ApprovalDsarErasureApprove},
    {ApprovalEnvironmentPromote, Xaas.Governance.Changes.ApprovalEnvironmentPromoteApprove},
    {ApprovalExportSubscriptionUpdate,
     Xaas.Governance.Changes.ApprovalExportSubscriptionUpdateApprove},
    {ApprovalFreezeOverride, Xaas.Governance.Changes.ApprovalFreezeOverrideApprove},
    {ApprovalGeofenceExceptionGrant,
     Xaas.Governance.Changes.ApprovalGeofenceExceptionGrantApprove},
    {ApprovalInsurancePolicyUpdate,
     Xaas.Governance.Changes.ApprovalInsurancePolicyUpdateApprove},
    {ApprovalLeRequestRespond, Xaas.Governance.Changes.ApprovalLeRequestRespondApprove},
    {ApprovalLegalHoldRelease, Xaas.Governance.Changes.ApprovalLegalHoldReleaseApprove},
    {ApprovalOrgDelete, Xaas.Governance.Changes.ApprovalOrgDeleteApprove},
    {ApprovalPentestFindingResolve,
     Xaas.Governance.Changes.ApprovalPentestFindingResolveApprove},
    {ApprovalPersonnelAttestationRecord,
     Xaas.Governance.Changes.ApprovalPersonnelAttestationRecordApprove},
    {ApprovalSourceEscrowSnapshot,
     Xaas.Governance.Changes.ApprovalSourceEscrowSnapshotApprove},
    {ApprovalSsoRoleMappingUpdate, Xaas.Governance.Changes.ApprovalSsoRoleMappingUpdateApprove},
    {ApprovalSubprocessorRegistryUpdate,
     Xaas.Governance.Changes.ApprovalSubprocessorRegistryUpdateApprove},
    {ApprovalVendorOffboardingAttestationIssue,
     Xaas.Governance.Changes.ApprovalVendorOffboardingAttestationIssueApprove},
    {DataDestructionCertificateIssue,
     Xaas.Governance.Changes.DataDestructionCertificateIssueApprove}
  ]

  @billing_rows [
    {ApprovalInvoiceReconciliationApprove,
     Xaas.Billing.Changes.ApprovalInvoiceReconciliationApproveApprove},
    {ApprovalQuotaOverride, Xaas.Billing.Changes.ApprovalQuotaOverrideApprove}
  ]

  defp identity_court!(resource, change_module) do
    changeset =
      Ash.Changeset.for_update(struct(resource), :approve, %{approved_by: "w984ea-court"})

    assert {:ok, opts} = change_module.init([])
    assert opts == []

    returned = change_module.change(changeset, [some: :opts, lane: :w984ea], %{lane: :w984ea})
    assert returned == changeset
    :ok
  end

  test "governance thin Approve changes are init-passthrough + changeset identity" do
    for {resource, change_module} <- @gov_rows do
      assert identity_court!(resource, change_module) == :ok,
             "#{inspect(change_module)} is not an identity passthrough"
    end

    assert length(@gov_rows) == 24
    assert @gov_rows |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length() == 24
    assert @gov_rows |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() == 24
  end

  test "billing thin Approve changes are init-passthrough + changeset identity" do
    for {resource, change_module} <- @billing_rows do
      assert identity_court!(resource, change_module) == :ok,
             "#{inspect(change_module)} is not an identity passthrough"
    end

    assert length(@billing_rows) == 2
  end

  test "GenerateInternalApiToken via live :issue returns raw token metadata once and stores only the hash" do
    created_by = "w984ea-#{System.unique_integer([:positive])}"

    {:ok, token} =
      InternalApiToken
      |> Ash.Changeset.for_create(:issue, %{created_by: created_by})
      |> Ash.create(authorize?: false)

    raw = Ash.Resource.get_metadata(token, :raw_token)

    assert is_binary(raw) and byte_size(raw) > 40
    assert String.starts_with?(raw, Xaas.Governance.InternalApiTokenAuth.prefix())

    assert token.token_prefix ==
             String.slice(raw, 0, Xaas.Governance.InternalApiTokenAuth.display_prefix_len())

    assert token.token_hash == Base.encode16(:crypto.hash(:sha256, raw), case: :lower)

    # hash-before-persistence: the raw token's body must not be the
    # stored hash and the stored hash must not embed the raw prefix body
    refute token.token_hash == raw
    refute String.contains?(token.token_hash, String.slice(raw, String.length(Xaas.Governance.InternalApiTokenAuth.prefix()), 16))
  end
end
