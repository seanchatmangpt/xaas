defmodule Xaas.Migrations.W981qRawRepo do
  @moduledoc false
  # Non-sandbox repo bound to the same xaas_test database: migration legs
  # must COMMIT (schema_migrations bookkeeping and DDL), not roll back
  # inside a sandbox transaction. Config is merged from Xaas.Repo's config
  # at start time (see setup_all in the court below).
  use Ecto.Repo, otp_app: :xaas, adapter: Ecto.Adapters.Postgres
end

defmodule Xaas.Migrations.AddAshOnetimeLogicalPartitionsReplayTest do
  @moduledoc """
  Lane W981q — Chicago court for W971b's
  `20261007111457_add_ash_onetime_logical_partitions` migration down-leg.

  The up/ was already replay-safe (W971b guards); the down/ was not:
  unguarded `DROP CONSTRAINT`/`DROP COLUMN` crashed a fresh replay of the
  dev database (xaas_dev, per the W786/W804 operator path) that never ran
  up/. This court exercises the real migration through the real
  `Ecto.Migrator` runner against the real `xaas_test` Postgres — no mocks —
  asserting real schema state (information_schema / pg_constraint) after
  every leg:

    (a) up replay on a schema that already has the DDL (up guards no-op);
    (b) down on the upped schema (real drop leg);
    (c) down AGAIN on the downed schema — the exact fresh-replay state that
        crashed before hardening (down guards must no-op, not raise);
    (d) final up restores the W786 end-state (column + logical collision
        constraint present, legacy 3-column unique absent).

  Runs against a dedicated non-sandbox repo (real autocommitting
  transactions) because the sandbox's never-committing transaction both
  hides the migrator's schema_migrations writes and row-lock-blocks the
  court's committed version bookkeeping.
  """

  use Xaas.DataCase, async: false

  @path "priv/repo/migrations/20261007111457_add_ash_onetime_logical_partitions.exs"
  @module Xaas.Repo.Migrations.AddAshOnetimeLogicalPartitions
  @version 2026_1007_111_457

  @tables ~w(
    ash_onetime_idempotency_claims
    ash_onetime_nonce_claims
    ash_onetime_response_payloads
  )

  @logical_constraint_tables ~w(
    ash_onetime_idempotency_claims
    ash_onetime_nonce_claims
  )

  setup_all do
    # Dedicated non-sandbox repo (real transactions, commits visible).
    conf =
      Xaas.Repo.config()
      |> Keyword.merge(pool: DBConnection.ConnectionPool, pool_size: 2, queue_target: 5_000)

    {:ok, repo_pid} = Xaas.Migrations.W981qRawRepo.start_link(conf)
    on_exit(fn -> if Process.alive?(repo_pid), do: GenServer.stop(repo_pid); :ok end)

    # Leave the DB in the upped end-state whatever the outcome.
    on_exit(fn ->
      recover_end_state()
    end)

    :ok
  end

  # ------------------------------------------------------------------
  # real schema assertions (read-only catalog introspection)
  # ------------------------------------------------------------------

  defp partition_columns_present? do
    Enum.all?(@tables, fn table ->
      {:ok, %{rows: [[count]]}} =
        Xaas.Migrations.W981qRawRepo.query(
          "SELECT count(*)::int FROM information_schema.columns
           WHERE table_schema = 'public' AND table_name = $1
             AND column_name = 'logical_partition'",
          [table]
        )

      count == 1
    end)
  end

  defp unique_constraints(table) do
    {:ok, %{rows: rows}} =
      Xaas.Migrations.W981qRawRepo.query(
        """
        SELECT c.conname::text,
               array_agg(a.attname::text ORDER BY key_columns.ordinality)
        FROM pg_catalog.pg_constraint c
        CROSS JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS key_columns(attnum, ordinality)
        JOIN pg_catalog.pg_attribute a
          ON a.attrelid = c.conrelid AND a.attnum = key_columns.attnum
        WHERE c.conrelid = '#{table}'::regclass AND c.contype = 'u'
        GROUP BY c.conname
        ORDER BY c.conname
        """,
        []
      )

    rows
  end

  defp logical_constraint_present? do
    Enum.all?(@logical_constraint_tables, fn table ->
      cols =
        unique_constraints(table)
        |> Enum.filter(fn [name, _cols] -> name == table <> "_logical_collision_key" end)
        |> Enum.map(fn [_name, cols] -> cols end)

      match?([cols] when is_list(cols), cols) and
        "logical_partition" in List.first(cols, [])
    end)
  end

  defp legacy_constraint_absent? do
    Enum.all?(@logical_constraint_tables, fn table ->
      legacy = table <> "_collision_key"
      not Enum.any?(unique_constraints(table), fn [name, _] -> name == legacy end)
    end)
  end

  # ------------------------------------------------------------------
  # the court
  # ------------------------------------------------------------------

  test "up/down/down-fresh/up replay legs hold real schema state" do
    # leg (a): up replay on a schema that already carries the DDL
    run_up()

    assert partition_columns_present?(),
           "after up replay: logical_partition missing on some ash_onetime table"

    assert logical_constraint_present?(),
           "after up replay: logical collision constraint missing"

    # leg (b): real down leg — drops columns + logical constraints,
    # restores legacy 3-column unique constraints
    run_down()

    refute partition_columns_present?(),
           "after down: logical_partition still present"

    for table <- @logical_constraint_tables do
      cols =
        unique_constraints(table)
        |> Enum.filter(fn [name, _] -> name == table <> "_collision_key" end)
        |> Enum.map(fn [_, cols] -> cols end)

      assert [cols] = cols, "after down: legacy collision constraint missing on #{table}"
      assert cols == ["operation_hash", "scope_hash", "key_hash"],
             "after down: legacy collision constraint wrong shape: #{inspect(cols)}"
    end

    # leg (c): down AGAIN on the downed schema — the fresh-db state that
    # crashed before W981q hardening; guards must no-op cleanly
    run_down()
    refute partition_columns_present?(), "second down resurrected columns?"

    # leg (d): final up restores the W786 end-state
    run_up()
    assert partition_columns_present?(), "after final up: columns missing"
    assert logical_constraint_present?(), "after final up: logical constraint missing"
    assert legacy_constraint_absent?(), "after final up: legacy constraint still present"
  end

  # ------------------------------------------------------------------
  # migration runner plumbing
  # ------------------------------------------------------------------

  defp run_up do
    # Force the real runner to execute (not skip as already-applied):
    # remove the recorded version on a committed connection, then migrate
    # up through Ecto.Migrator using the {version, module} target form
    # (a bare file path is treated as a directory by the runner's wildcard
    # glob and silently matches nothing).
    Xaas.Migrations.W981qRawRepo.query!("DELETE FROM schema_migrations WHERE version = $1", [@version])

    assert [_] =
             Ecto.Migrator.run(Xaas.Migrations.W981qRawRepo, [{@version, migration_module()}],
               :up,
               all: true,
               migration_lock: false
             )
  end

  defp run_down do
    # For :down the runner only executes recorded versions; force the leg
    # by recording the version on a committed connection first. On the
    # second down this is exactly the fresh-replay state: the version is
    # "recorded" but the schema was already downed.
    Xaas.Migrations.W981qRawRepo.query!(
      "INSERT INTO schema_migrations (version, inserted_at) VALUES ($1, now()) ON CONFLICT (version) DO NOTHING",
      [@version]
    )

    assert [_] =
             Ecto.Migrator.run(Xaas.Migrations.W981qRawRepo, [{@version, migration_module()}],
               :down,
               all: true,
               migration_lock: false
             )
  end

  defp migration_module do
    unless Code.ensure_loaded?(@module) do
      Code.require_file(@path)
    end

    @module
  end

  # ------------------------------------------------------------------
  # crash recovery: leave xaas_test in the upped end-state
  # ------------------------------------------------------------------

  defp recover_end_state do
    conf = Xaas.Repo.config()

    {:ok, raw} =
      Postgrex.start_link(
        hostname: conf[:hostname] || "localhost",
        port: conf[:port] || 5432,
        username: conf[:username],
        password: conf[:password],
        database: conf[:database]
      )

    # Re-run the guards directly (same idiom as the migration's up/):
    # add missing columns / logical constraints, record the version.
    for table <- @tables do
      %{rows: [[count]]} =
        Postgrex.query!(
          raw,
          "SELECT count(*)::int FROM information_schema.columns
           WHERE table_name = $1 AND column_name = 'logical_partition'",
          [table]
        )

      if count == 0 do
        Postgrex.query!(
          raw,
          "ALTER TABLE #{table} ADD COLUMN logical_partition text NOT NULL DEFAULT 'global'",
          []
        )
      end
    end

    for table <- @logical_constraint_tables do
      %{rows: rows} =
        Postgrex.query!(
          raw,
          "SELECT count(*)::int FROM pg_catalog.pg_constraint
           WHERE conrelid = $1::regclass AND conname = $2",
          [table, table <> "_logical_collision_key"]
        )

      if rows == [[0]] do
        Postgrex.query!(
          raw,
          """
          ALTER TABLE #{table}
          ADD CONSTRAINT #{table}_logical_collision_key
            UNIQUE (logical_partition, operation_hash, scope_hash, key_hash)
          """,
          []
        )
      end
    end

    Postgrex.query!(
      raw,
      "INSERT INTO schema_migrations (version, inserted_at) VALUES (20261007111457, now()) ON CONFLICT (version) DO NOTHING",
      []
    )

    GenServer.stop(raw)
  rescue
    _ -> :ok
  end
end
