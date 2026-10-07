defmodule Xaas.Semantics.DeclaredMetricsTest do
  use ExUnit.Case, async: true

  alias Xaas.Semantics.DeclaredMetrics

  @w316 "docs/sjira/v26.10.6/plans/w316-tokened-full-suite.md"

  describe "declare/0" do
    @tag :declared_metrics
    test "returns the Art 15(3) structure with all four metric groups" do
      assert {:ok, m} = DeclaredMetrics.declare()

      assert %{
               accuracy: %{
                 metric: "pass_rate",
                 passed: passed,
                 population: population,
                 source: source
               },
               robustness: %{
                 metric: "mutant_kill_rate",
                 kills: kills,
                 runs: runs,
                 sources: [_ | _] = sources
               },
               refusal_coverage: coverage,
               conformance: conformance
             } = m

      assert is_integer(passed) and passed > 0
      assert is_integer(population) and population >= passed
      assert is_integer(kills) and is_integer(runs) and runs > 0
      assert is_binary(coverage)
      assert is_binary(conformance)
      assert String.contains?(source, "w316")
      assert Enum.any?(sources, &String.contains?(&1, "w414"))
    end

    @tag :declared_metrics
    test "accuracy values match the cited w316 receipt's real numbers" do
      assert {:ok, %{accuracy: %{passed: passed, population: population}}} =
               DeclaredMetrics.declare()

      # Read the receipt independently, with the same extraction contract the
      # module declares: first `Result: N/M passed` line in the file.
      body = File.read!(Path.join(File.cwd!(), @w316))
      [_, receipt_passed, receipt_total] = Regex.run(~r/Result: (\d+)\/(\d+) passed/, body)

      assert passed == String.to_integer(receipt_passed)
      assert population == String.to_integer(receipt_total)
      # The witnessed numbers from w316b (3233/3247 run 1).
      assert population == 3247
    end

    @tag :declared_metrics
    test "robustness numbers match the refusal ledger counts" do
      assert {:ok, %{robustness: %{kills: kills, runs: runs}, refusal_coverage: coverage}} =
               DeclaredMetrics.declare()

      ledger =
        File.read!("docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json")
        |> Jason.decode!()

      counts = ledger["counts"]
      assert kills == counts["mutant_kill_verified"]
      assert runs == counts["mutation_runs"]
      assert coverage == counts["coverage"]
    end

    @tag :declared_metrics
    test "missing receipt fails closed with typed refusal" do
      empty_root = System.tmp_dir!() |> Path.join("w536-missing-root-#{System.unique_integer()}")
      File.mkdir_p!(empty_root)

      Application.put_env(:xaas, :declared_metrics_root, empty_root)

      try do
        assert DeclaredMetrics.declare() == {:error, :REFUSED_METRICS_SOURCE_MISSING}
      after
        Application.delete_env(:xaas, :declared_metrics_root)
        File.rm_rf!(empty_root)
      end
    end

    @tag :declared_metrics
    test "deterministic: two calls return identical data" do
      assert {:ok, a} = DeclaredMetrics.declare()
      assert {:ok, b} = DeclaredMetrics.declare()
      assert a == b
    end
  end
end
