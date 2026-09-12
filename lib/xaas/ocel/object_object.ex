defmodule Xaas.Ocel.ObjectObject do
  @moduledoc """
  The object-object relation from the OCEL model (e.g. "order contains item",
  "device belongs to site") -- ticket scope item "object-object relation",
  docs/jira/v26.9.11/object-centric-event-projection.md.

  A self-referential join over `Xaas.Ocel.Object`: `source_object_id` and
  `target_object_id` are both `Object` foreign keys, with a `qualifier`
  naming the relation type. This is the real mechanism that lets a
  case-shaped view be *derived* (see `Xaas.Ocel.CaseView`) by walking
  object-object edges outward from a root object, instead of requiring a
  canonical persisted case join table.
  """

  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Ocel,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("ocel_object_objects")
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
      description("Relate two existing objects with a qualifier.")
      accept([:source_object_id, :target_object_id, :qualifier])

      validate({Xaas.Ocel.Validations.NotSelfReferential, []})

      upsert?(true)
      upsert_identity(:object_object_qualifier)
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
    belongs_to :source_object, Xaas.Ocel.Object do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :target_object, Xaas.Ocel.Object do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:object_object_qualifier, [:source_object_id, :target_object_id, :qualifier])
  end
end
