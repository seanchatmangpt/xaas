defmodule Xaas.Operations.ActuationIntent do
  @moduledoc """
  Ash resource representing an admitted consequential-operation intent.

  This is the SELECT/ADMIT boundary before Reactor is allowed to execute a DO.
  The row binds the exact resource/action/subject, semantic projection identity,
  input fingerprint, caller authority, and idempotency key. It has no public
  mutation route; Reactor is the only writer and uses `authorize?: false` only
  after its authority admission step has succeeded.
  """

  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Operations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  policies do
    bypass action_type(:read) do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  postgres do
    table "actuation_intents"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :admit do
      accept [
        :idempotency_key,
        :resource_module,
        :action,
        :subject_id,
        :ontology_class_iri,
        :ontology_projection_hash,
        :input_hash,
        :actor_ref,
        :tenant_ref,
        :authority,
        :input,
        :status
      ]
    end

    update :transition do
      accept [:status]
      require_atomic? false
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :idempotency_key, :string do
      allow_nil? false
      public? true
    end

    attribute :resource_module, :string do
      allow_nil? false
      public? true
    end

    attribute :action, :string do
      allow_nil? false
      public? true
    end

    attribute :subject_id, :string do
      public? true
    end

    attribute :ontology_class_iri, :string do
      allow_nil? false
      public? true
    end

    attribute :ontology_projection_hash, :string do
      allow_nil? false
      public? true
    end

    attribute :input_hash, :string do
      allow_nil? false
      public? true
    end

    attribute :actor_ref, :string do
      public? true
    end

    attribute :tenant_ref, :string do
      public? true
    end

    attribute :authority, :map do
      allow_nil? false
      default %{}
      public? true
    end

    attribute :input, :map do
      allow_nil? false
      default %{}
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      default :admitted
      constraints one_of: [:admitted, :executing, :succeeded, :failed, :refused]
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_idempotency_key, [:idempotency_key]
  end
end
