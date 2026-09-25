defmodule Xaas.Repo.Migrations.AddReactorActuationControlPlane do
  use Ecto.Migration

  def up do
    create table(:actuation_intents, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :idempotency_key, :text, null: false
      add :resource_module, :text, null: false
      add :action, :text, null: false
      add :subject_id, :text
      add :ontology_class_iri, :text, null: false
      add :ontology_projection_hash, :text, null: false
      add :input_hash, :text, null: false
      add :actor_ref, :text
      add :tenant_ref, :text
      add :authority, :map, null: false, default: %{}
      add :input, :map, null: false, default: %{}
      add :status, :text, null: false, default: "admitted"

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:actuation_intents, [:idempotency_key],
             name: "actuation_intents_idempotency_key_index"
           )

    create index(:actuation_intents, [:resource_module, :action, :subject_id],
             name: "actuation_intents_subject_action_index"
           )

    create table(:actuation_receipts, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :intent_id, references(:actuation_intents, type: :uuid, on_delete: :delete_all),
        null: false

      add :attempt, :bigint, null: false, default: 1
      add :status, :text, null: false, default: "prepared"
      add :resource_module, :text, null: false
      add :action, :text, null: false
      add :subject_id, :text
      add :ontology_class_iri, :text, null: false
      add :ontology_projection_hash, :text, null: false
      add :input_hash, :text, null: false
      add :result_hash, :text
      add :result, :map, null: false, default: %{}
      add :error, :map, null: false, default: %{}
      add :replay_token, :text, null: false
      add :started_at, :utc_datetime_usec, null: false
      add :completed_at, :utc_datetime_usec

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:actuation_receipts, [:replay_token],
             name: "actuation_receipts_replay_token_index"
           )

    create index(:actuation_receipts, [:intent_id, :status],
             name: "actuation_receipts_intent_status_index"
           )
  end

  def down do
    drop_if_exists index(:actuation_receipts, [:intent_id, :status],
                     name: "actuation_receipts_intent_status_index"
                   )

    drop_if_exists unique_index(:actuation_receipts, [:replay_token],
                     name: "actuation_receipts_replay_token_index"
                   )

    drop table(:actuation_receipts)

    drop_if_exists index(:actuation_intents, [:resource_module, :action, :subject_id],
                     name: "actuation_intents_subject_action_index"
                   )

    drop_if_exists unique_index(:actuation_intents, [:idempotency_key],
                     name: "actuation_intents_idempotency_key_index"
                   )

    drop table(:actuation_intents)
  end
end
