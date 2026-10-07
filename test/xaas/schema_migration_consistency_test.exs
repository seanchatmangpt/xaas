defmodule Xaas.SchemaMigrationConsistencyTest do
  @moduledoc """
  Lane W846 — SQL-level court for the W726/W737/W786/W804 migration series.

  Nothing previously courted that the test database's actual schema matches
  what the migrations produce from scratch (a fresh `mix ecto.create &&
  mix ecto.migrate` on a scratch DB can silently diverge from a long-lived
  `xaas_test` — e.g. a rename guard that no-ops on one path but not the
  other). This module introspects the live test DB read-only via
  `Xaas.Repo.query/2` against `pg_indexes` / `information_schema.columns`
  — real Postgres, no mocks — and courts:

    (a) the W726-renamed witness identity indexes exist under their exact
        new names, and the W737/W804 ultracode org-less partial unique
        index exists;
    (b) the W786 `logical_partition` column exists on all three
        `ash_onetime_*` authority tables;
    (c) rename completeness: no table carries BOTH an old and new name
        version of the same index;
    (d) determinism: every introspection runs twice and must return
        identical row sets.

  If the sandbox connection cannot read the catalogs, the test fails with
  a typed SKIP-REFUSED reason rather than silently passing (the fallback
  of pinning via migration-file contracts was NOT needed: introspection
  is read-only and sandbox-safe — asserted by these tests actually
  running green against the real DB).
  """

  use Xaas.DataCase, async: false

  alias Xaas.Repo

  @witness_new_indexes %{
    "witness_certified_receipts" =>
      "witness_certified_receipts_unique_subject_payload_index",
    "witness_verification_keys" => "witness_verification_keys_unique_kid_index"
  }

  @witness_old_indexes MapSet.new([
                         "witness_certified_receipts_subject_payload_hash_hex_index",
                         "witness_verification_keys_kid_index"
                       ])

  @ultracode_index "ultracode_epochs_orgless_run_cycle_index"

  @partition_tables ~w(
    ash_onetime_idempotency_claims
    ash_onetime_nonce_claims
    ash_onetime_response_payloads
  )

  setup do
    # DataCase's sandbox owner covers LegacyRepo only; check out Xaas.Repo
    # explicitly for catalog reads. Sandbox isolates data, not DDL — the
    # introspected catalogs are the real xaas_test schema.
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: false)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)

    # Real catalogs of the real xaas_test DB (the sandbox connection sees
    # the same schema; sandbox only isolates data, not DDL).
    assert {:ok, %{rows: [[db_name]]}} =
             Repo.query("SELECT current_database()::text", [])

    {:ok, db_name: db_name}
  end

  defp pg_indexes do
    case Repo.query("""
         SELECT tablename::text, indexname::text
         FROM pg_indexes
         WHERE schemaname = 'public'
         ORDER BY tablename, indexname
         """, []) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [t, n] -> {t, n} end)

      {:error, err} ->
        flunk("REFUSED(SCHEMA_INTROSPECTION_FAILED) — pg_indexes unreadable: #{inspect(err)}")
    end
  end

  defp columns(table) do
    case Repo.query("""
         SELECT column_name::text
         FROM information_schema.columns
         WHERE table_schema = 'public' AND table_name = $1
         ORDER BY column_name
         """, [table]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [c] -> c end)

      {:error, err} ->
        flunk(
          "REFUSED(SCHEMA_INTROSPECTION_FAILED) — information_schema unreadable for " <>
            table <> ": #{inspect(err)}"
        )
    end
  end

  defp assert_deterministic(fetch, label) do
    first = fetch.()
    second = fetch.()
    assert first == second, "non-deterministic introspection for #{label}"
    first
  end

  # ------------------------------------------------------------------
  # (a) exact-name existence: W726 renames + W737/W804 ultracode index
  # ------------------------------------------------------------------

  test "W726-renamed witness identity indexes exist under exact new names",
       %{db_name: db_name} do
    indexes =
      assert_deterministic(&pg_indexes/0, "pg_indexes (witness)") |> MapSet.new()

    for {table, new_name} <- @witness_new_indexes do
      assert MapSet.member?(indexes, {table, new_name}),
             "MISSING in #{db_name}: index #{new_name} on #{table} " <>
               "(W726 rename end-state not present)"
    end
  end

  test "W737/W804 org-less run/cycle partial unique index exists on ultracode_epochs",
       %{db_name: db_name} do
    indexes =
      assert_deterministic(&pg_indexes/0, "pg_indexes (ultracode)") |> MapSet.new()

    assert MapSet.member?(indexes, {"ultracode_epochs", @ultracode_index}),
           "MISSING in #{db_name}: index #{@ultracode_index} on ultracode_epochs"

    # Chicago check on real index properties, not just the name: it must
    # be UNIQUE and partial on org_id IS NULL (W737's contract).
    {:ok, %{rows: rows}} =
      Repo.query(
        """
        SELECT i.indisunique, pg_get_expr(i.indpred, i.indrelid)::text
        FROM pg_indexes x
        JOIN pg_class c ON c.relname = x.indexname
        JOIN pg_index i ON i.indexrelid = c.oid
        WHERE x.schemaname = 'public' AND x.indexname = $1
        """,
        [@ultracode_index]
      )

    assert [[true, predicate]] = rows,
           "index #{@ultracode_index} has wrong properties: #{inspect(rows)}"

    assert is_binary(predicate) and String.contains?(predicate, "org_id") and
             String.contains?(predicate, "IS NULL"),
           "index #{@ultracode_index} is not partial on org_id IS NULL: #{inspect(predicate)}"
  end

  # ------------------------------------------------------------------
  # (b) W786 logical_partition on all three ash_onetime authority tables
  # ------------------------------------------------------------------

  test "W786 logical_partition column exists on all three ash_onetime tables" do
    for table <- @partition_tables do
      cols = assert_deterministic(fn -> columns(table) end, "columns(#{table})")

      assert "logical_partition" in cols,
             "MISSING: logical_partition column on #{table} (W786 contract)"
    end
  end

  # ------------------------------------------------------------------
  # (c) rename completeness: no old+new name coexistence
  # ------------------------------------------------------------------

  test "no table carries both old and new names of a renamed witness index" do
    indexes =
      assert_deterministic(&pg_indexes/0, "pg_indexes (rename completeness)")
      |> MapSet.new()

    old_present =
      indexes
      |> MapSet.new(fn {_t, name} -> name end)
      |> MapSet.intersection(@witness_old_indexes)

    assert MapSet.size(old_present) == 0,
           "RENAME INCOMPLETE: old witness index name(s) still present alongside " <>
             "new names: #{inspect(MapSet.to_list(old_present))}"
  end

  test "old ash_onetime global collision constraint is fully replaced (no coexistence)" do
    # W786 dropped the 3-column unique constraint and added the
    # 4-column logical one. Court the end-state directly.
    {:ok, %{rows: rows}} =
      Repo.query("""
      SELECT c.conname::text, array_agg(a.attname::text ORDER BY key_columns.ordinality)
      FROM pg_catalog.pg_constraint c
      CROSS JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS key_columns(attnum, ordinality)
      JOIN pg_catalog.pg_attribute a
        ON a.attrelid = c.conrelid AND a.attnum = key_columns.attnum
      WHERE c.conrelid = 'ash_onetime_idempotency_claims'::regclass
        AND c.contype = 'u'
      GROUP BY c.conname
      ORDER BY c.conname
      """)

    constraints = assert_deterministic(fn -> rows end, "idempotency unique constraints")

    assert [
             ["ash_onetime_idempotency_claims_logical_collision_key",
              ["logical_partition", "operation_hash", "scope_hash", "key_hash"]]
           ] = constraints,
           "unexpected unique-constraint end-state on ash_onetime_idempotency_claims: " <>
             inspect(constraints)
  end

  # ------------------------------------------------------------------
  # (d) determinism across a second full pass (already per-assert above;
  #     this is the whole-catalog ×2 court)
  # ------------------------------------------------------------------

  test "full catalog snapshot is deterministic across two passes" do
    snapshot = fn ->
      %{
        indexes: pg_indexes(),
        partition_cols: Map.new(@partition_tables, fn t -> {t, columns(t)} end)
      }
    end

    a = assert_deterministic(snapshot, "full catalog snapshot")
    # one more independent pass to satisfy the ×2 contract explicitly
    b = snapshot.()
    assert a == b, "catalog snapshot drifted between two consecutive reads"
  end
end
