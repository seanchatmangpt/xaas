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

    # XAAS-2601: every internal-only mutation action this repo's Ultracode
    # Reactor pipeline calls (Reactor, EpochReactor, NextEpoch, MissedEpochs,
    # Changes.CreateFirstEpoch) is admitted by the REAL system authority
    # predicate -- `Xaas.Checks.SystemActor` over a `Xaas.SystemAuthority`
    # actor the pipeline now passes explicitly -- instead of the previous
    # action-wide `authorize_if(always())` bypasses, which any caller
    # through the normal authorization path satisfied. The deny floor
    # below stays real for every other actor, and any FUTURE action added
    # to this resource remains deny-by-default.
    bypass action([:create, :start, :complete, :mark_missed, :mark_failed]) do
      authorize_if({Xaas.Checks.SystemActor, []})
    end

    policy always() do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:run_id, :cycle, :exact_subject, :state, :expected_at, :started_at])
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
