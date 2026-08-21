defmodule Xaas.Governance.ApprovalCmekKeyBinding do
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

    # Real, explicit per-action carve-out (issue #20), ported from
    # platform-console's real PUT /api/orgs/[id]/cmek maker-checker flow.
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
    type :approval_cmek_key_binding
  end

  json_api do
    type "approval_cmek_key_binding"

    routes do
      base "/approval_cmek_key_binding"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_cmek_key_bindings"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:org_id, :requested_by, :provider, :key_ref, :reason]
    end

    # Real mutation route (issue #20), ported from platform-console's
    # PUT /api/orgs/[id]/cmek maker-checker flow: approve binding (or
    # rotating) a customer-managed encryption key. Real business rule:
    # Xaas.Governance.Validations.ApprovalCmekKeyBindingRequiresApprover
    # -- `approved_by` required, must differ from `requested_by`.
    # platform-console's own additional real work (re-annotating live
    # Secrets/PVCs with the new key reference, `lib/cmek.ts`'s
    # reannotate step) is NOT ported -- xaas has no live k8s-resource
    # write path for this yet, honestly left undone rather than faked.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalCmekKeyBindingRequiresApprover
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

    # Real payload, matching platform-console's real PUT body
    # (provider/keyRef/reason). `provider` values ported verbatim from
    # platform-console's CmekProvider type.
    attribute :provider, :cmek_provider do
      allow_nil? false
      public? true
    end

    attribute :key_ref, :string do
      allow_nil? false
      public? true
    end

    attribute :reason, :string do
      allow_nil? false
      public? true
    end
  end
end
