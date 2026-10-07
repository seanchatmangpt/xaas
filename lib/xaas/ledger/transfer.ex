defmodule Xaas.Ledger.Transfer do
  use Xaas.Resource,
    domain: Elixir.Xaas.Ledger,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshDoubleEntry.Transfer, AshEvents.Events]

  events do
    event_log(Xaas.Ledger.EventLog)
    current_action_versions(transfer: 1)
  end

  policies do
    # ash-migration Phase 5 (deny-by-default floor): real, confirmed gap --
    # this resource had zero policy blocks before this commit, meaning
    # implicit allow-all authorization on a repo with real deployed infra.
    # Replace with real per-action rules as domain owners define them; never
    # relax this to allow-all without an explicit rule.
    bypass action_type(:read) do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end

  transfer do
    account_resource(Xaas.Ledger.Account)
    balance_resource(Xaas.Ledger.Balance)
  end

  postgres do
    table("ledger_transfers")
    repo(Xaas.Repo)
  end

  actions do
    defaults([:read])

    create :transfer do
      accept([:amount, :timestamp, :from_account_id, :to_account_id])

      # W762: refuse over-balance transfers (W738 UNSUPPORTED(invariant-absent)).
      validate(Xaas.Ledger.Validations.TransferSourceSufficiency)
    end

    # W968c / SPEC-27 (W799-GAP-1): dedicated reversal action. The mechanism
    # is still the lawful compensating transfer (from/to swapped), but it is
    # now wrapped so double-reversal is a typed, reversal-aware refusal plus
    # a DB unique constraint (`reverses_transfer_id`), not an accident of the
    # org happening to be at zero balance. See
    # Xaas.Ledger.Changes.ReverseTransfer and
    # docs/sjira/v26.10.6/plans/w799-reversal-deepening.md.
    create :reverse do
      description("Mint the compensating transfer for a prior transfer (from/to swapped).")

      accept([])

      argument :transfer_id, AshDoubleEntry.ULID do
        allow_nil?(false)
        public?(true)
      end

      validate(Xaas.Ledger.Validations.TransferSourceSufficiency)

      change(Xaas.Ledger.Changes.ReverseTransfer)
    end
  end

  attributes do
    attribute :id, AshDoubleEntry.ULID do
      primary_key?(true)
      allow_nil?(false)
      default(&AshDoubleEntry.ULID.generate/0)
    end

    attribute :amount, :money do
      allow_nil?(false)
    end

    # W968c / SPEC-27: set only by the `:reverse` action (not in any accept
    # list); unique index backstops double-reversal at the DB layer.
    attribute :reverses_transfer_id, AshDoubleEntry.ULID do
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :from_account, Xaas.Ledger.Account do
      attribute_writable?(true)
    end

    belongs_to :to_account, Xaas.Ledger.Account do
      attribute_writable?(true)
    end

    has_many :balances, Xaas.Ledger.Balance
  end

  identities do
    # W968c / SPEC-27: at most one compensating transfer per reversed
    # transfer; NULLs (ordinary transfers) are distinct in Postgres.
    identity(:unique_reversal, [:reverses_transfer_id])
  end
end
