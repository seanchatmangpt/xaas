defmodule Xaas.Billing.ApprovalTierDowngrade do
  @moduledoc """
  Real maker-checker approval resource for tier downgrade requests. Was a
  read-only skeleton (`defaults [:read]`, no mutation surface at all) --
  a prior pass added the real `:create`/`:approve` actions, following the
  established pattern in `Xaas.Billing.ApprovalPricingOverride` /
  `Xaas.Governance.ApprovalFreezeOverride`: `:create` is unauthenticated
  at the Ash-policy layer (real access control is the router-level
  `KanbanWeb.Plugs.RequireInternalApiToken` Bearer check ahead of every
  `/api` route), and `:approve` additionally runs
  `Xaas.Billing.Validations.ApprovalTierDowngradeRequiresApprover` -- `approved_by` must
  be present and must differ from `requested_by` (a second, distinct
  approver; no self-approval).

  ## Real fix (this pass) -- was wired but functionally dead

  Real, disclosed dead code found by the eleventh-pass ERRC grid sweep
  (`docs/claude/diataxis/explanation/errc-innovation-grid.md`): the
  resource had real `:create`/`:approve` routes and validation, but no
  `subscription_id`/`requested_tier` attributes at all -- there was no
  data on the record to say which subscription or which tier a "tier
  downgrade" even meant -- and its `Xaas.Billing.Changes.ApprovalTierDowngradeApprove`
  Change module was a byte-identical no-op, never even referenced by the
  `:approve` action. Approving a tier downgrade had zero real effect.

  This pass adds real `subscription_id` (a real `belongs_to`
  `Xaas.Billing.Subscription` FK) and `requested_tier` attributes, a real
  `Xaas.Billing.Validations.ApprovalTierDowngradeTargetsLowerTier`
  validation on `:create` (rejects a `requested_tier` that is not a real,
  strictly lower tier than the subscription's current tier), and wires
  the previously-dead `ApprovalTierDowngradeApprove` change into
  `:approve` with real logic: it drives `Xaas.Billing.Subscription`'s
  real, already-atomic `:change_tier` action
  (`lib/xaas/billing/subscription.ex:226-236`) with this record's own
  `requested_tier`, via `Ash.Changeset.after_action/2` so the approval
  write and the real tier-change (plus its own real prorated
  `Xaas.Ledger.Transfer` credit, `Xaas.Billing.Changes.SubscriptionProrateTierChange`)
  succeed or fail together -- matching this codebase's now-established
  atomic pattern (`ApprovalBackupRetentionChangeChargeOverage`,
  `SubscriptionProrateTierChange` itself).
  """
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  policies do
    # ash-migration Phase 5 (deny-by-default floor).
    bypass action_type(:read) do
      authorize_if always()
    end

    # Real, explicit per-action carve-out: `:create`/`:approve` are gated
    # the same way reads are -- by the router-level
    # KanbanWeb.Plugs.RequireInternalApiToken Bearer check -- plus
    # `:approve`'s own real validation
    # (`ApprovalTierDowngradeRequiresApprover`) rejecting a missing or
    # self-approving `approved_by`. Deliberate per-action carve-out, not
    # a blanket allow of every mutation.
    bypass action(:create) do
      authorize_if always()
    end

    bypass action(:approve) do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :approval_tier_downgrade
  end

  json_api do
    type "approval_tier_downgrade"

    routes do
      base "/approval_tier_downgrade"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_tier_downgrades"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:requested_by, :approved_by, :subscription_id, :requested_tier]
      validate Xaas.Billing.Validations.ApprovalTierDowngradeTargetsLowerTier
    end

    # Real mutation route: approve a pending tier downgrade request. Real
    # business rules:
    # `Xaas.Billing.Validations.ApprovalTierDowngradeRequiresApprover` --
    # `approved_by` must be present and must differ from `requested_by`
    # (a second, distinct approver). `Xaas.Billing.Changes.
    # ApprovalTierDowngradeApprove` (real logic, no longer the dead
    # no-op stub) then drives the real `Xaas.Billing.Subscription`
    # `:change_tier` action with `requested_tier`, atomically.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Billing.Validations.ApprovalTierDowngradeRequiresApprover
      change Xaas.Billing.Changes.ApprovalTierDowngradeApprove
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :requested_by, :string do
      allow_nil? false
      public? true
    end

    attribute :approved_by, :string do
      public? true
    end

    # Real target tier for the downgrade -- same enum shape (and same
    # real, disclosed placeholder pricing behind it via
    # `Xaas.Billing.Changes.SubscriptionProrateTierChange`) as
    # `Xaas.Billing.Subscription.tier` itself. Validated on `:create`
    # (`ApprovalTierDowngradeTargetsLowerTier`) to be strictly lower than
    # the subscription's real current tier.
    attribute :requested_tier, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:standard, :pro, :enterprise]
    end
  end

  relationships do
    # Real FK to the real subscription this downgrade targets -- the gap
    # the eleventh-pass grid found: without this, an approved downgrade
    # had no real subscription to apply itself to. `Xaas.Billing.Subscription`
    # is not multitenancy-wired (see its own moduledoc), so this is a
    # plain uuid FK, not an attribute-strategy tenant relationship like
    # `Xaas.Governance.ApprovalBackupRetentionChange`'s `belongs_to :org`.
    belongs_to :subscription, Xaas.Billing.Subscription do
      allow_nil? false
      public? true
    end
  end
end
