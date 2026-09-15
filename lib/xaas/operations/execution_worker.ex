defmodule Xaas.Operations.ExecutionWorker do
  @moduledoc """
  Ash resource representing one leased execution worker on an admitted
  actuation provider (ZCode, OpenCode, ...).

  A worker row is durable provider topology evidence, not authority: it
  records what the provider observed (sessions, heartbeats, capability
  advertisement) and what lease it currently holds. Claiming work goes
  through `Xaas.Execution.claim_next/2`, which is the only writer of the
  lease binding on `Xaas.Operations.WorkContract`.

  Standing vocabulary for `state` mirrors the fabric lifecycle:
  available | claiming | leased | running | verifying | accepted | replan |
  refused | lost | throttled.
  """

  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Operations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  policies do
    policy always() do
      forbid_if(always())
    end
  end

  postgres do
    table("execution_workers")
    repo(Xaas.Repo)
  end

  identities do
    identity :unique_provider_worker, [:provider, :provider_worker_id]
  end

  actions do
    read :read do
      primary?(true)
      public?(false)
    end

    create :register do
      public?(false)

      accept([
        :provider,
        :provider_worker_id,
        :provider_session_id,
        :repository,
        :worktree,
        :model_class,
        :quota_lane,
        :capabilities
      ])

      upsert?(true)
      upsert_identity(:unique_provider_worker)
      upsert_fields([
        :provider_session_id,
        :repository,
        :worktree,
        :model_class,
        :quota_lane,
        :capabilities
      ])

      change(set_attribute(:state, :available))
    end

    update :heartbeat do
      public?(false)
      accept([:provider_session_id])
      change(set_attribute(:last_heartbeat_at, &DateTime.utc_now/0))
      require_atomic?(false)
    end

    update :transition do
      public?(false)
      accept([:state])
      require_atomic?(false)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :provider, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :provider_worker_id, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :provider_session_id, :string do
      public?(true)
    end

    attribute :repository, :string do
      public?(true)
    end

    attribute :worktree, :string do
      public?(true)
    end

    attribute :model_class, :string do
      public?(true)
    end

    attribute :quota_lane, :atom do
      constraints one_of: [:free_idle, :scarce_flash, :scarce_frontier]
      public?(true)
    end

    attribute :state, :atom do
      constraints one_of: [
                    :available,
                    :claiming,
                    :leased,
                    :running,
                    :verifying,
                    :accepted,
                    :replan,
                    :refused,
                    :lost,
                    :throttled
                  ]
      public?(true)
    end

    attribute :capabilities, :map do
      public?(true)
    end

    attribute :last_heartbeat_at, :utc_datetime do
      public?(true)
    end

    attribute :lease_expires_at, :utc_datetime do
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    has_many :work_contracts, Xaas.Operations.WorkContract do
      destination_attribute(:execution_worker_id)
      public?(true)
    end
  end
end
