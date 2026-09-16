defmodule Xaas.Checks.SystemActor do
  @moduledoc """
  Fail-closed `Ash.Policy.SimpleCheck` for internal-system authority.

  Generic `{Xaas.Checks.SystemActor, []}` policies derive the required service
  from the exact resource/action subject. Unknown subjects have no ambient
  authority and are refused. Explicit `service:` policies remain supported for
  unclassified legacy subjects, but an explicit service may not contradict a
  canonical exact-subject mapping.

  XAAS-2602 extends the XAAS-2601 capability map rather than replacing it:
  HTTP service-boundary mutations require `:internal_api`, AutoFDE planner
  requests require `:autofde_coverage_monitor`, and the liveness cron action
  requires `:oban_scheduler`.
  """

  use Ash.Policy.SimpleCheck

  @xaas_2601_actions [
    {Xaas.Ultracode.Run, :tick, :oban_scheduler},
    {Xaas.Ultracode.Run, :advance_cycle, :ultracode_reactor},
    {Xaas.Ultracode.Run, :transition_state, :ultracode_reactor},
    {Xaas.Ultracode.Epoch, :create, :ultracode_reactor},
    {Xaas.Ultracode.Epoch, :start, :ultracode_reactor},
    {Xaas.Ultracode.Epoch, :complete, :ultracode_reactor},
    {Xaas.Ultracode.Epoch, :mark_missed, :ultracode_reactor},
    {Xaas.Ultracode.Epoch, :mark_failed, :ultracode_reactor},
    {Xaas.Ultracode.Receipt, :seal, :ultracode_reactor},
    {Xaas.Platform.WebhookDelivery, :retry_failed_deliveries, :oban_scheduler},
    {Xaas.Platform.WebhookDelivery, :deliver, :webhook_dispatcher},
    {Xaas.Library.HoldRequest, :expire_stale, :oban_scheduler},
    {Xaas.Library.HoldRequest, :expire, :oban_scheduler}
  ]

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

  @action_services Enum.reduce(@xaas_2601_actions, %{}, fn {resource, action, service}, acc ->
                     Map.put(acc, {resource, action}, service)
                   end)
                   |> Map.merge(Map.new(@internal_api_actions, &{&1, :internal_api}))
                   |> Map.merge(Map.new(@autofde_actions, &{&1, :autofde_coverage_monitor}))
                   |> Map.put(
                     {Xaas.Operations.CapabilityLivenessReceipt, :check_regressions},
                     :oban_scheduler
                   )

  @impl true
  def describe(opts) do
    case opts[:service] do
      nil -> "actor carries the service capability required by the exact protected action"
      service -> "actor is a Xaas.SystemAuthority for service #{inspect(service)}"
    end
  end

  @impl true
  def match?(actor, %{subject: subject}, opts) do
    with true <- Xaas.SystemAuthority.system?(actor),
         {:ok, required_service} <- required_service(subject, opts) do
      actor.service == required_service
    else
      _ -> false
    end
  end

  def match?(_actor, _context, _opts), do: false

  @doc false
  @spec service_for(module(), atom()) :: {:ok, Xaas.SystemAuthority.service()} | :error
  def service_for(resource, action), do: Map.fetch(@action_services, {resource, action})

  defp required_service(subject, opts) do
    canonical =
      case subject_key(subject) do
        {resource, action} -> service_for(resource, action)
        _ -> :error
      end

    case {Keyword.fetch(opts, :service), canonical} do
      {{:ok, service}, {:ok, service}} -> admitted_service(service)
      {{:ok, _explicit}, {:ok, _canonical}} -> :error
      {{:ok, service}, :error} -> admitted_service(service)
      {:error, canonical_result} -> canonical_result
    end
  end

  defp admitted_service(service) do
    if service in Xaas.SystemAuthority.services(), do: {:ok, service}, else: :error
  end

  defp subject_key(%Ash.Changeset{resource: resource, action: %{name: action}}),
    do: {resource, action}

  defp subject_key(%Ash.ActionInput{resource: resource, action: %{name: action}}),
    do: {resource, action}

  defp subject_key(%Ash.Query{resource: resource, action: %{name: action}}),
    do: {resource, action}

  defp subject_key(_subject), do: nil
end
