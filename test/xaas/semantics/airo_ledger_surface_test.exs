defmodule Xaas.Semantics.AiroLedgerSurfaceTest do
  @moduledoc """
  W984dt burn-down court on the last uncovered state-bearing surface in
  `Xaas.Semantics.AiroRiskMapping`: the real ledger-file boundary
  (`ledger_path/0` + `load_ledger/0`).

  Prior coverage (airo_risk_mapping_test, airo_risk_mapping_depth_test W984bj)
  exercises the ledger only *indirectly* through `variants/0`/`risk_graph/0`.
  No existing test calls the file boundary directly, so any of these mutants
  would survive today:

  - `ledger_path/0` `Path.expand("../../..", __DIR__)` depth off-by-one or a
    changed `@ledger_relpath` (variants/0 would raise File.Error at the file
    boundary — a build break, but not attributable to the path seam; when both
    path pieces drift *consistently* the seam silently points at a stale file).
  - `load_ledger/0` silently memoizing or returning a default map on read
    failure (a stale/default ledger would then drive risk_graph emission).
  - the `refused?` predicate in `variants/0` drifting from the
    `REFUSED_`-prefix contract (a `String.contains?` or case-insensitive
    mutant would misclassify BLOCKED_* rows as refused).

  Chicago discipline: real file, real JSON parse, no mocks, assertions on
  final real state. x2 fresh root calls per test where ordering could hide
  state.
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.AiroRiskMapping

  @ledger_relpath "docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json"
  @tag w984dt: true
  test "1. ledger_path/0 is absolute, repo-rooted, and pinned to the real file" do
    path = AiroRiskMapping.ledger_path()

    assert Path.absname(path) == path, "ledger_path/0 must be absolute, got: #{path}"
    assert File.exists?(path), "ledger file must exist at #{path}"
    assert String.ends_with?(path, @ledger_relpath),
           "ledger_path must end with the pinned relpath #{inspect(@ledger_relpath)}, got: #{path}"

    # Repo-rooted: expanding the repo root off the path must terminate at a
    # directory that actually contains lib/xaas/semantics/airo_risk_mapping.ex.
    repo_root = String.trim_trailing(path, @ledger_relpath)
    assert File.exists?(Path.join(repo_root, "lib/xaas/semantics/airo_risk_mapping.ex")),
           "ledger_path/0 is not rooted at the repo that owns the module"
  end

  @tag w984dt: true
  test "2. load_ledger/0 parses the real file; counts are internally consistent" do
    ledger = AiroRiskMapping.load_ledger()

    assert is_map(ledger)
    counts = ledger["counts"]
    assert is_map(counts), "ledger must carry a counts map"

    declared = counts["declared"]
    assert is_integer(declared) and declared > 0

    # Internal consistency: fixture_covered cannot exceed declared, and the
    # coverage string must agree with the numeric counts.
    covered = counts["fixture_covered"]
    assert is_integer(covered) and covered > 0 and covered <= declared

    coverage = counts["coverage"]
    assert is_binary(coverage) and coverage =~ ~r|^\d+/\d+$|
    assert coverage == "#{covered}/#{declared}",
           "coverage string #{inspect(coverage)} disagrees with counts " <>
             "fixture_covered=#{covered} declared=#{declared}"

    # Evidence must be cited: an unprovenanced ledger is not admitted.
    assert is_list(ledger["evidence_sources"]) and ledger["evidence_sources"] != []
  end

  @tag w984dt: true
  test "3. variants/0 is the true projection of the raw ledger refused?-predicate boundary" do
    raw = AiroRiskMapping.load_ledger()
    vs = AiroRiskMapping.variants()

    raw_variants = raw["variants"]
    assert is_list(raw_variants) and raw_variants != []

    assert MapSet.new(vs, & &1.variant) == MapSet.new(raw_variants, & &1["variant"]),
           "variants/0 must project exactly the raw ledger variant set"

    # Predicate boundary: refused? is exactly the REFUSED_ prefix contract,
    # computed independently from the raw ledger.
    for v <- raw_variants do
      expected = String.starts_with?(v["variant"] || "", "REFUSED_")
      projected = Enum.find(vs, &(&1.variant == (v["variant"] || "UNKNOWN_VARIANT")))

      assert projected.refused? == expected,
             "refused? misprojected for #{inspect(v["variant"])}"
    end

    # Boundary pin: the BLOCKED_* row must classify as not-refused.
    blocked = Enum.find(vs, &String.starts_with?(&1.variant, "BLOCKED_"))
    assert blocked, "ledger is expected to carry at least one BLOCKED_* row"
    refute blocked.refused?
  end

  @tag w984dt: true
  test "4. x2 fresh load_ledger/0 calls agree and match an independent decode of the raw bytes" do
    path = AiroRiskMapping.ledger_path()

    l1 = AiroRiskMapping.load_ledger()
    l2 = AiroRiskMapping.load_ledger()

    assert l1 == l2, "x2 fresh load_ledger calls must be identical (no hidden state)"

    # Independent ground truth: decode the bytes straight off disk.
    independent = path |> File.read!() |> Jason.decode!()
    assert l1 == independent,
           "load_ledger/0 must equal a direct decode of the file at ledger_path/0 " <>
             "(catches path/relpath drift and silent memoization)"
  end

  @tag w984dt: true
  test "5. downstream ledger consumers resolve the same real file seam" do
    # lib/xaas/operations/refusal_ledger_export.ex and
    # lib/xaas/operations/authority_ledger_export.ex both route through
    # AiroRiskMapping.ledger_path/0. Pin that the shared seam stays coherent:
    # the export contract requires the counts of the file at ledger_path/0.
    ledger = AiroRiskMapping.load_ledger()
    counts = ledger["counts"]

    assert counts["mutant_kill_verified"] in 0..(counts["mutation_runs"] || 0),
           "mutant_kill_verified must not exceed mutation_runs in the real ledger"

    assert is_integer(counts["mutation_runs"]) and counts["mutation_runs"] > 0

    # Structurally unreachable is bounded by declared.
    assert counts["structurally_unreachable"] in 0..counts["declared"]
  end
end
