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
