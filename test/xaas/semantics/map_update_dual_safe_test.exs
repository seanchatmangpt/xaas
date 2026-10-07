# W659 lane: xaas self-patch — dual-safe Map.update/4 remediation.
#
# W705's census (docs/sjira/v26.10.6/plans/w705-wasm4pm-ex4pm-gaps.md) listed
# 12 absent-key-reliant Map.update/4 sites in xaas's own lib/. All 12 are now
# patched with the explicit case Map.fetch idiom: the absent-key arm seeds the
# default and never calls the update fun (observed otp-28 Map.update/4
# semantics), the present-key arm applies the transform. Both arms written
# explicitly, so behavior is identical under any future semantics.
#
# This file: W604-style canary + census drift tripwire + behavior pins through
# real public surfaces (circuit fail/open?/reset boundary, OCEL summary
# aggregation, gall TTL checkpoint admission).

defmodule Xaas.Semantics.MapUpdateDualSafeTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../..", __DIR__)

  @census_sites [
    {"lib/xaas/runtime/fond/circuit.ex", 4},
    {"lib/xaas_web/controllers/ocel_summary_controller.ex", 52},
    {"lib/xaas_web/controllers/ocel_summary_controller.ex", 53},
    {"lib/xaas/gall/turtle.ex", 139},
    {"lib/xaas/gall/turtle.ex", 167},
    {"lib/xaas/gall/turtle.ex", 172},
    {"lib/xaas/semantics/vkg/workspace.ex", 120},
    {"lib/xaas/ultracode/sequenced_drain.ex", 239},
    {"lib/xaas/ultracode/run_validation.ex", 798},
    {"lib/xaas/ultracode/run_validation.ex", 799},
    {"lib/xaas/ultracode/semantic_drive.ex", 2472},
    {"lib/xaas/fabric/planes/process.ex", 26}
  ]

  test "canary: Map.update/4 skips the fun on absent key on this runtime" do
    assert Map.update(%{}, :k, 7, &(&1 + 1)) == %{k: 7}
  end

  test "canary: Map.update/4 applies the fun on present key on this runtime" do
    assert Map.update(%{k: 7}, :k, 0, &(&1 + 1)) == %{k: 8}
  end

  test "canary: the dual-safe case Map.fetch idiom is behavior-identical to Map.update/4 on both arms" do
    bump = fn m, k ->
      case Map.fetch(m, k) do
        {:ok, n} -> Map.put(m, k, n + 1)
        :error -> Map.put(m, k, 1)
      end
    end

    # Absent arm: seeds the default, fun never called.
    assert bump.(%{}, :k) == Map.update(%{}, :k, 1, &(&1 + 1))
    # Present arm: fun applies.
    assert bump.(%{k: 1}, :k) == Map.update(%{k: 1}, :k, 1, &(&1 + 1))
  end

  test "census drift tripwire: all 12 w705 census sites are dual-safe (no Map.update/4 left)" do
    assert length(@census_sites) == 12

    for {rel, line_no} <- @census_sites do
      path = Path.expand(rel, @repo_root)
      assert File.exists?(path), "census site file missing: #{rel}"

      line_text =
        path
        |> File.read!()
        |> String.split("\n")
        |> Enum.at(line_no - 1, "")

      refute String.contains?(line_text, "Map.update("),
             "census site regressed to Map.update/4: #{rel}:#{line_no}"
    end
  end

  test "census drift tripwire: lib/ still compiles with exactly the expected Map.update/4 residue" do
    {remaining, _exit} =
      System.cmd("grep", ["-rn", "Map\\.update(", Path.join(@repo_root, "lib")],
        stderr_to_stdout: true
      )

    sites =
      remaining
      |> String.split("\n", trim: true)
      |> Enum.map(fn row ->
        [path, lineno, _rest] = String.split(row, ":", parts: 3)
        {Path.relative_to(path, File.cwd!()), String.to_integer(lineno)}
      end)

    # Exactly one residue, and it is the known absent-key-safe normalizer at
    # run_validation.ex:661 (default [] is fun-invariant: fun([]) == []), so
    # it is correct under either semantics and outside the w705 census.
    assert sites == [{"lib/xaas/ultracode/run_validation.ex", 661}]
  end

  # -- behavior pins through real public surfaces ------------------------------

  describe "FOND.Circuit fail/open?/reset boundary" do
    test "absent key seeds 1 (never 2), threshold opens at exactly 3 failures, reset clears" do
      c = Xaas.Runtime.FOND.Circuit.new(3)

      # Absent key: stored value is the seed 1, NOT fun.(1) == 2.
      c1 = Xaas.Runtime.FOND.Circuit.fail(c, :edge)
      assert c1.failures == %{edge: 1}
      refute Xaas.Runtime.FOND.Circuit.open?(c1, :edge)

      # Present key: increments.
      c2 = Xaas.Runtime.FOND.Circuit.fail(c1, :edge)
      c3 = Xaas.Runtime.FOND.Circuit.fail(c2, :edge)
      assert c3.failures == %{edge: 3}
      refute Xaas.Runtime.FOND.Circuit.open?(c2, :edge)
      assert Xaas.Runtime.FOND.Circuit.open?(c3, :edge)
      assert Xaas.Runtime.FOND.Circuit.open?(Xaas.Runtime.FOND.Circuit.fail(c3, :edge), :edge)

      c4 = Xaas.Runtime.FOND.Circuit.reset(c3, :edge)
      assert c4.failures == %{}
      refute Xaas.Runtime.FOND.Circuit.open?(c4, :edge)
    end
  end

  describe "XaasWeb.OcelSummaryController.summarize/1 (real NDJSON lines, no mocks)" do
    test "counts real ocel:events across multi-event documents, skips foreign lines" do
      lines = [
        ~s({"ocel:events": [{"type": "capability_liveness_receipt.ingest", "attributes": {"outcome": "ok"}}]}),
        ~s({"ocel:events": [{"type": "a.create", "attributes": {"outcome": "ok"}}, {"type": "a.create", "attributes": {"outcome": "error"}}]}),
        "not json at all",
        ~s({"unrelated": true})
      ]

      {by_activity, by_outcome, total} = XaasWeb.OcelSummaryController.summarize(lines)

      assert total == 3
      assert by_activity == %{"capability_liveness_receipt.ingest" => 1, "a.create" => 2}
      assert by_outcome == %{"ok" => 2, "error" => 1}

      # Absent-key seed is exactly 1 per new activity/outcome; repeated
      # activities accumulate (the dual-safe bump arms in the controller).
      assert by_activity["a.create"] == 2
    end

    test "empty log: real zero counts" do
      assert {%{}, %{}, 0} = XaasWeb.OcelSummaryController.summarize([])
    end
  end

  describe "Xaas.Gall.Turtle.from_turtle/1 (real RDF parse, list-append census sites)" do
    @ttl """
    @prefix gall: <https://semantic-a2a.dev/gall#> .

    <urn:gall:checkpoint:xaas:w659-001>
      a gall:CodingCheckpoint ;
      gall:repository <urn:repo:seanchatmangpt:xaas> ;
      gall:baseSha "6d5fca8cff223eb30ef19e237574d54f21cbfc15" ;
      gall:goal gall:SemanticWorkerIntegration ;
      gall:requiresCapability gall:Read, gall:Edit, gall:Commit ;
      gall:requiresVerifier gall:XaasChicagoCourt ;
      gall:forbidsCapability gall:Push ;
      gall:standing gall:UNKNOWN .
    """

    test "multi-valued predicates group per subject via the dual-safe append arms" do
      assert {:ok, checkpoint} = Xaas.Gall.Turtle.from_turtle(@ttl)
      assert Enum.sort(checkpoint.requires_capabilities) == [:Commit, :Edit, :Read]
      assert checkpoint.forbids_capabilities == [:Push]
      assert checkpoint.standing == :UNKNOWN
    end
  end
end
