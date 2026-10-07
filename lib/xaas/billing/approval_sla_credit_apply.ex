defmodule Xaas.Billing.ApprovalSlaCreditApply do
  @moduledoc """
  Real maker-checker approval resource for SLA credit application requests. Was a
  read-only skeleton (`defaults [:read]`, no mutation surface at all) --
  a prior pass added the real `:create`/`:approve` actions, following the
  established pattern in `Xaas.Billing.ApprovalPricingOverride` /
  `Xaas.Governance.ApprovalFreezeOverride`: `:create` is unauthenticated
  at the Ash-policy layer (real access control is the router-level
  `XaasWeb.Plugs.RequireInternalApiToken` Bearer check ahead of every
  `/api` route), and `:approve` additionally runs
  `Xaas.Billing.Validations.ApprovalSlaCreditApplyRequiresApprover` -- `approved_by` must
  be present and must differ from `requested_by` (a second, distinct
  approver; no self-approval).

  ## Real fix (sixteenth pass) -- the `:create`/`:approve` bypass had no
  per-org access control at all

  Real, live-HTTP-proven gap found by the sixteenth-pass ERRC grid sweep:
  the `:create`/`:approve` bypass was a bare `authorize_if always()` -- no
  org check at all -- and `XaasWeb.Plugs.ResolveOrgActor`'s hardcoded
  tenant-scoped path list didn't cover `approval_sla_credit_apply` either.
  A real, temporary (deleted-after-run) HTTP test proved live
  exploitability: an actor holding only the shared `INTERNAL_API_TOKEN`
  could `POST` a fabricated, never-authenticated `org_id` plus an
  arbitrary `credit_amount_cents`, then self-approve it as its own
  invented approver -- a real `Money.new(:USD, "9999.99")` landed in a
  real `Xaas.Ledger.Balance` row keyed to the fabricated org string. No
  existing victim record was even required.

  This pass adds `Xaas.Billing.Checks.SlaCreditActorOrgMatches` (see that
  module's own moduledoc for why it is a real, direct-attribute-read
  check -- this resource carries its own `org_id` attribute directly, no
  relation hop like `ApprovalTierDowngrade`'s check needed), wires it into
  `:create`/`:approve` in place of `authorize_if always()`, and adds
  `approval_sla_credit_apply` to `ResolveOrgActor`'s
  `@tenant_scoped_path_segments` so the route actually receives a resolved
  org actor instead of `nil`.
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
    # (`ApprovalSlaCreditApplyRequiresApprover`) rejecting a missing or
    # self-approving `approved_by`. Deliberate per-action carve-out, not
    # a blanket allow of every mutation.
    #
    # Updated sixteenth pass: no longer a bare `authorize_if always()` --
    # both now real-check `Xaas.Billing.Checks.SlaCreditActorOrgMatches`
    # (the actor's `X-Org-Id`-resolved org must match this record's real
    # `org_id`). See that module's moduledoc for why this is needed --
    # SPEC-07 lane W982p now adds the resource-level `multitenancy` block as
    # the data-layer backstop on top of this actor-identity check.
    bypass action(:create) do
      authorize_if(Xaas.Billing.Checks.SlaCreditActorOrgMatches)
    end

    bypass action(:approve) do
      authorize_if(Xaas.Billing.Checks.SlaCreditActorOrgMatches)
    end

    policy always() do
      forbid_if(always())
    end
  end

  json_api do
    type("approval_sla_credit_apply")

    routes do
      base("/approval_sla_credit_apply")
      get(:read)
      index(:read)
      post(:create)

      # WP-1 (OS-15, Art. 14(4)(b)): read-only causal-anatomy enrichment of
      # the operator approve response — the top-level `meta` member carries
      # the W505 Shapley attribution + W506 counterfactual trace + W984p
      # briefing for the decision being approved. Zero new authority: the
      # mutation path (policies, validations, Ledger change) is untouched.
      # See Xaas.Operations.ApprovalCausalAnatomy for the full rationale.
      patch(:approve,
        metadata: fn _subject, result, _request ->
          Xaas.Operations.ApprovalCausalAnatomy.metadata(result)
        end
      )
    end
  end

  postgres do
    table("approval_sla_credit_applies")
    repo(Xaas.Repo)
  end

  # SPEC-07 (W905 W729-GAP-3, lane W982p): real Ash attribute-strategy
  # multitenancy backstop, converging on the convention lane W970a landed on
  # the sibling approval resources (see approval_pricing_override.ex for the
  # full comment, including the Ash 3.34 update-path reason for
  # `global?(true)`). Tenant-less operations behave exactly as before
  # (org_id remains `allow_nil?(false)` and is explicitly accepted on
  # :create); any operation that DOES bind a tenant is hard-filtered to that
  # org's rows. The SlaCreditActorOrgMatches policy checks below stay
  # unchanged -- they gate actor identity at the policy layer, this block
  # backstops row isolation at the data layer. See
  # test/xaas/billing/billing_multitenancy_court_test.exs.
  multitenancy do
    strategy(:attribute)
    attribute(:org_id)
    global?(true)
  end

  actions do
    defaults([:read])

    create :create do
      accept([:requested_by, :approved_by, :org_id, :credit_amount_cents])
    end

    # Real mutation route: approve a pending SLA credit application request. Real
    # business rules:
    # - Xaas.Billing.Validations.ApprovalSlaCreditApplyRequiresApprover --
    #   `approved_by` must be present and must differ from `requested_by`
    #   (a second, distinct approver).
    # - Xaas.Billing.Changes.ApprovalSlaCreditApplyApprove -- real, NEW
    #   Ledger integration: on the request's real first `:approve`, a
    #   real Xaas.Ledger.Transfer credits `credit_amount_cents` from the
    #   dedicated `platform:revenue:sla-credits` account to the org's
    #   real Xaas.Ledger.Account. See that module's own moduledoc for the
    #   full disclosure (why a dedicated account, why after_transaction/2,
    #   idempotency).
    update :approve do
      accept([:approved_by])
      require_atomic?(false)

      # Real, DB-level idempotency guard (W746, gap 2 from
      # docs/sjira/v26.10.6/plans/w729-billing-deepening.md): only a row
      # whose PERSISTED approved_by is still nil may be approved. Unlike
      # the in-memory changeset.data reads downstream, this filter lands
      # in the UPDATE's WHERE clause (Ash.Changeset.filter/2), so a
      # repeat :approve through a stale in-memory record -- approved_by
      # still nil in the caller's struct, already set in Postgres --
      # matches zero rows and is refused typed (Ash.Error.Invalid with
      # NotFound) instead of double-crediting the org's Ledger account.
      # Same builtin `filter(expr(...))` change shape already used by
      # Xaas.Library.Book / Xaas.Library.HoldRequest / Xaas.Ultracode.Receipt.
      change(filter(expr(is_nil(approved_by))))
      change(Xaas.Billing.Changes.ApprovalSlaCreditApplyApprove)
      validate(Xaas.Billing.Validations.ApprovalSlaCreditApplyRequiresApprover)
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

    # Real, necessary addition beyond the prior read-only skeleton's
    # attribute set: crediting an org's Ledger.Account requires a real
    # org identifier. Plain string identifier (not a belongs_to FK), used
    # directly as the Xaas.Ledger.Account
    # `identifier` for the org's account, same convention
    # Xaas.Billing.Changes.SubscriptionChargeOnActivate and
    # Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage
    # already use for `record.org_id`.
    attribute :org_id, :string do
      allow_nil?(false)
      public?(true)
    end

    # Real, necessary addition: an SLA credit needs a real amount to
    # actually credit. `credit_amount_cents` is a real, disclosed
    # placeholder-shaped field (the caller supplies the real cents
    # amount at `:create` time; this resource does not itself compute
    # an SLA-breach-derived amount -- that pricing logic does not exist
    # yet and is out of scope for this pass). Integer cents, must be
    # positive.
    attribute :credit_amount_cents, :integer do
      allow_nil?(false)
      public?(true)
      constraints(min: 1)
    end
  end
end
