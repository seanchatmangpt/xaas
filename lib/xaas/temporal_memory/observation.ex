defmodule Xaas.TemporalMemory.Observation do
  @moduledoc """
  A single bitemporal event: one fact about `{subject_type, subject_id}`,
  true over a valid-time interval (`valid_from`..`valid_to`), recorded at a
  fixed observation/transaction time (`observed_at`).

  Bitemporal event model (ticket scope item 1) with the two time axes kept
  as independent, separately-queryable attributes (scope items 2-3):

  - `valid_from`/`valid_to` -- when the fact was true *in the world*
    (`t_v`). `valid_to: nil` means "still valid, open-ended".
  - `observed_at` -- when the system *learned* the fact (`t_o`). Always
    server-set to `DateTime.utc_now/0` at admission time, never accepted
    from the caller, so it honestly reflects when this row entered the
    system rather than a claimed value.

  Rows are structurally immutable: only `:observe` and `:supersede` create
  actions exist, no `:update` action is defined, so a correction can only
  ever be represented as a *new* row (scope item 7, correction/supersession
  semantics) -- the falsifier "a correction silently overwrites the
  original record" is defeated by construction, not by convention.

  `receipt_hash` (scope item 10) is a deterministic SHA-256 over the
  canonical bitemporal fields, so any attempted mutation of a persisted row
  (this schema has no update path for it, but a future one, or a direct SQL
  edit, would) is independently detectable by recomputing the hash and
  comparing.

  See `Xaas.TemporalMemory.Query` (scope items 4, 5, 8) and
  `Xaas.TemporalMemory.Replay` (scope item 9) for the historical
  reconstruction / replay-verification surface built on top of this
  resource.
  """

  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.TemporalMemory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("temporal_memory_observations")
    repo(Xaas.Repo)
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  actions do
    read :read do
      primary?(true)
      public?(false)
    end

    create :observe do
      public?(true)

      accept([
        :subject_type,
        :subject_id,
        :fact,
        :valid_from,
        :valid_to,
        :supersedes_id
      ])

      change(set_attribute(:observed_at, &DateTime.utc_now/0))
      change(Xaas.TemporalMemory.Changes.ComputeReceiptHash)
    end

    create :supersede do
      public?(true)

      accept([
        :subject_type,
        :subject_id,
        :fact,
        :valid_from,
        :valid_to,
        :supersedes_id
      ])

      validate(present(:supersedes_id),
        message: "supersede requires :supersedes_id -- use :observe for a first-time fact"
      )

      change(set_attribute(:observed_at, &DateTime.utc_now/0))
      change(Xaas.TemporalMemory.Changes.ComputeReceiptHash)
      change(Xaas.TemporalMemory.Changes.MarkPriorSuperseded)
    end

    update :mark_superseded_by do
      public?(false)
      require_atomic?(false)
      accept([:superseded_by_id])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :subject_type, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :subject_id, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :fact, :map do
      allow_nil?(false)
      default(%{})
      public?(true)
    end

    attribute :valid_from, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
    end

    attribute :valid_to, :utc_datetime_usec do
      public?(true)
    end

    attribute :observed_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
    end

    attribute :supersedes_id, :uuid do
      public?(true)
    end

    attribute :superseded_by_id, :uuid do
      public?(true)
    end

    attribute :receipt_hash, :string do
      allow_nil?(false)
      public?(true)
    end

    create_timestamp(:inserted_at)
  end

  identities do
    identity(:unique_receipt_hash, [:receipt_hash])
  end
end
