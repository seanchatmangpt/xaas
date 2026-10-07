defmodule Xaas.Semantics.DeclaredMetrics do
  @moduledoc """
  EU AI Act Art. 15(3) declared-metrics surface.

  Art. 15(3): technical documentation shall include the metrics used to
  measure accuracy and robustness. This module declares the fleet's REAL
  accuracy/robustness metrics as structured data — values are READ from the
  cited receipt files at call time (fail-closed on a missing or unparseable
  source), never hardcoded into the declaration.

  Each metric carries its source receipt path, so the declaration is an
  evidence pointer, not an assertion. Any missing or unparseable source
  yields the typed refusal `{:error, :REFUSED_METRICS_SOURCE_MISSING}`.
  """

  @typed_refusal :REFUSED_METRICS_SOURCE_MISSING

  @w316 "docs/sjira/v26.10.6/plans/w316-tokened-full-suite.md"
  @w385 "docs/sjira/v26.10.6/plans/w385-conformance-court.md"
  @ledger "docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json"
  @mutation_receipts [
    "docs/sjira/v26.10.6/plans/w320-anti-vacuity-audit.md",
    "docs/sjira/v26.10.6/plans/w382-anti-vacuity-r2.md",
    "docs/sjira/v26.10.6/plans/w414-empty-bearer-kill.md"
  ]

  @doc """
  Emits the declared accuracy/robustness metrics, read from the witnessed
  receipt corpus at call time.

  Fails closed with `{:error, :REFUSED_METRICS_SOURCE_MISSING}` when any
  cited receipt is missing from disk or its numbers cannot be extracted.
  """
  @spec declare() :: {:ok, map()} | {:error, :REFUSED_METRICS_SOURCE_MISSING}
  def declare do
    with {:ok, w316} <- read(@w316),
         {:ok, w385} <- read(@w385),
         {:ok, ledger_body} <- read(@ledger),
         :ok <- require_all(@mutation_receipts),
         {passed, population} when is_integer(passed) <- parse_suite(w316),
         {conformant, total} when is_integer(conformant) <- parse_conformance(w385),
         {:ok, counts} <- parse_ledger(ledger_body) do
      {:ok,
       %{
         accuracy: %{
           metric: "pass_rate",
           passed: passed,
           population: population,
           source: @w316
         },
         robustness: %{
           metric: "mutant_kill_rate",
           kills: counts.mutant_kill_verified,
           runs: counts.mutation_runs,
           sources: @mutation_receipts
         },
         refusal_coverage: counts.coverage,
         conformance: "#{conformant}/#{total} in-repo court"
       }}
    else
      _ -> {:error, @typed_refusal}
    end
  end

  defp read(path) do
    root = Application.get_env(:xaas, :declared_metrics_root, File.cwd!())

    case File.read(Path.join(root, path)) do
      {:ok, body} -> {:ok, body}
      {:error, _} -> {:error, @typed_refusal}
    end
  end

  defp require_all(paths) do
    Enum.reduce_while(paths, :ok, fn path, :ok ->
      case read(path) do
        {:ok, _} -> {:cont, :ok}
        {:error, refusal} -> {:halt, {:error, refusal}}
      end
    end)
  end

  defp parse_suite(body) do
    case Regex.run(~r/Result: (\d+)\/(\d+) passed/, body) do
      [_, passed, total] -> {String.to_integer(passed), String.to_integer(total)}
      nil -> :error
    end
  end

  defp parse_conformance(body) do
    case Regex.run(~r/CONFORMANT (\d+)\/(\d+)/, body) do
      [_, conformant, total] -> {String.to_integer(conformant), String.to_integer(total)}
      nil -> :error
    end
  end

  defp parse_ledger(body) do
    with {:ok, json} <- Jason.decode(body),
         %{
           "counts" => %{
             "coverage" => coverage,
             "mutant_kill_verified" => kills,
             "mutation_runs" => runs
           }
         } <- json,
         true <- is_binary(coverage) and is_integer(kills) and is_integer(runs) do
      {:ok, %{coverage: coverage, mutant_kill_verified: kills, mutation_runs: runs}}
    else
      _ -> :error
    end
  end
end
