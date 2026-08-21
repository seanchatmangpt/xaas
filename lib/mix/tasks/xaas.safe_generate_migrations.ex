defmodule Mix.Tasks.Xaas.SafeGenerateMigrations do
  @moduledoc """
  Real, structural fix for a real recurring incident: this session hit the
  same problem 3 separate times where `mix ash_postgres.generate_migrations`
  for one changed resource produced a migration file that ALSO contained
  unrelated, sometimes destructive, operations on OTHER tables -- driven by
  other resources' pending codegen sitting in the same tree at generation
  time. Those had to be manually inspected and hand-stripped, every time,
  before the migration was safe to apply.

  This task wraps the real `mix ash_postgres.generate_migrations` and adds a
  real safety gate:

    1. Run the real underlying task with the given `--name`.
    2. Read the real migration file(s) it just wrote (by diffing the real
       `priv/repo/migrations` directory before/after the run -- the
       underlying task does not report the path it wrote).
    3. Parse the real generated Ecto.Migration DSL for `create table(:x)`,
       `alter table(:x) do ... end`, `drop table(:x)`, `rename` calls,
       `references(:x, ...)` calls (embedded inside `add`/`modify` column
       definitions -- e.g. `modify :org_id, references(:orgs, ...)`), and
       `index(:x, ...)` / `unique_index(:x, ...)` calls (which are never
       nested inside a `table(:x) do ... end` block at all -- they name
       their table directly, e.g. `create unique_index(:orgs, [:slug])`),
       to get the real set of tables the migration touches.
    4. Resolve the target resource's real table from its
       `postgres do table "..." end` block (compiled at runtime via
       `Ash.Resource.Info.table/1` against the real, compiled resource
       module passed as `--resource`).
    5. Any touched table other than the target resource's own table is a
       cross-table operation. By default, REFUSE: print every cross-table
       operation found, and exit non-zero, leaving the generated migration
       file in place for manual review (do not silently delete real
       generated artifacts -- fix forward, inspect, decide).
    6. `--allow-cross-table` bypasses the refusal for the rare legitimate
       multi-resource migration, and the task then behaves exactly like the
       plain underlying task.

  Usage:

      mix xaas.safe_generate_migrations --name add_foo_field --resource Xaas.Billing.Subscription
      mix xaas.safe_generate_migrations --name add_foo_field --resource Xaas.Billing.Subscription --allow-cross-table
  """
  use Mix.Task

  @shortdoc "Generate an ash_postgres migration and refuse it if it touches tables outside --resource's own table"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.config")

    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [name: :string, resource: :string, allow_cross_table: :boolean],
        aliases: [n: :name, r: :resource]
      )

    name = opts[:name] || Mix.raise("--name is required")
    resource_arg = opts[:resource] || Mix.raise("--resource is required")
    allow_cross_table? = opts[:allow_cross_table] || false

    resource_module = resolve_resource_module!(resource_arg)
    target_table = resolve_target_table!(resource_module)

    migrations_dir = Path.join([File.cwd!(), "priv", "repo", "migrations"])
    before_files = list_migration_files(migrations_dir)

    Mix.shell().info(
      "[xaas.safe_generate_migrations] target resource #{inspect(resource_module)} -> table #{inspect(target_table)}"
    )

    Mix.Task.run("ash_postgres.generate_migrations", ["--name", name])
    Mix.Task.reenable("ash_postgres.generate_migrations")

    after_files = list_migration_files(migrations_dir)
    new_files = after_files -- before_files

    if new_files == [] do
      Mix.shell().info(
        "[xaas.safe_generate_migrations] no new migration file was generated (no pending changes for #{inspect(resource_module)}, or generation was a no-op)."
      )
    else
      Enum.each(new_files, fn file ->
        path = Path.join(migrations_dir, file)
        content = File.read!(path)
        touched_tables = touched_tables(content)
        cross_table = MapSet.delete(touched_tables, target_table) |> Enum.sort()

        cond do
          cross_table == [] ->
            Mix.shell().info(
              "[xaas.safe_generate_migrations] OK: #{file} only touches #{inspect(target_table)}."
            )

          allow_cross_table? ->
            Mix.shell().info(
              "[xaas.safe_generate_migrations] WARNING: #{file} touches other tables #{inspect(cross_table)} in addition to #{inspect(target_table)}, but --allow-cross-table was passed. Leaving migration in place."
            )

          true ->
            report_refusal(file, path, target_table, cross_table, content)
            Mix.raise(
              "xaas.safe_generate_migrations: refused #{file} -- it contains operations on tables other than #{inspect(target_table)}. Re-run with --allow-cross-table only if this is genuinely intended, or regenerate after resolving/committing the other resources' pending codegen separately."
            )
        end
      end)
    end
  end

  defp resolve_resource_module!(resource_arg) do
    module = Module.concat([resource_arg])

    case Code.ensure_compiled(module) do
      {:module, ^module} ->
        if function_exported?(module, :spark_is, 0) or
             Ash.Resource.Info.resource?(module) do
          module
        else
          Mix.raise("#{resource_arg} is not a compiled Ash.Resource")
        end

      {:error, reason} ->
        Mix.raise("could not load resource module #{resource_arg}: #{inspect(reason)}")
    end
  end

  defp resolve_target_table!(resource_module) do
    case AshPostgres.DataLayer.Info.table(resource_module) do
      nil ->
        Mix.raise(
          "#{inspect(resource_module)} has no `postgres do table \"...\" end` block -- cannot determine its table."
        )

      table when is_binary(table) ->
        table
    end
  end

  defp list_migration_files(dir) do
    case File.ls(dir) do
      {:ok, files} -> files |> Enum.filter(&String.ends_with?(&1, ".exs")) |> Enum.sort()
      {:error, _} -> []
    end
  end

  # Parses the real Ecto.Migration DSL forms that
  # `mix ash_postgres.generate_migrations` actually emits for this project
  # (confirmed against real generated files -- see the real FMEA finding
  # this fixes, RPN=490: `priv/repo/migrations/20260821034020_add_org_fk_dr_
  # failover_legal_hold_release_deployment_quarantine.exs` has 3 real
  # `references(:orgs, ...)` calls embedded inside `alter table(:x) do
  # modify :org_id, references(:orgs, ...) end` blocks that the original,
  # `table(`-only regex silently missed; `priv/repo/migrations/2026082102451
  # 1_add_marketplace_providers.exs` and `..._add_org_membership.exs` have
  # real top-level `create unique_index(:x, [...])` calls that never appear
  # nested inside a `table(:x) do ... end` block at all):
  #
  #   create table(:foo, primary_key: false) do ... end
  #   alter table(:foo) do ... end
  #   drop table(:foo)
  #   rename table(:foo), :old, to: :new
  #   references(:foo, column: :id, ...)          -- inside add/modify column defs
  #   create index(:foo, [:bar])
  #   create unique_index(:foo, [:bar])
  #   drop_if_exists index(:foo, [:bar])
  #   drop_if_exists unique_index(:foo, [:bar])
  #
  # Table identifiers are always the `:table_name` atom-literal argument
  # immediately following `table(`, `references(`, `index(`, or
  # `unique_index(`.
  @table_call_regex ~r/\b(?:create|alter|drop|rename)\s+table\(\s*:([a-zA-Z_][a-zA-Z0-9_]*)/
  @references_call_regex ~r/\breferences\(\s*:([a-zA-Z_][a-zA-Z0-9_]*)/
  @index_call_regex ~r/\b(?:unique_)?index\(\s*:([a-zA-Z_][a-zA-Z0-9_]*)/

  # All real table-name-bearing DSL forms recognized above, unioned together.
  @all_table_regexes [@table_call_regex, @references_call_regex, @index_call_regex]

  # Real, confirmed DOE finding (reproduced independently 3 times this
  # session): the regexes above ran over RAW file text, including comments
  # and `@moduledoc`/`@doc` strings. A migration file whose comment merely
  # EXPLAINS or gives an example of `references(:orgs, ...)` DSL syntax
  # (documentation, a code-review note, a "do NOT do this" example) got
  # that comment text matched as if it were real, executable migration
  # code, producing a false REFUSE.
  #
  # Fix: strip Elixir single-line comments (everything from an unescaped
  # `#` to end-of-line) before running the detection regexes. Elixir has
  # no block comments -- every comment is a full-line-or-line-suffix
  # `#...`, so line-by-line stripping is complete for the real DSL forms
  # this task parses.
  #
  # Real, accepted limitation, not a bug: a `#` inside an actual string
  # literal (e.g. `"table#1"`, a URL fragment) is not a comment start in
  # real Elixir, but this per-line scan cannot distinguish that from a
  # real comment without a full tokenizer. This is deliberately not
  # handled: real `mix ash_postgres.generate_migrations` output never puts
  # a literal `#` inside a string argument to `table()`/`references()`/
  # `index()` calls -- table/column/index names there are plain Elixir
  # atoms (`:foo`), not strings, and the surrounding arguments are keyword
  # lists -- so this limitation does not affect any real input this task
  # processes. A full string-aware tokenizer would be over-engineering for
  # a case that does not occur in practice.
  @line_comment_regex ~r/(?<!\\)#.*/

  defp strip_comments(content) do
    content
    |> String.split("\n")
    |> Enum.map(&strip_line_comment/1)
    |> Enum.join("\n")
  end

  defp strip_line_comment(line), do: Regex.replace(@line_comment_regex, line, "", global: false)

  @doc false
  def touched_tables(content) do
    stripped = strip_comments(content)

    @all_table_regexes
    |> Enum.flat_map(fn regex ->
      regex
      |> Regex.scan(stripped)
      |> Enum.map(fn [_, table] -> table end)
    end)
    |> MapSet.new()
  end

  # Real tables named on a single line, across all recognized DSL forms.
  # Shared by `touched_tables/1` (whole-file union) and `report_refusal/5`
  # (per-line detail for the refusal message). Comment-stripped for the
  # same reason as `touched_tables/1` above.
  defp tables_on_line(line) do
    stripped = strip_line_comment(line)

    @all_table_regexes
    |> Enum.flat_map(fn regex ->
      regex
      |> Regex.scan(stripped)
      |> Enum.map(fn [_, table] -> table end)
    end)
    |> Enum.uniq()
  end

  defp report_refusal(file, path, target_table, cross_table, content) do
    Mix.shell().error("""

    [xaas.safe_generate_migrations] REFUSED -- cross-table operations detected

    Migration file: #{path}
    Target resource table: #{inspect(target_table)}
    Other tables touched by this migration: #{inspect(cross_table)}

    This means #{file} bundles changes for tables outside the resource you
    asked to generate a migration for. This is the exact class of incident
    this task exists to prevent: unrelated in-flight resource changes
    getting silently swept into one migration and requiring manual,
    error-prone hand-stripping before it is safe to apply.

    The generated migration file has been left on disk for manual review at:
      #{path}

    Cross-table operations found (verbatim from the generated file):
    """)

    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.each(fn {line, lineno} ->
      if Enum.any?(tables_on_line(line), &(&1 != target_table)) do
        Mix.shell().error("  line #{lineno}: #{String.trim(line)}")
      end
    end)

    Mix.shell().error("""

    To proceed anyway (only if this cross-table change is genuinely intended):
      mix xaas.safe_generate_migrations --name <name> --resource <ResourceModule> --allow-cross-table
    """)
  end
end
