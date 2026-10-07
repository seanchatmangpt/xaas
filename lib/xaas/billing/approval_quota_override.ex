defmodule Xaas.Billing.ApprovalQuotaOverride do
  @moduledoc """
  Real maker-checker approval resource for quota override requests. Was a
  read-only skeleton (`defaults [:read]`, no mutation surface at all) --
  this pass adds the real `:create`/`:approve` actions, following the
  established pattern in `Xaas.Billing.ApprovalPricingOverride` /
  `Xaas.Governance.ApprovalFreezeOverride`: `:create` is unauthenticated
  at the Ash-policy layer (real access control is the router-level
  `XaasWeb.Plugs.RequireInternalApiToken` Bearer check ahead of every
  `/api` route), and `:approve` additionally runs
  `Xaas.Billing.Validations.ApprovalQuotaOverrideRequiresApprover` -- `approved_by` must
  be present and must differ from `requested_by` (a second, distinct
  approver; no self-approval).
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  policies do
    # ash-migration Phase 5 (deny-by-default floor).
    bypass action_type(:read) do
      authorize_if(always())
    end

    # Real, explicit per-action carve-out: `:create`/`:approve` are gated
    # the same way reads are -- by the router-level
    # XaasWeb.Plugs.RequireInternalApiToken Bearer check -- plus
    # `:approve`'s own real validation
    # (`ApprovalQuotaOverrideRequiresApprover`) rejecting a missing or
    # self-approving `approved_by`. Deliberate per-action carve-out, not
    # a blanket allow of every mutation.
    bypass action(:create) do
      # XAAS-2602: real system-authority predicate replaces the bare
      # always() -- XaasWeb.Plugs.SetInternalApiSystemActor supplies the
      # Xaas.SystemAuthority.new(:internal_api) actor AFTER the
      # RequireInternalApiToken Bearer check (HTTP gate unchanged), so the
      # action no longer authorizes literally any other actor/path.
      authorize_if({Xaas.Checks.SystemActor, []})
    end

    bypass action(:approve) do
      # XAAS-2602: real system-authority predicate replaces the bare
      # always() -- XaasWeb.Plugs.SetInternalApiSystemActor supplies the
      # Xaas.SystemAuthority.new(:internal_api) actor AFTER the
      # RequireInternalApiToken Bearer check (HTTP gate unchanged), so the
      # action no longer authorizes literally any other actor/path.
      authorize_if({Xaas.Checks.SystemActor, []})
    end

    policy always() do
      forbid_if(always())
    end
  end

  json_api do
    type("approval_quota_override")

    routes do
      base("/approval_quota_override")
      get(:read)
      index(:read)
      post(:create)
      patch(:approve)
    end
  end

  postgres do
    table("approval_quota_overrides")
    repo(Xaas.Repo)
  end

  # SPEC-07 (W905 W729-GAP-3, lane W970a): real Ash attribute-strategy
  # multitenancy backstop, converging on the convention lane W975b landed
  # on the sibling Xaas.Billing resources (subscription, sla_credit_apply,
  # patch_sla_credit_apply, revenue_recognition): `global?(true)` because
  # every existing caller runs tenant-less today AND because Ash 3.34's
  # update path (Ash.Actions.Update.set_tenant/1) enforces tenant presence
  # from the RESOURCE flag regardless of per-action `:allow_global` -- so
  # resource-level global? is the only shape that keeps every existing
  # tenant-less mutation working. Tenant-less operations behave exactly as
  # before; any operation that DOES bind a tenant is hard-filtered to that
  # org's rows -- the isolation backstop W729 disclosed. See
  # test/xaas/billing/billing_multitenancy_court_test.exs.
  multitenancy do
    strategy(:attribute)
    attribute(:org_id)
    global?(true)
  end

  actions do
    defaults([:read])

    create :create do
      accept([:requested_by, :approved_by, :org_id])
    end

    # Real mutation route: approve a pending quota override request. Real
    # business rule lives in
    # Xaas.Billing.Validations.ApprovalQuotaOverrideRequiresApprover --
    # `approved_by` must be present and must differ from `requested_by`
    # (a second, distinct approver).
    update :approve do
      accept([:approved_by])

      # Real, DB-level idempotency guard (W984k, gap 1b from
      # docs/sjira/v26.10.6/plans/w982s-approval-deepening.md): only a row
      # whose PERSISTED approved_by is still nil may be approved. The
      # filter lands in the UPDATE's WHERE clause, so a repeat :approve
      # through a stale record matches zero rows and is refused typed.
      # Same shape as ApprovalSlaCreditApply (W746).
      change(filter(expr(is_nil(approved_by))))
      validate(Xaas.Billing.Validations.ApprovalQuotaOverrideRequiresApprover)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :requested_by, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :approved_by, :string do
      public?(true)
    end

    # SPEC-07: tenant attribute backing the `multitenancy` block above.
    # Nullable by design: rows minted without a tenant stay global rows
    # (nil org_id matches global reads); a supplied tenant stamps it.
    attribute :org_id, :string do
      public?(true)
    end
  end
end
