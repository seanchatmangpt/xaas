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
       `alter table(:x) do ... end`, `drop table(:x)`, and `rename` calls,
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

  # Parses the real Ecto.Migration DSL that
  # `mix ash_postgres.generate_migrations` actually emits for this project
  # (confirmed against a real generated file):
  #
  #   create table(:foo, primary_key: false) do ... end
  #   alter table(:foo) do ... end
  #   drop table(:foo)
  #   rename table(:foo), :old, to: :new
  #
  # Table identifiers are always the `:table_name` atom-literal argument
  # immediately following `table(`.
  @table_call_regex ~r/\b(?:create|alter|drop|rename)\s+table\(\s*:([a-zA-Z_][a-zA-Z0-9_]*)/

  defp touched_tables(content) do
    @table_call_regex
    |> Regex.scan(content)
    |> Enum.map(fn [_, table] -> table end)
    |> MapSet.new()
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
    |> Enum.filter(fn {line, _} -> Regex.match?(@table_call_regex, line) end)
    |> Enum.each(fn {line, lineno} ->
      case Regex.run(@table_call_regex, line) do
        [_, table] when table != target_table ->
          Mix.shell().error("  line #{lineno}: #{String.trim(line)}")

        _ ->
          :ok
      end
    end)

    Mix.shell().error("""

    To proceed anyway (only if this cross-table change is genuinely intended):
      mix xaas.safe_generate_migrations --name <name> --resource <ResourceModule> --allow-cross-table
    """)
  end
end
