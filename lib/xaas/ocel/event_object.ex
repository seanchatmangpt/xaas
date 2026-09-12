defmodule Xaas.Ocel.EventObject do
  @moduledoc """
  The event-object relation from the OCEL model: `event -> {o_1, ..., o_n}`.

  Ticket: docs/jira/v26.9.11/object-centric-event-projection.md. Rows here
  are the real replacement for a case-oriented join table -- an event can
  relate to any number of objects of any type, each with its own qualifier
  (e.g. "resource", "actor"), instead of being pinned to one artificial case
  id. Normally created transactionally by `Xaas.Ocel.Event`'s `:record`
  action (see `Xaas.Ocel.Changes.RelateEventToObjects`); `:relate` exists as
  a direct create action for OCEL import (`Xaas.Ocel.Projection.import/1`)
  where the event may already exist.
  """

  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Ocel,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("ocel_event_objects")
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

    create :relate do
      description("Relate an existing event to an existing object with a qualifier.")
      accept([:event_id, :object_id, :qualifier])
      upsert?(true)
      upsert_identity(:event_object_qualifier)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :qualifier, :string do
      allow_nil?(false)
      default("related")
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :event, Xaas.Ocel.Event do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :object, Xaas.Ocel.Object do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:event_object_qualifier, [:event_id, :object_id, :qualifier])
  end
end
