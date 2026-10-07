defmodule Xaas.A2a.Task do
  @moduledoc """
  One A2A protocol task (`AshA2A.Protocol.Task` surface) bound to the agent
  that executes it via `agent_id` (the agent's card `name`).
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.A2a,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:agent_id, :string,
      allow_nil?: false,
      public?: true,
      description: "The executing agent's card name (`Xaas.A2a.Agent.name`)."
    )

    attribute(:task_id, :string, allow_nil?: false, public?: true)

    attribute(:status, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [one_of: [:submitted, :working, :completed, :failed, :input_required]],
      description: "A2A task state machine."
    )

    attribute(:context_id, :string, allow_nil?: false, public?: true)

    attribute(:artifacts, {:array, :map},
      allow_nil?: false,
      default: [],
      public?: true
    )

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_task_id, [:task_id], pre_check_with: Ash.DataLayer.Ets)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:agent_id, :task_id, :status, :context_id, :artifacts])
    end

    update :update do
      accept([:status, :artifacts])
      require_atomic?(false)
    end
  end
end
