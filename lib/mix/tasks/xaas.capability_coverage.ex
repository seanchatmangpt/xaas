defmodule Mix.Tasks.Xaas.CapabilityCoverage do
  @shortdoc "Reports real Postgres row counts for every real Ash resource in lib/xaas/"
  @moduledoc """
  Enumerates every real Ash resource module under lib/xaas/ (resources that use
  `Xaas.Resource` / `Ash.Resource` with `data_layer: AshPostgres.DataLayer`), and for
  each one runs a real `Ash.count/2` against the real, current Postgres database
  (via `Xaas.Repo`), reporting the real row count.

  Usage:

      mix xaas.capability_coverage
  """
  use Mix.Task

  @domains [
    Xaas.Accounts,
    Xaas.Billing,
    Xaas.Governance,
    Xaas.Ledger,
    Xaas.Marketplace,
    Xaas.Operations,
    Xaas.Platform
  ]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    resources =
      @domains
      |> Enum.flat_map(fn domain ->
        try do
          Ash.Domain.Info.resources(domain)
        rescue
          _ -> []
        end
      end)
      |> Enum.uniq()
      |> Enum.filter(fn resource ->
        try do
          Ash.Resource.Info.data_layer(resource) == AshPostgres.DataLayer
        rescue
          _ -> false
        end
      end)
      |> Enum.sort_by(&inspect/1)

    rows =
      Enum.map(resources, fn resource ->
        table = AshPostgres.DataLayer.Info.table(resource) || "(no table)"

        count =
          try do
            case Ash.count(resource, authorize?: false) do
              {:ok, n} -> n
              {:error, error} -> {:error, inspect(error)}
            end
          rescue
            e -> {:error, Exception.message(e)}
          end

        {resource, table, count}
      end)

    total_resources = length(rows)
    with_rows = Enum.count(rows, fn {_, _, c} -> is_integer(c) and c > 0 end)
    zero_rows = Enum.count(rows, fn {_, _, c} -> c == 0 end)
    errored = Enum.count(rows, fn {_, _, c} -> match?({:error, _}, c) end)

    Mix.shell().info("")
    Mix.shell().info("XaaS Capability Coverage Report (real Ash resources, real Postgres counts)")
    Mix.shell().info(String.duplicate("=", 100))

    Mix.shell().info(
      String.pad_trailing("RESOURCE", 62) <>
        String.pad_trailing("TABLE", 28) <> "ROW COUNT"
    )

    Mix.shell().info(String.duplicate("-", 100))

    Enum.each(rows, fn {resource, table, count} ->
      count_str =
        case count do
          {:error, msg} -> "ERROR: " <> msg
          n -> Integer.to_string(n)
        end

      Mix.shell().info(
        String.pad_trailing(inspect(resource), 62) <>
          String.pad_trailing(table, 28) <> count_str
      )
    end)

    Mix.shell().info(String.duplicate("-", 100))
    Mix.shell().info("Total real Postgres-backed Ash resources: #{total_resources}")
    Mix.shell().info("Resources with at least one real persisted row: #{with_rows}")
    Mix.shell().info("Resources with zero rows: #{zero_rows}")
    Mix.shell().info("Resources that errored on count: #{errored}")

    coverage_pct =
      if total_resources > 0, do: Float.round(with_rows / total_resources * 100, 1), else: 0.0

    Mix.shell().info("Coverage (resources with >=1 real row / total): #{coverage_pct}%")
    Mix.shell().info("")
  end
end
