defmodule Xaas.Ledger.Transfer do
  use Xaas.Resource,
    domain: Elixir.Xaas.Ledger,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshDoubleEntry.Transfer, AshEvents.Events]

  events do
    event_log Xaas.Ledger.EventLog
    current_action_versions transfer: 1
  end

  policies do
    # ash-migration Phase 5 (deny-by-default floor): real, confirmed gap --
    # this resource had zero policy blocks before this commit, meaning
    # implicit allow-all authorization on a repo with real deployed infra.
    # Replace with real per-action rules as domain owners define them; never
    # relax this to allow-all without an explicit rule.
    bypass action_type(:read) do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  transfer do
    account_resource Xaas.Ledger.Account
    balance_resource Xaas.Ledger.Balance
  end

  postgres do
    table "ledger_transfers"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :transfer do
      accept [:amount, :timestamp, :from_account_id, :to_account_id]
    end
  end

  attributes do
    attribute :id, AshDoubleEntry.ULID do
      primary_key? true
      allow_nil? false
      default &AshDoubleEntry.ULID.generate/0
    end

    attribute :amount, :money do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :from_account, Xaas.Ledger.Account do
      attribute_writable? true
    end

    belongs_to :to_account, Xaas.Ledger.Account do
      attribute_writable? true
    end

    has_many :balances, Xaas.Ledger.Balance
  end
end
