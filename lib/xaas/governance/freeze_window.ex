defmodule Xaas.Governance.FreezeWindow do
  @moduledoc """
  Real "declare a change-freeze window" resource, ported from
  platform-console's real
  `app/app/api/freeze-windows/route.ts` + `lib/freeze-windows.ts` CRUD
  (SOC2 CC8 / ITIL change management). This is a DIFFERENT real concept
  from `Xaas.Governance.ApprovalFreezeOverride` (approving an emergency
  override DURING an active freeze) -- see that resource's moduledoc for
  the concept-mismatch this session found and how it was resolved.

  platform-console's route has no maker-checker approval step of its
  own: any org owner can create or delete a freeze window outright (its
  auth boundary is `requireRoleIn(..., "owner")` at the app layer, not a
  separate approval action), so this resource has real `:create` and
  `:destroy` actions only -- no `:approve`.

  ## AshIam read bypass -- extended pilot (2nd of 2 new resources this pass)

  Freeze windows are real per-org change-management data (`org_id`,
  `starts_at`/`ends_at`, `reason`) with a real, sensible reason to be
  IAM-scoped: one org's change-freeze schedule is not something another
  org has any business reading, the same real per-org-visibility argument
  as `Xaas.Accounts.Org`/`Xaas.Billing.Subscription`/
  `Xaas.Marketplace.Provider`'s own pilots. `:read` now bypasses the
  catch-all via `bypass action_type(:read) do authorize_if AshIam.Check
  end`, the same construct as those three (a plain `policy` here would AND
  against the trailing `policy always() do forbid_if always() end`
  catch-all and silently deny every read regardless of `AshIam.Check`'s
  result -- see `Xaas.Accounts.Org`'s moduledoc for the real `{:ok, []}`
  bug this was found from). This replaces the previous `bypass
  action_type(:read) do authorize_if always() end` (open read to any
  actor) -- a real behavior change: reads are now IAM-gated, not
  unconditionally allowed.

  `:create`/`:destroy` are deliberately left on their existing
  `authorize_if always()` bypasses, unchanged -- `AshIam.Check` is not
  wired to them (same real, disclosed limitation as the other 3 pilots:
  this repo's `ash_iam` version real-tests as broken on non-read/filter-
  type checks against create/update-shaped actions).
  """
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Governance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshPaperTrail.Resource, AshIam]

  paper_trail do
    change_tracking_mode :full_diff
  end

  iam do
    permission_base "xaas:freeze_window"
    action_to_iam_mapping create: :create, read: :read
  end

  policies do
    # Real IAM-gated read, same real, hard-won pattern as the other 3
    # pilots (see moduledoc). Replaces the previous open
    # `authorize_if always()` read bypass.
    bypass action_type(:read) do
      authorize_if AshIam.Check
    end

    bypass action(:create) do
      authorize_if always()
    end

    bypass action(:destroy) do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :freeze_window
  end

  json_api do
    type "freeze_window"

    routes do
      base "/freeze_window"
      get :read
      index :read
      post :create
      delete :destroy
    end
  end

  postgres do
    table "freeze_windows"
    repo Xaas.Repo
  end

  actions do
    defaults [:read, :destroy]

    # Real payload, matching platform-console's real POST body
    # (orgId/startsAt/endsAt/reason/allowEmergencyOverride, createdBy set
    # from the session actor server-side).
    create :create do
      accept [:org_id, :starts_at, :ends_at, :reason, :allow_emergency_override, :created_by]
      validate Xaas.Governance.Validations.FreezeWindowEndsAfterStarts
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :org_id, :string do
      allow_nil? false
      public? true
    end

    attribute :starts_at, :utc_datetime do
      allow_nil? false
      public? true
    end

    attribute :ends_at, :utc_datetime do
      allow_nil? false
      public? true
    end

    attribute :reason, :string do
      allow_nil? false
      public? true
    end

    # Mirrors platform-console's real `allowEmergencyOverride` flag
    # (`body?.allowEmergencyOverride === true`, defaults false): whether a
    # maker-checker `Xaas.Governance.ApprovalFreezeOverride` request may
    # be filed against this window at all.
    attribute :allow_emergency_override, :boolean do
      allow_nil? false
      default false
      public? true
    end

    attribute :created_by, :string do
      allow_nil? false
      public? true
    end
  end
end
