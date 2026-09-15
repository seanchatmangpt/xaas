defmodule XaasWeb.Plugs.SetInternalApiSystemActor do
  @moduledoc """
  Real XAAS-2602 companion to `XaasWeb.Plugs.RequireInternalApiToken` for
  the SERVICE-BOUNDARY mutation sites whose previous bare
  `bypass action(...) do authorize_if(always()) end` carve-outs are now the
  real system-authority predicate `Xaas.Checks.SystemActor`
  (`Xaas.SystemAuthority` actor, see XAAS-2601).

  Those resources' ONLY real callers are their own JSON:API routes under
  `/api` (and `/internal-api` for the two Operations approvals) -- there is
  no hand-written controller to pass an actor at, so the router pipeline
  IS the controller call site: after the Bearer-token check admits the
  caller as a real internal service, this plug supplies the real system
  authority actor `Xaas.SystemAuthority.new(:internal_api)` through the
  same `Ash.PlugHelpers.set_actor/2` mechanism
  `XaasWeb.Plugs.ResolveOrgActor` already uses (the one AshJsonApi's own
  request path reads).

  Security level is UNCHANGED at the HTTP boundary -- the internal token
  is still required and still fail-closed -- but the actions no longer
  authorize literally any actor through any other path: a non-system
  actor reaching one of these actions through any other route now falls
  to the resource's deny-by-default floor.

  Path-aware by the same disclosed design decision as
  `XaasWeb.Plugs.ResolveOrgActor`: the `/api` and `/internal-api` prefixes
  are single blanket `forward`s to AshJsonApi routers with no per-resource
  pipeline hook inside, so this plug inspects `conn.path_info` itself and
  only touches requests whose first path segment is one of the converted
  resources' route bases below. Every other request passes through
  completely unaffected -- this plug NEVER loosens another resource's
  policies (it only ever supplies an actor where the previous policy was
  the unconditional `always()`, and only when no actor was already
  resolved, so `ResolveOrgActor`'s real org actors always win where they
  apply). The segment set is disjoint from `ResolveOrgActor`'s
  `@tenant_scoped_path_segments`.
  """

  import Plug.Conn

  # The 28 XAAS-2602 SERVICE-BOUNDARY resources (see
  # docs/jira/v26.9.15/XAAS-2602-always-bypass-classification.md for the
  # full per-site classification evidence): Platform route_secrets /
  # route_feature_flags, Governance freeze_window + 20 Approval* maker-
  # checker flows, Billing approval_pricing_override / approval_quota_override /
  # approval_invoice_reconciliation_approve, and the two Operations
  # approvals (served under BOTH /api and /internal-api -- both prefixes
  # are matched below).
  @system_actor_path_segments ~w(
    route_secrets
    route_feature_flags
    freeze_window
    approval_freeze_override
    approval_cmek_key_binding
    approval_sso_role_mapping_update
    approval_compliance_rotation_block
    data_destruction_certificate_issue
    approval_change_of_control_notify
    approval_vendor_offboarding_attestation_issue
    approval_org_delete
    approval_insurance_policy_update
    approval_subprocessor_registry_update
    approval_geofence_exception_grant
    approval_denied_party_override
    approval_export_subscription_update
    approval_le_request_respond
    approval_personnel_attestation_record
    approval_pentest_finding_resolve
    approval_source_escrow_snapshot
    approval_dsar_erasure
    approval_environment_promote
    approval_break_glass_justification_review
    approval_pricing_override
    approval_quota_override
    approval_invoice_reconciliation_approve
    approval_k8s_fault_remediate_suggest
    approval_castle_verb_schedule
  )

  def init(opts), do: opts

  def call(conn, _opts) do
    if system_actor_scoped?(conn) and is_nil(Ash.PlugHelpers.get_actor(conn)) do
      actor = Xaas.SystemAuthority.new(:internal_api)

      conn
      |> assign(:current_actor, actor)
      |> Ash.PlugHelpers.set_actor(actor)
    else
      conn
    end
  end

  defp system_actor_scoped?(conn) do
    case conn.path_info do
      [prefix, first | _] when prefix in ["api", "internal-api"] ->
        first in @system_actor_path_segments

      _ ->
        false
    end
  end
end
