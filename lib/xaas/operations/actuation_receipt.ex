defmodule Xaas.Operations.ActuationReceipt do
  @moduledoc """
  Durable Ash receipt for a Reactor-governed consequential operation.

  A receipt is prepared before DO and sealed after the target Ash action returns.
  The record binds identity, semantic projection, input, consequence, and replay.
  It deliberately has no public action surface; only the Reactor actuation kernel
  may prepare, read, or seal it.
  """

  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Operations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  policies do
    policy always() do
      forbid_if always()
    end
  end

  postgres do
    table "actuation_receipts"
    repo Xaas.Repo
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :prepare do
      public? false

      accept [
        :intent_id,
        :attempt,
        :status,
        :resource_module,
        :action,
        :subject_id,
        :ontology_class_iri,
        :ontology_projection_hash,
        :input_hash,
        :replay_token,
        :started_at
      ]
    end

    update :seal do
      public? false
      accept [:status, :result_hash, :result, :error, :completed_at]
      require_atomic? false
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :intent_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :attempt, :integer do
      allow_nil? false
      default 1
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      default :prepared
      constraints one_of: [:prepared, :succeeded, :failed, :refused]
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

    attribute :result_hash, :string do
      public? true
    end

    attribute :result, :map do
      allow_nil? false
      default %{}
      public? true
    end

    attribute :error, :map do
      allow_nil? false
      default %{}
      public? true
    end

    attribute :replay_token, :string do
      allow_nil? false
      public? true
    end

    attribute :started_at, :utc_datetime_usec do
      allow_nil? false
      default &DateTime.utc_now/0
      public? true
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :intent, Xaas.Operations.ActuationIntent do
      source_attribute :intent_id
      destination_attribute :id
      attribute_type :uuid
      define_attribute? false
    end
  end

  identities do
    identity :unique_replay_token, [:replay_token]
  end
end
