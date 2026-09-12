defmodule Xaas.Ocel.Event do
  @moduledoc """
  A typed OCEL (Object-Centric Event Log) event.

  Ticket: docs/jira/v26.9.11/object-centric-event-projection.md, key
  invariant: "An event relates to a set of objects, not a single case:
  `event -> {o_1, ..., o_n}`".

  The real, concrete admission path enforcing that invariant lives on the
  `:record` create action below: it requires a non-empty `:object_ids`
  argument and, in an `after_action/2` hook (same transaction, per this
  repo's established `after_action` convention -- see
  `lib/xaas/library/changes/increment_book_inventory.ex`), creates one
  `Xaas.Ocel.EventObject` join row per object. An event created with zero
  objects is refused before any row is written -- see
  `Xaas.Ocel.Changes.RelateEventToObjects` for the change module and its own
  moduledoc for why this, and not a fabricated causal-discovery step, is the
  real admission boundary this ticket asks for.
  """

  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Ocel,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("ocel_events")
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

    create :record do
      description(
        "Record a real OCEL event and its object relations in one admitted, transactional step."
      )

      accept([:event_type, :ocel_id, :occurred_at, :attributes])

      argument :object_relations, {:array, :map} do
        allow_nil?(false)
      end

      change {Xaas.Ocel.Changes.RelateEventToObjects, []}
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :event_type, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :ocel_id, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :occurred_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
    end

    attribute :attributes, :map do
      default(%{})
      public?(true)
    end

    timestamps()
  end

  relationships do
    has_many(:event_objects, Xaas.Ocel.EventObject, destination_attribute: :event_id)
    has_many(:state_deltas, Xaas.Ocel.ObjectStateDelta, destination_attribute: :event_id)
  end

  identities do
    identity(:event_type_ocel_id, [:event_type, :ocel_id])
  end
end
