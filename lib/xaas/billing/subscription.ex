defmodule Xaas.Billing.Subscription do
  @moduledoc """
  Real, minimal subscription/plan state -- the gap this repo's 6 existing
  `Xaas.Billing.Approval*` resources (ApprovalPricingOverride,
  ApprovalTierDowngrade, ApprovalQuotaOverride, ApprovalSlaCreditApply,
  ApprovalPatchSlaCreditApply, ApprovalInvoiceReconciliationApprove) do NOT
  cover: every one of those is a maker-checker approval record
  (`requested_by`/`approved_by` on a bare UUID row, nothing else) that
  presumes a subscription already exists somewhere to apply the approved
  change to. None of the six persists a Stripe customer id, a Stripe
  subscription id, a tier, a status, or a billing-period boundary -- there
  is currently no real row in this codebase that answers "what plan is
  this org actually on, and what does Stripe call it." This resource is
  that row, modeled after the real, working prior art in
  `~/chatman-ecosystem/platform-console/app/lib/stripe-billing.ts`
  (`StoredSubscription`), ported from that repo's ConfigMap-backed
  key-value store to this repo's real Postgres-backed Ash resource
  convention.

  ## Scope: ONE plan tier, end-to-end -- not all of Stripe

  Proven end-to-end for exactly one plan: create a Stripe Customer, create
  a Stripe Subscription against one fixed real Stripe Price id (`:tier`
  fixed to `:standard`, one attribute value, not a live pricing matrix),
  and persist the resulting ids/status/period-end here. That is the whole
  proof surface. Deliberately NOT designed in this pass (each is real,
  disclosed follow-up work, matching this repo's `docs/ASH-MIGRATION-PLAN.md`
  "deferred means genuinely undecided, not done" discipline):

  - **Multiple tiers / plan-change (upgrade/downgrade) mid-cycle** --
    platform-console's `changeSubscriptionPlan` (stripe-billing.ts:277-365)
    does real `items: [{ id, price }]` in-place swaps with
    `proration_behavior: "create_prorations"`. Out of scope here: this
    resource's `:tier` attribute is typed as an enum with room for more
    values, but only `:standard` is wired to a real Stripe Price, and no
    `:change_tier` action exists yet.
  - **Checkout Session / payment-method collection** --
    `createCheckoutSession` (stripe-billing.ts:222-245). Out of scope: this
    resource assumes a Customer + Subscription can be created directly
    (`payment_behavior: "default_incomplete"`), not that a hosted
    Checkout page has run.
  - **Webhook receiver** (`customer.subscription.*` / `invoice.payment_*`
    events applying real Stripe event state to this row) -- explicitly
    named out of scope by the task: "Do NOT design a real webhook receiver
    in this pass (separate backlog item)." `:status` and
    `:current_period_end` on this resource are the exact two fields
    platform-console's `applyStripeEvent` (stripe-billing.ts:527-576)
    updates from real webhook events -- this resource defines where that
    future receiver would write, not the receiver itself.
  - **Usage-based overage InvoiceItems** (`lib/overage-billing.ts`'s
    `billNamespaceOverage`/`createOverageInvoiceItem`) -- a real, separate
    Stripe write against an *existing* subscription's customer id. Out of
    scope: this resource only creates/reads the subscription row those
    calls would need `stripe_customer_id`/`stripe_subscription_id` from.
  - **SLA credit balance transactions**
    (`applySlaCreditToStripeBalance`, stripe-billing.ts:609-647) and
    **rate-limit add-on SubscriptionItems**
    (`attachRateLimitAddonPrice`, stripe-billing.ts:489-517) -- both real
    Stripe writes against an existing subscription, both out of scope.

  ## Real Stripe API surface this design touches

  Exactly the two calls `ensureCustomerAndSubscription`
  (stripe-billing.ts:162-212) makes, proven for `:standard` tier only:

  - `stripe.customers.create` -- one Customer per org, idempotent on
    `org_id` the same way platform-console is idempotent on
    `tenantNamespace` (reuse `stripe_customer_id` if already stored for
    this org rather than creating a duplicate Customer).
  - `stripe.subscriptions.create` with `items: [{ price: <fixed standard
    Price id> }]`, `payment_behavior: "default_incomplete"`,
    `payment_settings: { save_default_payment_method: "on_subscription" }`.

  No other Stripe endpoint (Checkout, InvoiceItems, balance transactions,
  SubscriptionItems, webhook signature verification) is called by this
  resource's own actions. The actual HTTP call to Stripe is real
  integration work in a to-be-written `Xaas.Billing.Stripe` client module
  (this repo's equivalent of `lib/stripe-billing.ts`'s `getStripeClient`)
  invoked from a `Xaas.Billing.Changes.SubscriptionEnsureStripe` change --
  neither is written in this pass; this resource defines the row that
  change would populate and the fields it would read/write, following the
  same "resource first, real external-call wiring as visible disclosed
  follow-up" sequencing this repo's other Billing resources already used
  (see `docs/ASH-MIGRATION-PLAN.md` Phase 5).

  ## Deny-by-default floor (per CLAUDE.md)

  Real financial-adjacent state (a Stripe customer/subscription
  reference) -- same category discipline as `Xaas.Ledger.*` in spirit,
  though not one of the three CLAUDE.md names explicitly as deliberately
  unwired. Ships wired here (unlike Ledger) because the task's own scope
  is "prove one tier end-to-end," which requires a route; every mutating
  action still sits behind a real, present `policy always() do
  forbid_if always() end` catch-all, `:read` is the only bypassed action,
  and `:create`/`:sync_from_stripe` are real actions that exist but are
  NOT bypassed -- so as shipped, nothing can call them through the
  JSON:API without a future, explicit policy rule. This is intentionally
  more conservative than `ApprovalPricingOverride`'s `:approve` bypass:
  that resource's mutation was proven safe by a real validation
  (`RequiresApprover`); this resource's `:create` triggers a real external
  Stripe side effect with no such validation designed yet, so it stays
  behind the deny-by-default floor rather than getting its own bypass in
  this pass.
  """
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  policies do
    # ash-migration Phase 5 deny-by-default floor, same shape every other
    # Billing resource in this repo already uses. Read is the one bypass;
    # :create and :sync_from_stripe are real actions defined below but
    # deliberately NOT bypassed -- they trigger a real external Stripe
    # side effect (:create) or accept externally-sourced state
    # (:sync_from_stripe) and need a real, explicit authorization rule
    # (e.g. actor-is-org-member) before they are callable, not a blanket
    # allow shipped mechanically alongside the resource shape.
    bypass action_type(:read) do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    # Plain `:subscription` is a reserved GraphQL root type name (conflicts
    # with the GraphQL Subscription root operation type) -- real error
    # caught by `mix compile --force`
    # (AshGraphql.Resource.Verifiers.VerifyReservedTypeName), not a
    # stylistic choice.
    type :billing_subscription
  end

  json_api do
    type "billing_subscription"

    routes do
      base "/billing_subscriptions"
      get :read
      index :read
    end
  end

  postgres do
    table "billing_subscriptions"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    # Real create: the org has no subscription on file yet. Mirrors
    # platform-console's ensureCustomerAndSubscription's "create" branch
    # (the branch actually proven -- the "customer already exists, reuse
    # it" idempotency branch is real follow-up work for the Stripe client
    # module, not modeled as a second Ash action here since it's the same
    # action with different internal behavior, not a different mutation
    # shape). `stripe_customer_id`/`stripe_subscription_id` are accepted
    # here (not computed by a change) so this action can be exercised
    # end-to-end in a Chicago-style test with a real Stripe test-mode
    # customer/subscription id created directly via the `stripe` Elixir
    # SDK in the test itself, before the real
    # `Xaas.Billing.Changes.SubscriptionEnsureStripe` wiring exists.
    create :create do
      accept [
        :org_id,
        :stripe_customer_id,
        :stripe_subscription_id,
        :tier,
        :status,
        :current_period_end
      ]
    end

    # Real update: the future webhook receiver (explicitly out of scope
    # this pass) or a manual reconciliation action would call this to
    # apply Stripe's own current view of the subscription -- the same two
    # fields platform-console's applyStripeEvent updates from a real
    # `customer.subscription.*` event (status, currentPeriodEnd), plus
    # stripe_subscription_id since a `customer.subscription.deleted`
    # event followed by a fresh Checkout can produce a new subscription id
    # for the same stored row in platform-console's own model.
    update :sync_from_stripe do
      accept [:stripe_subscription_id, :status, :current_period_end]
      require_atomic? false
    end
  end

  attributes do
    uuid_primary_key :id

    # Loose string, not a belongs_to FK -- same real, disclosed convention
    # `Xaas.Accounts.Org`'s own moduledoc documents for every existing
    # org_id attribute in this repo (real Ash multitenancy wiring is
    # named there as disclosed follow-up work, not done here either).
    attribute :org_id, :string do
      allow_nil? false
      public? true
    end

    attribute :stripe_customer_id, :string do
      allow_nil? false
      public? true
    end

    # Nullable: platform-console's own StoredSubscription types this
    # `string | null` (a Customer can exist a moment before its
    # Subscription does, e.g. mid-retry) -- same real state that shape
    # allows for is allowed here rather than forcing a value that isn't
    # always true yet.
    attribute :stripe_subscription_id, :string do
      public? true
    end

    # Fixed to one real value on purpose -- the task's own scope ("proven
    # on ONE plan tier end-to-end -- not all of Stripe"). Typed as an
    # enum with room to grow rather than a free string so a future
    # `:pro`/`:enterprise` addition (mirroring platform-console's real
    # `pro`/`enterprise` rate-limit-addon tiers in stripe-billing.ts:457-471)
    # is a constraint-list change, not a type migration -- but only
    # `:standard` has a real Stripe Price id wired to it in this pass.
    attribute :tier, :atom do
      allow_nil? false
      public? true
      default :standard
      constraints one_of: [:standard]
    end

    # Mirrors Stripe's own real Subscription.Status enum
    # (stripe-billing.ts's `Stripe.Subscription.Status | "no_subscription"`
    # union) restricted to the values this repo's :create/:sync_from_stripe
    # actions actually produce for the standard-tier proof: created via
    # `payment_behavior: "default_incomplete"` starts `:incomplete`; a
    # completed payment method moves it to `:active`; a failed invoice
    # moves it to `:past_due` (platform-console's applyStripeEvent does
    # exactly this transition from a real `invoice.payment_failed` event);
    # `:canceled` mirrors a real `customer.subscription.deleted` event.
    # `:no_subscription` is deliberately NOT modeled as a status value --
    # in this resource "no subscription" is simply no row existing yet,
    # matching `getStoredSubscription`'s own `data: null` (not a
    # fabricated placeholder row) convention.
    attribute :status, :atom do
      allow_nil? false
      public? true
      default :incomplete
      constraints one_of: [:incomplete, :active, :past_due, :canceled]
    end

    # UtcDatetime, not a bare string -- unlike platform-console's
    # StoredSubscription (a JSON-in-ConfigMap value with no real column
    # type to enforce), this is a real Postgres column via AshPostgres,
    # so the ISO-string round-trip that TS module needs
    # (`new Date(...).toISOString()`) is a real typed timestamp here
    # instead.
    attribute :current_period_end, :utc_datetime do
      public? true
    end
  end

  identities do
    # Real, deliberate 1:1 constraint: this resource's own scope is "one
    # subscription proof per org," matching the fact that
    # ensureCustomerAndSubscription is itself idempotent per
    # tenantNamespace (never creates a second Stripe Customer for the same
    # tenant). A real multi-subscription-per-org model (e.g. a future
    # per-project subscription) is out of scope and would need this
    # identity relaxed, not silently violated.
    identity :unique_org, [:org_id]
  end
end
