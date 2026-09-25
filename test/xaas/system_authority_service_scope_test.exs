defmodule Xaas.SystemAuthorityServiceScopeTest do
  use ExUnit.Case, async: true

  alias Xaas.Checks.SystemActor
  alias Xaas.SystemAuthority

  @internal_api_actions [
    {Xaas.Platform.RouteSecrets, :create},
    {Xaas.Platform.RouteSecrets, :destroy},
    {Xaas.Platform.RouteFeatureFlags, :create},
    {Xaas.Platform.RouteFeatureFlags, :update},
    {Xaas.Governance.FreezeWindow, :create},
    {Xaas.Governance.FreezeWindow, :destroy},
    {Xaas.Governance.ApprovalFreezeOverride, :create},
    {Xaas.Governance.ApprovalFreezeOverride, :approve},
    {Xaas.Governance.ApprovalCmekKeyBinding, :create},
    {Xaas.Governance.ApprovalCmekKeyBinding, :approve},
    {Xaas.Governance.ApprovalSsoRoleMappingUpdate, :create},
    {Xaas.Governance.ApprovalSsoRoleMappingUpdate, :approve},
    {Xaas.Governance.ApprovalComplianceRotationBlock, :create},
    {Xaas.Governance.ApprovalComplianceRotationBlock, :approve},
    {Xaas.Governance.DataDestructionCertificateIssue, :create},
    {Xaas.Governance.DataDestructionCertificateIssue, :approve},
    {Xaas.Governance.ApprovalChangeOfControlNotify, :create},
    {Xaas.Governance.ApprovalChangeOfControlNotify, :approve},
    {Xaas.Governance.ApprovalVendorOffboardingAttestationIssue, :create},
    {Xaas.Governance.ApprovalVendorOffboardingAttestationIssue, :approve},
    {Xaas.Governance.ApprovalOrgDelete, :create},
    {Xaas.Governance.ApprovalOrgDelete, :approve},
    {Xaas.Governance.ApprovalInsurancePolicyUpdate, :create},
    {Xaas.Governance.ApprovalInsurancePolicyUpdate, :approve},
    {Xaas.Governance.ApprovalSubprocessorRegistryUpdate, :create},
    {Xaas.Governance.ApprovalSubprocessorRegistryUpdate, :approve},
    {Xaas.Governance.ApprovalGeofenceExceptionGrant, :create},
    {Xaas.Governance.ApprovalGeofenceExceptionGrant, :approve},
    {Xaas.Governance.ApprovalDeniedPartyOverride, :create},
    {Xaas.Governance.ApprovalDeniedPartyOverride, :approve},
    {Xaas.Governance.ApprovalExportSubscriptionUpdate, :create},
    {Xaas.Governance.ApprovalExportSubscriptionUpdate, :approve},
    {Xaas.Governance.ApprovalLeRequestRespond, :create},
    {Xaas.Governance.ApprovalLeRequestRespond, :approve},
    {Xaas.Governance.ApprovalPersonnelAttestationRecord, :create},
    {Xaas.Governance.ApprovalPersonnelAttestationRecord, :approve},
    {Xaas.Governance.ApprovalPentestFindingResolve, :create},
    {Xaas.Governance.ApprovalPentestFindingResolve, :approve},
    {Xaas.Governance.ApprovalSourceEscrowSnapshot, :create},
    {Xaas.Governance.ApprovalSourceEscrowSnapshot, :approve},
    {Xaas.Governance.ApprovalDsarErasure, :create},
    {Xaas.Governance.ApprovalDsarErasure, :approve},
    {Xaas.Governance.ApprovalEnvironmentPromote, :create},
    {Xaas.Governance.ApprovalEnvironmentPromote, :approve},
    {Xaas.Governance.ApprovalBreakGlassJustificationReview, :create},
    {Xaas.Governance.ApprovalBreakGlassJustificationReview, :approve},
    {Xaas.Billing.ApprovalPricingOverride, :approve},
    {Xaas.Billing.ApprovalQuotaOverride, :create},
    {Xaas.Billing.ApprovalQuotaOverride, :approve},
    {Xaas.Billing.ApprovalInvoiceReconciliationApprove, :create},
    {Xaas.Billing.ApprovalInvoiceReconciliationApprove, :approve},
    {Xaas.Operations.ApprovalK8sFaultRemediateSuggest, :create},
    {Xaas.Operations.ApprovalK8sFaultRemediateSuggest, :approve},
    {Xaas.Operations.ApprovalCastleVerbSchedule, :create},
    {Xaas.Operations.ApprovalCastleVerbSchedule, :approve}
  ]

  @autofde_actions [
    {Xaas.Operations.AutofdePlannerMatch, :request_match},
    {Xaas.Operations.AutofdePlannerCatalog, :request_catalog},
    {Xaas.Operations.AutofdePlannerCacheStats, :request_cache_stats},
    {Xaas.Operations.AutofdePlannerCacheHotset, :request_cache_hotset},
    {Xaas.Operations.AutofdePlannerCandidate, :request_candidate}
  ]

  test "XAAS-2602's 61 exact mutation subjects are bound to one canonical service" do
    assert length(@internal_api_actions) == 55
    assert length(@autofde_actions) == 5

    Enum.each(@internal_api_actions, fn {resource, action} ->
      assert {:ok, :internal_api} = SystemActor.service_for(resource, action)
    end)

    Enum.each(@autofde_actions, fn {resource, action} ->
      assert {:ok, :autofde_coverage_monitor} = SystemActor.service_for(resource, action)
    end)

    assert {:ok, :oban_scheduler} =
             SystemActor.service_for(
               Xaas.Operations.CapabilityLivenessReceipt,
               :check_regressions
             )
  end

  test "the authority vocabulary admits the two XAAS-2602 roots but remains closed" do
    assert SystemAuthority.system?(SystemAuthority.new(:internal_api))
    assert SystemAuthority.system?(SystemAuthority.new(:autofde_coverage_monitor))

    assert_raise ArgumentError, fn -> SystemAuthority.new(:fabricated_service) end
    refute SystemAuthority.system?(%SystemAuthority{service: :fabricated_service})
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

  test "an explicit service cannot contradict an exact-subject capability" do
    subject =
      Xaas.Platform.RouteSecrets
      |> Ash.Changeset.for_create(:create, %{
        namespace: "scope-conflict",
        name: "creds",
        requested_by: "scope-test"
      })

    refute SystemActor.match?(
             SystemAuthority.new(:oban_scheduler),
             %{subject: subject},
             service: :oban_scheduler
           )
  end

  test "the AshOban liveness action rejects a genuine system actor from the wrong service" do
    assert {:error, %Ash.Error.Forbidden{}} =
             Xaas.Operations.CapabilityLivenessReceipt
             |> Ash.ActionInput.for_action(:check_regressions, %{})
             |> Ash.run_action(actor: SystemAuthority.new(:internal_api))
  end
end
