defmodule Xaas.Ocel.Object do
  @moduledoc """
  A typed OCEL (Object-Centric Event Log) object.

  Ticket: docs/jira/v26.9.11/object-centric-event-projection.md. An object is
  a real, typed entity that events relate to -- e.g. an order, a device, a
  user -- distinct from the artificial single "case id" that case-oriented
  workflow engines force. Multiple objects, of possibly different types, can
  share the same event (see `Xaas.Ocel.EventObject`).

  `ash_resource`/`ash_resource_id` are an optional, real (not fabricated)
  identity bridge back to an existing Ash resource this object represents,
  per the ticket's "Ash-resource identity mapping" scope item -- see
  `Xaas.Ocel.AshIdentity` for the deterministic mapping functions. Both
  fields are nullable because an OCEL object need not be backed by any
  existing Ash resource (e.g. an object introduced purely via OCEL import).
  """

  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Ocel,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("ocel_objects")
    repo(Xaas.Repo)
  end

  policies do
    # Deny-by-default floor (per CLAUDE.md's Ash policy floor). Read is a
    # scoped, deliberate carve-out for internal process-mining consumers;
    # every write action stays deny-by-default with zero matching policy,
    # per the catch-all forbid_if below.
    bypass action_type(:read) do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read, :destroy])

    create :register do
      description("Register a real, typed OCEL object.")
      accept([:object_type, :ocel_id, :ash_resource, :ash_resource_id])
      upsert?(true)
      upsert_identity(:object_type_ocel_id)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :object_type, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :ocel_id, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :ash_resource, :string do
      public?(true)
    end

    attribute :ash_resource_id, :string do
      public?(true)
    end

    timestamps()
  end

  relationships do
    has_many(:event_objects, Xaas.Ocel.EventObject, destination_attribute: :object_id)

    has_many(:outgoing_object_relations, Xaas.Ocel.ObjectObject,
      destination_attribute: :source_object_id
    )

    has_many(:incoming_object_relations, Xaas.Ocel.ObjectObject,
      destination_attribute: :target_object_id
    )

    has_many(:state_deltas, Xaas.Ocel.ObjectStateDelta, destination_attribute: :object_id)
  end

  identities do
    identity(:object_type_ocel_id, [:object_type, :ocel_id])
  end
end
