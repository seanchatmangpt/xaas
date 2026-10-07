defmodule Xaas.Semantics.DeclaredMetricsStalenessTest do
  # Tag rationale (lane convention: in-file comment naming the evidenced line):
  # this file courts the Art. 15(3) declared-metrics fail-closed surface of
  # lib/xaas/semantics/declared_metrics.ex — EU AI Act Art. 15(3): "technical
  # documentation shall include the metrics used to measure accuracy and
  # robustness." The fail-closed read-at-call-time contract (W658c court
  # finding) is the behavior under test.
  use ExUnit.Case, async: false

  # Tag rationale (lane convention: in-file comment naming the evidenced line):
  # this file courts the Art. 15(3) declared-metrics fail-closed surface of
  # lib/xaas/semantics/declared_metrics.ex — EU AI Act Art. 15(3): "technical
  # documentation shall include the metrics used to measure accuracy and
  # robustness." The fail-closed read-at-call-time contract (W658c court
  # finding) is the behavior under test.
  @moduletag :eu_ai_act

  alias Xaas.Semantics.DeclaredMetrics

  @typed_refusal :REFUSED_METRICS_SOURCE_MISSING

  # Same relative receipt paths the module reads under the fixture root.
  @w316 "docs/sjira/v26.10.6/plans/w316-tokened-full-suite.md"
  @w385 "docs/sjira/v26.10.6/plans/w385-conformance-court.md"
  @ledger "docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json"

  @mutation_receipts [
    "docs/sjira/v26.10.6/plans/w320-anti-vacuity-audit.md",
    "docs/sjira/v26.10.6/plans/w382-anti-vacuity-r2.md",
    "docs/sjira/v26.10.6/plans/w414-empty-bearer-kill.md"
  ]

  # Real fixture bytes byte-shaped to the production surfaces the parsers
  # regex against (w316 suite line, w385 CONFORMANT line, JCS ledger counts).
  @w316_happy """
  # w316 — tokened full suite receipt

  Result: 3233/3247 passed
  """
  @w316_drift """
  # w316 — tokened full suite receipt

  Result: 3232/3247 passed
  """
  @w385_bytes """
  # w385 — conformance court

  CONFORMANT 26/26
  """
  @ledger_bytes ~s({"counts":{"coverage":"62/62","mutant_kill_verified":9,"mutation_runs":10}})

  setup do
    root = System.tmp_dir!() |> Path.join("w697-staleness-#{System.unique_integer()}")
    File.mkdir_p!(root)
    %{root: root}
  end

  setup context do
    Application.put_env(:xaas, :declared_metrics_root, context.root)

    on_exit(fn ->
      Application.delete_env(:xaas, :declared_metrics_root)
      File.rm_rf!(context.root)
    end)

    :ok
  end

  defp write_receipts(root, opts) do
    Enum.each(@mutation_receipts, fn rel ->
      path = Path.join(root, rel)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, "# mutation receipt fixture\n")
    end)

    Enum.each([{@w316, opts[:w316]}, {@w385, opts[:w385]}, {@ledger, opts[:ledger]}], fn
      {_rel, nil} ->
        :ok

      {rel, bytes} when is_binary(bytes) ->
        path = Path.join(root, rel)
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, bytes)
    end)
  end

  describe "declare/0 staleness (fail-closed contract per W658c court finding)" do
    @tag :w697_a
    test "(a) missing receipt file -> typed refusal" do
      root = context_root()
      # w316 and w385 present; the ledger is absent from disk.
      write_receipts(root, w316: @w316_happy, w385: @w385_bytes, ledger: nil)

      assert DeclaredMetrics.declare() == {:error, @typed_refusal}
    end

    @tag :w697_a2
    test "(a2) empty root, all receipts missing -> typed refusal" do
      assert DeclaredMetrics.declare() == {:error, @typed_refusal}
    end

    @tag :w697_b
    test "(b) malformed JSON in the refusal ledger -> typed refusal" do
      root = context_root()
      write_receipts(root, w316: @w316_happy, w385: @w385_bytes, ledger: "{not json")

      assert DeclaredMetrics.declare() == {:error, @typed_refusal}
    end

    @tag :w697_b2
    test "(b2) well-formed JSON with wrong ledger shape -> typed refusal" do
      root = context_root()
      write_receipts(root, w316: @w316_happy, w385: @w385_bytes, ledger: ~s({"counts":{"coverage":62}}))

      assert DeclaredMetrics.declare() == {:error, @typed_refusal}
    end

    @tag :w697_c
    test "(c) count drift 3233->3232 does NOT refuse (typed finding: drift gate lives in the production-value court, not in declare/0)" do
      root = context_root()
      write_receipts(root, w316: @w316_drift, w385: @w385_bytes, ledger: @ledger_bytes)

      # The module has no hardcoded-value admission: a drifted w316 is parsed
      # faithfully and returned as ok. This is by design — declare/0 is an
      # evidence pointer, so drift detection is delegated to the production
      # court in declared_metrics_test.exs, which pins population == 3247
      # against the REAL on-disk receipt (not this fixture root). This test
      # witnesses the boundary: drift alone does not trigger the typed
      # refusal, and the drifted value flows through unmodified.
      assert {:ok, %{accuracy: %{passed: 3232, population: 3247}}} =
               DeclaredMetrics.declare()
    end

    @tag :w697_c2
    test "(c2) unparseable suite line (regex miss) -> typed refusal" do
      root = context_root()
      write_receipts(root, w316: "Result: all green", w385: @w385_bytes, ledger: @ledger_bytes)

      assert DeclaredMetrics.declare() == {:error, @typed_refusal}
    end

    @tag :w697_c3
    test "(c3) missing mutation receipt -> typed refusal" do
      root = context_root()
      write_receipts(root, w316: @w316_happy, w385: @w385_bytes, ledger: @ledger_bytes)
      File.rm!(Path.join(root, "docs/sjira/v26.10.6/plans/w382-anti-vacuity-r2.md"))

      assert DeclaredMetrics.declare() == {:error, @typed_refusal}
    end

    @tag :w697_d
    test "(d) staleness typing: module exposes no staleness variant (typed finding, nothing invented)" do
      # Typed finding: Xaas.Semantics.DeclaredMetrics exports exactly one
      # public function, declare/0. There is no staleness-typed API (no
      # declare/1, no :stale status, no freshness metadata in the result),
      # so the contract under test is binary: {:ok, map} | typed refusal.
      # Witness that exported surface rather than inventing an API.
      exports = DeclaredMetrics.module_info(:exports)
      assert {:declare, 0} in exports
      assert {:declare, 1} not in exports
      refute Enum.any?(exports, fn {name, _} -> name in [:stale, :staleness, :freshness] end)
      # And on a fully-stale fixture root the only response is the typed refusal.
      assert DeclaredMetrics.declare() == {:error, @typed_refusal}
    end

    @tag :w697_e
    test "(e) happy path with real fixture bytes matches the production values" do
      root = context_root()
      write_receipts(root, w316: @w316_happy, w385: @w385_bytes, ledger: @ledger_bytes)

      assert {:ok, m} = DeclaredMetrics.declare()

      assert %{
               accuracy: %{metric: "pass_rate", passed: 3233, population: 3247, source: @w316},
               robustness: %{
                 metric: "mutant_kill_rate",
                 kills: 9,
                 runs: 10,
                 sources: @mutation_receipts
               },
               refusal_coverage: "62/62",
               conformance: "26/26 in-repo court"
             } = m
    end

    @tag :w697_e2
    test "(e2) happy-path fixture shape equals the REAL on-disk production surface" do
      # Chicago cross-check: the fixture bytes are not invented — the same
      # extraction contract pulls identical values from the production files.
      real_w316 = File.read!(Path.join(File.cwd!(), @w316))
      real_w385 = File.read!(Path.join(File.cwd!(), @w385))
      real_ledger = File.read!(Path.join(File.cwd!(), @ledger))

      [_, p, pop] = Regex.run(~r/Result: (\d+)\/(\d+) passed/, real_w316)
      [_, conf, total] = Regex.run(~r/CONFORMANT (\d+)\/(\d+)/, real_w385)
      counts = real_ledger |> Jason.decode!() |> Map.fetch!("counts")

      root = context_root()
      write_receipts(root, w316: real_w316, w385: real_w385, ledger: real_ledger)

      assert {:ok, m} = DeclaredMetrics.declare()
      assert m.accuracy.passed == String.to_integer(p)
      assert m.accuracy.population == String.to_integer(pop)
      assert m.conformance == "#{conf}/#{total} in-repo court"
      assert m.robustness.kills == counts["mutant_kill_verified"]
      assert m.robustness.runs == counts["mutation_runs"]
      assert m.refusal_coverage == counts["coverage"]

      # Production witnessed values (w316b run 1, w385 court, ledger recount).
      assert m.accuracy.passed == 3233
      assert m.accuracy.population == 3247
      assert m.conformance == "26/26 in-repo court"
    end
  end

  defp context_root do
    Application.fetch_env!(:xaas, :declared_metrics_root)
  end
end
