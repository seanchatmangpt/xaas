defmodule Xaas.Checks.SystemActor do
  @moduledoc """
  `Ash.Policy.SimpleCheck` for internal system authority.

  A genuine `Xaas.SystemAuthority` struct is necessary but not sufficient on
  the XAAS-2602 surfaces. The check also binds the actor's `service` to the
  canonical service that owns the resource. This prevents a genuine authority
  minted for one subsystem (for example `:oban_scheduler`) from crossing into
  another subsystem's mutation boundary (for example `:internal_api`).

  Call sites may still provide an explicit `service:` option. For resources in
  the canonical XAAS-2602 map, an explicit service must agree with the
  canonical service; disagreement fails closed. Unmapped legacy resources keep
  the prior explicit-service/any-system semantics until they are classified.
  """

  use Ash.Policy.SimpleCheck

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

  @canonical_resource_services (
                                 Map.new(@internal_api_resources, &{&1, :internal_api})
                                 |> Map.merge(
                                   Map.new(
                                     @autofde_resources,
                                     &{&1, :autofde_coverage_monitor}
                                   )
                                 )
                                 |> Map.put(
                                   Xaas.Operations.CapabilityLivenessReceipt,
                                   :oban_scheduler
                                 )
                               )

  @impl true
  def describe(opts) do
    case opts[:service] do
      nil -> "actor is a genuine Xaas.SystemAuthority in the resource's canonical service scope"
      service -> "actor is a Xaas.SystemAuthority for service #{inspect(service)}"
    end
  end

  @impl true
  def match?(actor, context, opts) do
    required_service = required_service(context, opts)

    Xaas.SystemAuthority.system?(actor) and
      service_admitted?(actor.service, required_service)
  end

  defp required_service(context, opts) do
    explicit = opts[:service]
    canonical = Map.get(@canonical_resource_services, Map.get(context, :resource))

    case {explicit, canonical} do
      {nil, canonical} -> canonical
      {explicit, nil} -> explicit
      {service, service} -> service
      {explicit, canonical} -> {:scope_conflict, explicit, canonical}
    end
  end

  defp service_admitted?(_actual, nil), do: true

  defp service_admitted?(actual, required) when is_atom(actual) and is_atom(required),
    do: actual == required

  defp service_admitted?(_actual, _required), do: false
end
