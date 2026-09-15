defmodule Xaas.SystemAuthorityServiceScopeTest do
  use ExUnit.Case, async: true

  alias Xaas.Checks.SystemActor
  alias Xaas.SystemAuthority

  @internal_api_resources [
    Xaas.Billing.ApprovalInvoiceReconciliationApprove,
    Xaas.Billing.ApprovalPricingOverride,
    Xaas.Billing.ApprovalQuotaOverride,
    Xaas.Governance.ApprovalBreakGlassJustificationReview,
    Xaas.Governance.ApprovalChangeOfControlNotify,
    Xaas.Governance.ApprovalCmekKeyBinding,
    Xaas.Governance.ApprovalComplianceRotationBlock,
    Xaas.Governance.ApprovalDeniedPartyOverride,
    Xaas.Governance.ApprovalDsarErasure,
    Xaas.Governance.ApprovalEnvironmentPromote,
    Xaas.Governance.ApprovalExportSubscriptionUpdate,
    Xaas.Governance.ApprovalFreezeOverride,
    Xaas.Governance.ApprovalGeofenceExceptionGrant,
    Xaas.Governance.ApprovalInsurancePolicyUpdate,
    Xaas.Governance.ApprovalLeRequestRespond,
    Xaas.Governance.ApprovalOrgDelete,
    Xaas.Governance.ApprovalPentestFindingResolve,
    Xaas.Governance.ApprovalPersonnelAttestationRecord,
    Xaas.Governance.ApprovalSourceEscrowSnapshot,
    Xaas.Governance.ApprovalSsoRoleMappingUpdate,
    Xaas.Governance.ApprovalSubprocessorRegistryUpdate,
    Xaas.Governance.ApprovalVendorOffboardingAttestationIssue,
    Xaas.Governance.DataDestructionCertificateIssue,
    Xaas.Governance.FreezeWindow,
    Xaas.Operations.ApprovalCastleVerbSchedule,
    Xaas.Operations.ApprovalK8sFaultRemediateSuggest,
    Xaas.Platform.RouteFeatureFlags,
    Xaas.Platform.RouteSecrets
  ]

  @autofde_resources [
    Xaas.Operations.AutofdePlannerCacheHotset,
    Xaas.Operations.AutofdePlannerCacheStats,
    Xaas.Operations.AutofdePlannerCandidate,
    Xaas.Operations.AutofdePlannerCatalog,
    Xaas.Operations.AutofdePlannerMatch
  ]

  test "every XAAS-2602 canonical resource admits only its owning system service" do
    Enum.each(@internal_api_resources, fn resource ->
      context = %{resource: resource}

      assert SystemActor.match?(SystemAuthority.new(:internal_api), context, [])
      refute SystemActor.match?(SystemAuthority.new(:oban_scheduler), context, [])
      refute SystemActor.match?(SystemAuthority.new(:autofde_coverage_monitor), context, [])
    end)

    Enum.each(@autofde_resources, fn resource ->
      context = %{resource: resource}

      assert SystemActor.match?(SystemAuthority.new(:autofde_coverage_monitor), context, [])
      refute SystemActor.match?(SystemAuthority.new(:internal_api), context, [])
      refute SystemActor.match?(SystemAuthority.new(:oban_scheduler), context, [])
    end)

    context = %{resource: Xaas.Operations.CapabilityLivenessReceipt}

    assert SystemActor.match?(SystemAuthority.new(:oban_scheduler), context, [])
    refute SystemActor.match?(SystemAuthority.new(:internal_api), context, [])
    refute SystemActor.match?(SystemAuthority.new(:autofde_coverage_monitor), context, [])
  end

  test "an explicit service scope cannot contradict a classified resource scope" do
    context = %{resource: Xaas.Platform.RouteSecrets}

    refute SystemActor.match?(
             SystemAuthority.new(:oban_scheduler),
             context,
             service: :oban_scheduler
           )

    assert SystemActor.match?(
             SystemAuthority.new(:internal_api),
             context,
             service: :internal_api
           )
  end

  test "the real Ash policy calculus rejects a wrong genuine service on service-boundary and autofde actions" do
    route_changeset =
      Xaas.Platform.RouteSecrets
      |> Ash.Changeset.for_create(:create, %{
        namespace: "wrong-service-falsifier",
        name: "creds",
        requested_by: "scope-test"
      })

    refute Ash.can?(route_changeset, SystemAuthority.new(:oban_scheduler))
    assert Ash.can?(route_changeset, SystemAuthority.new(:internal_api))

    autofde_changeset =
      Xaas.Operations.AutofdePlannerMatch
      |> Ash.Changeset.for_create(:request_match, %{query: "Maze"})

    refute Ash.can?(autofde_changeset, SystemAuthority.new(:internal_api))
    assert Ash.can?(autofde_changeset, SystemAuthority.new(:autofde_coverage_monitor))
  end

  test "the AshOban liveness action rejects a genuine system actor from the wrong service" do
    assert {:error, %Ash.Error.Forbidden{}} =
             Xaas.Operations.CapabilityLivenessReceipt
             |> Ash.ActionInput.for_action(:check_regressions, %{})
             |> Ash.run_action(actor: SystemAuthority.new(:internal_api))
  end
end
