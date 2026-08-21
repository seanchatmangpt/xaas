defmodule Xaas.Governance.ApprovalFreezeOverride do
  @moduledoc """
  Real emergency-override-during-a-freeze approval (maker-checker), a
  DIFFERENT real concept from `Xaas.Governance.FreezeWindow` (declaring a
  freeze period at all, matching platform-console's real
  `app/app/api/freeze-windows/route.ts` CRUD).

  This session found the two concepts had been conflated: this resource's
  name implies approving an emergency change DURING an active freeze, but
  it previously only had `requested_by`/`approved_by` fields and no real
  create/approve actions -- neither the override-approval flow nor the
  freeze-declaration flow was actually modeled. Resolution: keep this
  resource for the override-approval concept (matching the naming
  convention and maker-checker shape of the other 22 `Approval*`
  Governance resources), and add a separate `FreezeWindow` resource for
  the freeze-declaration concept that actually matches the real route.

  ## `freeze_window_id` reference validation (twenty-second-pass ERRC fix)

  `:create` accepts a caller-supplied `freeze_window_id` that was
  previously never validated against any real `Xaas.Governance.
  FreezeWindow` row. `Xaas.Governance.Validations.
  ApprovalFreezeOverrideFreezeWindowExists` now closes 3 real gaps:
  existence, cross-org integrity (the referenced window must belong to
  this request's own `org_id`), and the window's own
  `allow_emergency_override` flag must be `true`. See that module's
  moduledoc for the full real gap this closes. This is orthogonal to, and
  does not resolve, the separately-deferred actor-vs-request org-scoping
  question on this resource's own `policies do` bypasses (both `:create`
  and `:approve` remain on `authorize_if always()`, unchanged by this
  fix) -- see `docs/claude/diataxis/explanation/errc-innovation-grid.md`
  for that standing, disclosed deferral.
  """
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Governance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshPaperTrail.Resource]

  paper_trail do
    change_tracking_mode :full_diff
  end

  policies do
    # ash-migration Phase 5 (deny-by-default floor).
    bypass action_type(:read) do
      authorize_if always()
    end

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
    type :approval_freeze_override
  end

  json_api do
    type "approval_freeze_override"

    routes do
      base "/approval_freeze_override"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_freeze_overrides"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    # Real business rule lives in
    # Xaas.Governance.Validations.ApprovalFreezeOverrideFreezeWindowExists --
    # freeze_window_id must reference a real, same-org FreezeWindow row
    # whose own allow_emergency_override flag is true.
    create :create do
      accept [:org_id, :requested_by, :freeze_window_id, :reason]
      validate Xaas.Governance.Validations.ApprovalFreezeOverrideFreezeWindowExists
    end

    # Real mutation route: approve a pending emergency override of an
    # active freeze window. Real business rule lives in
    # Xaas.Governance.Validations.ApprovalFreezeOverrideRequiresApprover --
    # `approved_by` must be present and must differ from `requested_by`
    # (a second, distinct owner).
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalFreezeOverrideRequiresApprover
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :org_id, :string do
      allow_nil? false
      public? true
    end

    attribute :requested_by, :string do
      allow_nil? false
      public? true
    end

    attribute :approved_by, :string do
      public? true
    end

    # References the FreezeWindow being overridden. Kept as a plain
    # string id (not a belongs_to) to match this domain's existing
    # Governance resources, none of which cross-reference each other via
    # Ash relationships.
    attribute :freeze_window_id, :string do
      allow_nil? false
      public? true
    end

    attribute :reason, :string do
      allow_nil? false
      public? true
    end
  end
end
