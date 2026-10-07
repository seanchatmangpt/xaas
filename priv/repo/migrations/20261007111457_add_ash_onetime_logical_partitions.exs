defmodule Xaas.Repo.Migrations.AddAshOnetimeLogicalPartitions do
  @moduledoc false

  use Ecto.Migration

  def up do
    add_partition_column("ash_onetime_idempotency_claims")
    add_partition_column("ash_onetime_nonce_claims")
    add_partition_column("ash_onetime_response_payloads")

    replace_collision_constraint(
      "ash_onetime_idempotency_claims",
      "ash_onetime_idempotency_claims_logical_collision_key"
    )

    replace_collision_constraint(
      "ash_onetime_nonce_claims",
      "ash_onetime_nonce_claims_logical_collision_key"
    )
  end

  def down do
    # Replay-safe down/ (W981q): xaas_dev received this DDL directly, so a
    # fresh replay may run down/ against a schema where up/ never recorded.
    # Guard every drop the same way up/ guards every add.
    if column_exists?("ash_onetime_idempotency_claims", "logical_partition") do
      execute("""
      DO $guard$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM #{q("ash_onetime_idempotency_claims")}
        WHERE logical_partition <> 'global'
      ) OR EXISTS (
        SELECT 1 FROM #{q("ash_onetime_nonce_claims")}
        WHERE logical_partition <> 'global'
      ) OR EXISTS (
        SELECT 1 FROM #{q("ash_onetime_response_payloads")}
        WHERE logical_partition <> 'global'
      ) THEN
        RAISE EXCEPTION 'cannot remove logical partitions while non-global claims exist'
          USING ERRCODE = '23514';
      END IF;
    END
    $guard$
    """)
    end

    restore_global_collision(
      "ash_onetime_idempotency_claims",
      "ash_onetime_idempotency_claims_logical_collision_key",
      "ash_onetime_idempotency_claims_collision_key"
    )

    restore_global_collision(
      "ash_onetime_nonce_claims",
      "ash_onetime_nonce_claims_logical_collision_key",
      "ash_onetime_nonce_claims_collision_key"
    )

    drop_partition_column("ash_onetime_response_payloads")
    drop_partition_column("ash_onetime_nonce_claims")
    drop_partition_column("ash_onetime_idempotency_claims")
  end

  defp add_partition_column(table) do
    # Replay-safe (W971b): xaas_dev received this DDL directly, so the
    # column may already exist without the version being recorded.
    if column_exists?(table, "logical_partition") do
      :ok
    else
      execute("""
      ALTER TABLE #{q(table)}
      ADD COLUMN logical_partition text NOT NULL DEFAULT 'global'
        CHECK (octet_length(logical_partition) BETWEEN 1 AND 255)
      """)
    end
  end

  defp replace_collision_constraint(table, new_name) do
    # Replay-safe (W971b): if the logical collision constraint already
    # exists, the replace already happened on a prior direct-DDL pass.
    if constraint_exists?(table, new_name) do
      :ok
    else
      do_replace_collision_constraint(table, new_name)
    end
  end

  defp do_replace_collision_constraint(table, new_name) do
    execute("""
    DO $replace$
    DECLARE old_name text;
    BEGIN
      SELECT constraint_name INTO old_name
      FROM (
        SELECT c.conname AS constraint_name,
               array_agg(a.attname ORDER BY key_columns.ordinality) AS columns
        FROM pg_catalog.pg_constraint c
        CROSS JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS key_columns(attnum, ordinality)
        JOIN pg_catalog.pg_attribute a
          ON a.attrelid = c.conrelid AND a.attnum = key_columns.attnum
        WHERE c.conrelid = '#{q(table)}'::regclass AND c.contype = 'u'
        GROUP BY c.conname
      ) constraints
      WHERE columns = ARRAY['operation_hash','scope_hash','key_hash']::name[];

      IF old_name IS NULL THEN
        RAISE EXCEPTION 'legacy ash_onetime collision constraint is missing'
          USING ERRCODE = '23514';
      END IF;

      EXECUTE format('ALTER TABLE #{q(table)} DROP CONSTRAINT %I', old_name);
    END
    $replace$
    """)

    execute("""
    ALTER TABLE #{q(table)}
    ADD CONSTRAINT #{quote_identifier(new_name)}
      UNIQUE (logical_partition, operation_hash, scope_hash, key_hash)
    """)
  end

  defp drop_partition_column(table) do
    # Replay-safe (W981q): match up/'s column_exists? idiom for the drop.
    if column_exists?(table, "logical_partition") do
      execute("ALTER TABLE #{q(table)} DROP COLUMN logical_partition")
    end
  end

  defp restore_global_collision(table, current_name, restored_name) do
    # Replay-safe (W981q): only drop/restore when the logical collision
    # constraint is present; skip the add when the legacy constraint already
    # exists (fresh replay of a schema that never ran up/).
    if constraint_exists?(table, current_name) do
      execute("""
      ALTER TABLE #{q(table)} DROP CONSTRAINT #{quote_identifier(current_name)}
      """)

      unless constraint_exists?(table, restored_name) do
        execute("""
        ALTER TABLE #{q(table)}
        ADD CONSTRAINT #{quote_identifier(restored_name)}
          UNIQUE (operation_hash, scope_hash, key_hash)
        """)
      end
    end
  end

  defp column_exists?(table, column) do
    repo().query!(
      "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = $1 AND column_name = $2)",
      [table, column]
    ).rows |> List.flatten() |> hd()
  end

  defp constraint_exists?(table, name) do
    repo().query!(
      """
      SELECT EXISTS (
        SELECT 1 FROM pg_catalog.pg_constraint c
        JOIN pg_catalog.pg_class t ON t.oid = c.conrelid
        WHERE c.conname = $1 AND t.relname = $2
      )
      """,
      [name, table]
    ).rows |> List.flatten() |> hd()
  end

  defp q(name) do
    case prefix() do
      nil -> quote_identifier(name)
      prefix_value -> quote_identifier(prefix_value) <> "." <> quote_identifier(name)
    end
  end

  defp quote_identifier(value), do: ~s("#{String.replace(value, "\"", "\"\"")}")
end