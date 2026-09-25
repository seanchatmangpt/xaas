defmodule Xaas.Ocel.ObjectStateDelta do
  @moduledoc """
  A real, append-only record of one attribute changing value on one object,
  optionally attributed to the event that caused it -- ticket scope item
  "object state delta", docs/jira/v26.9.11/object-centric-event-projection.md.

  Deliberately append-only (no `:update` action, only `:read`/`:destroy`
  defaults plus `:record_delta` create): the object's *current* state is
  always the fold of its deltas in `occurred_at` order, never a separately
  mutated column, so replaying deltas is the only way to reconstruct state
  -- consistent with the ticket's case-view-derivation invariant applied one
  level down, to object state instead of case membership.
  """

  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Ocel,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("ocel_object_state_deltas")
    repo(Xaas.Repo)
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read, :destroy])

    create :record_delta do
      description("Record one real attribute-value transition on an object.")

      accept([
        :object_id,
        :event_id,
        :attribute,
        :previous_value,
        :new_value,
        :occurred_at
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :attribute, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :previous_value, :string do
      public?(true)
    end

    attribute :new_value, :string do
      public?(true)
    end

    attribute :occurred_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :object, Xaas.Ocel.Object do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :event, Xaas.Ocel.Event do
      public?(true)
    end
  end
end
