defmodule Xaas.Governance.ApprovalEnvironmentPromote do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Governance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshStateMachine]

  policies do
    # ash-migration Phase 5 (deny-by-default floor): real, confirmed gap --
    # this resource had zero policy blocks before this commit, meaning
    # implicit allow-all authorization on a repo with real deployed infra.
    # Replace with real per-action rules as domain owners define them; never
    # relax this to allow-all without an explicit rule.
    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :approval_environment_promote
  end

  json_api do
    type "approval_environment_promote"
  end

  postgres do
    table "approval_environment_promotes"
    repo Xaas.Repo
  end

  state_machine do
    initial_states([:pending])
    default_initial_state(:pending)
    state_attribute(:status)

    transitions do
      transition(:approve, from: :pending, to: :approved)
      transition(:reject, from: :pending, to: :rejected)
    end
  end

  actions do
    defaults [:read]

    create :request do
      accept [:requested_by]
    end

    update :approve do
      accept [:approved_by]
      require_atomic? false
      change transition_state(:approved)
    end

    update :reject do
      require_atomic? false
      change transition_state(:rejected)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :requested_by, :string do
      allow_nil? false
    end

    attribute :approved_by, :string
  end
end
