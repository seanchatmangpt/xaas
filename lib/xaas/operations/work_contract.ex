defmodule Xaas.Operations.WorkContract do
  @moduledoc """
  Ash resource representing one semantic unit of engineering work offered to
  the execution fabric.

  The contract is the pull payload a provider worker receives on claim:
  repository + exact base SHA, goal, acceptance, verifier, falsifiers,
  authority ceiling, and quota lane. It is SELECT/PLAN output, never DO
  authority — the lease binding written at claim time grants bounded
  construction authority inside one worktree and expires; consequence
  semantics stay behind `Xaas.Actuation`/`Xaas.Operations.ActuationIntent`.

  `state` vocabulary: pending | claimed | verifying | closed | refused |
  expired. `standing` records the typed evidence standing at closure
  (ALIVE | PARTIAL_ALIVE | BLOCKED | BUILD_BROKEN | REFUSED_* | UNKNOWN |
  UNSUPPORTED).
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
    table("work_contracts")
    repo(Xaas.Repo)

    references do
      reference(:execution_worker, on_delete: :nilify)
    end
  end

  identities do
    identity :unique_work_id, [:work_id]
  end

  actions do
    read :read do
      primary?(true)
      public?(false)
    end

    create :submit do
      public?(false)

      accept([
        :work_id,
        :repository,
        :base_sha,
        :worktree,
        :goal,
        :acceptance,
        :verifier,
        :falsifiers,
        :authority_ceiling,
        :quota_lane
      ])

      change(set_attribute(:state, :pending))

      validate(present(:goal))
      validate(string_length(:base_sha, min: 7, max: 64))
    end

    update :claim do
      public?(false)
      accept([:lease_token, :lease_expires_at, :execution_worker_id])
      require_atomic?(false)

      change(set_attribute(:state, :claimed))
    end

    update :heartbeat_lease do
      public?(false)
      accept([])
      require_atomic?(false)
    end

    update :transition do
      public?(false)
      accept([:state])
      require_atomic?(false)
    end

    update :close do
      public?(false)
      accept([:final_head, :standing])
      require_atomic?(false)

      change(set_attribute(:state, :closed))
    end

    update :refuse do
      public?(false)
      accept([:standing])
      require_atomic?(false)

      change(set_attribute(:state, :refused))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :work_id, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :repository, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :base_sha, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :worktree, :string do
      public?(true)
    end

    attribute :goal, :string do
      public?(true)
    end

    attribute :acceptance, :map do
      public?(true)
    end

    attribute :verifier, :map do
      public?(true)
    end

    attribute :falsifiers, :map do
      public?(true)
    end

    attribute :authority_ceiling, :string do
      public?(true)
    end

    attribute :quota_lane, :atom do
      constraints one_of: [:free_idle, :scarce_flash, :scarce_frontier]
      public?(true)
    end

    attribute :state, :atom do
      constraints one_of: [:pending, :claimed, :verifying, :closed, :refused, :expired]
      public?(true)
    end

    attribute :lease_token, :string do
      public?(true)
    end

    attribute :lease_expires_at, :utc_datetime do
      public?(true)
    end

    attribute :final_head, :string do
      public?(true)
    end

    attribute :standing, :string do
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :execution_worker, Xaas.Operations.ExecutionWorker do
      allow_nil?(true)
      public?(true)
    end
  end
end
