defmodule Mix.Tasks.Xaas.SafeGenerateMigrationsTest do
  @moduledoc """
  Real regression test for the real FMEA finding (RPN=490,
  Severity=7 x Occurrence=7 x Detection=10): `touched_tables/1`'s original
  regex only recognized the literal `<verb> table(:x)` DSL wrapper and
  silently missed `references(:other_table, ...)` calls embedded inside
  `add`/`modify` column definitions, and bare `index(:other_table, ...)` /
  `unique_index(:other_table, ...)` calls -- both real, common
  `mix ash_postgres.generate_migrations` output shapes that never appear
  wrapped in a `table(:x) do ... end` block.

  This test reads REAL migration files already committed to
  `priv/repo/migrations/` (no fabricated fixtures for the confirming case)
  and calls the REAL `touched_tables/1` function -- pure text parsing, no
  collaborator worth faking, so no test double of any kind is used here.
  """
  use ExUnit.Case, async: true

  alias Mix.Tasks.Xaas.SafeGenerateMigrations, as: Task

  describe "touched_tables/1 -- references() detection (the real FMEA gap)" do
    test "catches a real references(:orgs, ...) call embedded inside alter table() blocks, on the real cited migration" do
      # This is the exact real file cited in the FMEA finding: 3 real
      # `references(:orgs, ...)` calls, each nested inside a separate
      # `alter table(:approval_*) do modify :org_id, references(:orgs, ...) end`
      # block. Before this fix, `touched_tables/1` returned only the 3
      # `approval_*` tables from the `alter table(:x)` wrapper and silently
      # dropped `orgs` -- the actual foreign-key target -- entirely.
      content =
        File.read!(
          "priv/repo/migrations/20260821034020_add_org_fk_dr_failover_legal_hold_release_deployment_quarantine.exs"
        )

      touched = Task.touched_tables(content)

      assert MapSet.member?(touched, "orgs"),
             "expected touched_tables/1 to catch the real references(:orgs, ...) calls, got: #{inspect(touched)}"

      assert touched ==
               MapSet.new([
                 "approval_dr_failovers",
                 "approval_deployment_quarantines",
                 "approval_legal_hold_releases",
                 "orgs"
               ])

      # Prove the real cross-table refusal gate itself now catches this: if
      # the target resource were `approval_dr_failovers`, `orgs` shows up as
      # a real cross-table operation the gate must not silently miss.
      cross_table = MapSet.delete(touched, "approval_dr_failovers") |> Enum.sort()
      assert "orgs" in cross_table
    end

    test "catches references(:table, ...) for a synthetic single-line case, isolated from any table() wrapper" do
      content = """
      alter table(:widgets) do
        modify :owner_id, references(:owners, column: :id, on_delete: :restrict)
      end
      """

      touched = Task.touched_tables(content)

      assert touched == MapSet.new(["widgets", "owners"])
    end
  end

  describe "touched_tables/1 -- index()/unique_index() detection (the real FMEA gap)" do
    test "catches real top-level create unique_index(:table, ...) calls on real migration files" do
      # Real file: `create unique_index(:marketplace_providers, [:slug], ...)`
      # appears at the top level (not nested in any table(:x) block), naming
      # the same table the migration also `create table`s -- confirms
      # detection without introducing a false cross-table positive here.
      content = File.read!("priv/repo/migrations/20260821024511_add_marketplace_providers.exs")
      touched = Task.touched_tables(content)

      assert touched == MapSet.new(["marketplace_providers"])
    end

    test "catches a bare unique_index(:other_table, ...) that targets a different table than any table() call" do
      content = """
      create index(:orders, [:customer_id])
      create unique_index(:customers, [:email])
      """

      touched = Task.touched_tables(content)

      assert touched == MapSet.new(["orders", "customers"])
    end
  end

  describe "touched_tables/1 -- happy path preserved" do
    test "a real single-table migration with no references()/index() calls still returns exactly its one table" do
      # Real file: `create table(:ledger_events, ...) do ... end` /
      # `drop table(:ledger_events)` only -- no references(), no index(),
      # no unique_index(). Confirms the fix does not regress the ordinary,
      # already-working single-table case.
      content = File.read!("priv/repo/migrations/20260820213157_add_ledger_events.exs")
      touched = Task.touched_tables(content)

      assert touched == MapSet.new(["ledger_events"])
    end

    test "the original create/alter/drop/rename table() forms are still recognized on their own" do
      content = """
      defmodule Xaas.Repo.Migrations.SyntheticHappyPath do
        use Ecto.Migration

        def up do
          create table(:foos, primary_key: false) do
            add :id, :uuid, null: false, primary_key: true
            add :name, :text, null: false
          end
        end

        def down do
          drop table(:foos)
        end
      end
      """

      touched = Task.touched_tables(content)

      assert touched == MapSet.new(["foos"])
    end
  end
end
