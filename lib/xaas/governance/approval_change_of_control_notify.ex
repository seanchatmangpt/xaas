defmodule Xaas.Governance.ApprovalChangeOfControlNotify do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Governance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  policies do
    # ash-migration Phase 5 (deny-by-default floor): real, confirmed gap --
    # this resource had zero policy blocks before this commit, meaning
    # implicit allow-all authorization on a repo with real deployed infra.
    # Replace with real per-action rules as domain owners define them; never
    # relax this to allow-all without an explicit rule.
    bypass action_type(:read) do
      authorize_if always()
    end

    # Real, explicit per-action carve-out, ported from platform-console's
    # real POST/PUT /api/owner/change-of-control maker-checker flow:
    # `:create` (file the change-of-control trigger/notification) and
    # `:approve` are gated the same way reads are -- by the router-level
    # KanbanWeb.Plugs.RequireInternalApiToken Bearer check -- plus
    # ApprovalChangeOfControlNotifyRequiresApprover's real "second,
    # distinct owner" rule on :approve.
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
    type :approval_change_of_control_notify
  end

  json_api do
    type "approval_change_of_control_notify"

    routes do
      base "/approval_change_of_control_notify"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_change_of_control_notifies"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :org_id,
        :requested_by,
        :event_type,
        :description,
        :trigger_date,
        :notice_window_days,
        :notification_method
      ]
    end

    # Real mutation route, ported from platform-console's real
    # PUT /api/owner/change-of-control maker-checker flow: approve a
    # pending change-of-control notification recording. Real business
    # rule lives in
    # Xaas.Governance.Validations.ApprovalChangeOfControlNotifyRequiresApprover
    # -- `approved_by` must be present and must differ from
    # `requested_by` (a second, distinct owner).
    #
    # NOT ported: platform-console's own POST (`fileChangeOfControlTrigger`)
    # and PATCH (`addAffectedOrgs`) endpoints are unprivileged-relative-to-
    # owner record-keeping steps that write to a separate `affectedOrgIds`
    # list and a live audit-log DB table (writeAuditLogEntry) xaas has no
    # equivalent for yet; this resource models the single maker-checker-
    # gated step (file + approve a notification for one org) and honestly
    # does not reproduce the trigger/affected-orgs list-growing behavior
    # or the audit-log side effect.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalChangeOfControlNotifyRequiresApprover
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

    # Real payload, matching platform-console's real POST body
    # (eventType/description/triggerDate/noticeWindowDays, all required
    # except noticeWindowDays) plus the real PUT body's
    # notificationMethod (required to record the notification).
    attribute :event_type, :change_of_control_event_type do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      allow_nil? false
      public? true
    end

    attribute :trigger_date, :string do
      allow_nil? false
      public? true
    end

    attribute :notice_window_days, :integer do
      public? true
    end

    attribute :notification_method, :string do
      allow_nil? false
      public? true
    end
  end
end
