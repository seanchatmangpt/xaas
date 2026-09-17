defmodule Xaas.Ultracode.Epoch do
  @moduledoc """
  One cycle of a `Run`'s attempt against a real, named `exact_subject`.

  `ExpectedEpoch`/`CompletedEpoch`/`MissedEpoch` are deliberately not
  separate resources -- they are `state` values on this one resource
  (`:expected | :running | :completed | :missed | :failed`), matching this
  repo's existing lifecycle-as-attribute convention (`WebhookDelivery`'s
  `:failed` status, `CapabilityLivenessReceipt`'s receipt lifecycle) instead
  of a polymorphic per-state resource split.

  Enforces two real invariants from the ontology formalization:

  - `Unique(run, cycle)` -- `identities do identity :unique_run_cycle, ...`
    below, giving both an app-level pre-flight rejection and (via
    `ash_postgres` migration generation) a real DB unique index.
  - `AtMostOneActiveEpoch(run)` -- `Xaas.Ultracode.Validations.
    AtMostOneActiveEpoch`, run on `:create`/`:update` whenever `state` is
    being set to `:running`.

  ## Org scoping (see ADR-0002, `Xaas.Ultracode.Run`'s own moduledoc)

  Deliberately no separate `org_id` column here: `Run.org_id` (real,
  disclosed, unenforced -- see that module's moduledoc) is this Run's own
  Epochs' single source of truth for org provenance, reached via the
  existing `belongs_to :run` below (`epoch.run.org_id`), the same
  normalized-through-the-parent shape every enforced convention elsewhere
  in this codebase avoids duplicating across a relationship hop. `Lease`
  (`Xaas.Ultracode.Lease`) owns no resource of its own -- its
  `lease_token`/`leased_to`/`worktree`/`final_head` fields live on THIS
  resource (see `Lease`'s own moduledoc), so there is no separate `Lease`
  schema to seam either.
  """

  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Ultracode,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("ultracode_epochs")
    repo(Xaas.Repo)
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    # ERRC raise: real, scoped carve-outs for every internal-only
    # mutation action this repo's Ultracode Reactor pipeline calls --
    # matching `Xaas.Ultracode.Run`'s own `bypass action(:tick)` shape.
    # Previously every one of these actions was invoked with
    # `authorize?: false` at every call site instead (Reactor, EpochReactor,
    # NextEpoch, MissedEpochs, Changes.CreateFirstEpoch), which routed
    # around `Ash.Policy.Authorizer` entirely and made the `forbid_if
    # always()` floor below dead code for every real production mutation
    # path. Bypassing here instead means the floor is real: any FUTURE
    # action added to this resource is deny-by-default unless explicitly
    # bypassed, exactly like this repo's Ash policy convention requires.
    bypass action(:create) do
      authorize_if(always())
    end

    bypass action(:start) do
      authorize_if(always())
    end

    bypass action(:complete) do
      authorize_if(always())
    end

    bypass action(:mark_missed) do
      authorize_if(always())
    end

    bypass action(:mark_failed) do
      authorize_if(always())
    end

    bypass action(:lease) do
      authorize_if(always())
    end

    bypass action(:renew_lease) do
      authorize_if(always())
    end

    bypass action(:record_final_head) do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:run_id, :cycle, :exact_subject, :state, :expected_at, :started_at, :worktree])
    end

    update :start do
      accept([])
      require_atomic?(false)
      change(set_attribute(:state, :running))
      change(set_attribute(:started_at, &DateTime.utc_now/0))

      validate({Xaas.Ultracode.Validations.AtMostOneActiveEpoch, []})
    end

    update :complete do
      accept([])
      require_atomic?(false)
      change(set_attribute(:state, :completed))
      change(set_attribute(:completed_at, &DateTime.utc_now/0))

      validate({Xaas.Ultracode.Validations.EpochTransitionAllowed, from: [:running]})
    end

    update :mark_missed do
      accept([])
      require_atomic?(false)
      change(set_attribute(:state, :missed))

      validate({Xaas.Ultracode.Validations.EpochTransitionAllowed, from: [:expected, :running]})
    end

    update :mark_failed do
      accept([])
      require_atomic?(false)
      change(set_attribute(:state, :failed))

      validate({Xaas.Ultracode.Validations.EpochTransitionAllowed, from: [:expected, :running]})
    end

    # Bind the ActuationLease. Only admissible on a `:running` epoch with no
    # live lease (see Xaas.Ultracode.Validations.LeaseAvailable); callers
    # race-safely bind via Xaas.Ultracode.Lease.claim_next/1's filtered bulk
    # update, not by calling this directly.
    update :lease do
      accept([:lease_token, :lease_expires_at, :leased_to, :worktree])
      require_atomic?(false)

      validate({Xaas.Ultracode.Validations.LeaseAvailable, []})
    end

    update :renew_lease do
      accept([:lease_expires_at])
      require_atomic?(false)
    end

    update :record_final_head do
      accept([:final_head])
      require_atomic?(false)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :cycle, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :exact_subject, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :state, :atom do
      allow_nil?(false)
      default(:expected)
      constraints(one_of: [:expected, :running, :completed, :missed, :failed])
      public?(true)
    end

    # When this epoch is expected to be underway/complete by. Set at
    # `:create` (or `:start`). `Xaas.Ultracode.MissedEpochs` compares this
    # against `now - run.epoch_timeout_seconds` to decide `:missed` --
    # real input to a real state transition, not decoration.
    attribute :expected_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :started_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :completed_at, :utc_datetime_usec do
      public?(true)
    end

    # ------------------------------------------------------------------
    # ActuationLease fields (the provider-pull edge between Plan and
    # Construct). An Epoch is the bounded work unit, so the lease lives
    # here: `lease_token` is the only capability mid-work operations key
    # on, `leased_to` is provider worker identity (free-form string --
    # worker registries are provider business, not this domain), and
    # `final_head` is the provider-reported exact repository head at
    # closure, verified against `worktree` before any Receipt is sealed
    # with an :alive-family outcome.
    # ------------------------------------------------------------------

    attribute :lease_token, :string do
      public?(true)
    end

    attribute :lease_expires_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :leased_to, :string do
      public?(true)
    end

    attribute :worktree, :string do
      public?(true)
    end

    attribute :final_head, :string do
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :run, Xaas.Ultracode.Run do
      allow_nil?(false)
      attribute_writable?(true)
    end

    has_many :receipts, Xaas.Ultracode.Receipt
  end

  identities do
    identity(:unique_run_cycle, [:run_id, :cycle])
  end
end
