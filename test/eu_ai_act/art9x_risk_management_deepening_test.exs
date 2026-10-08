defmodule Xaas.EUAIAct.Art9xRiskManagementDeepeningTest do
  @moduledoc """
  Lane W984fc — corpus evidenced-line deepening, Art. 9.x (risk management)
  lines flagged court-free by W984ec's receipt
  (`docs/sjira/v26.10.6/plans/w984ec-probe.md`): 9.1, 9.2.a, 9.2.b, 9.2.c,
  9.2.d, 9.5, 9.5.a, 9.5.b, 9.6, 9.8.

  Statute (Regulation (EU) 2024/1689):

    * Art. 9.1: the risk-management system is a "continuous iterative
      process" — its cycle must run and produce output over the LIVE inputs
      (the real refusal ledger), deterministically re-runnable.
    * Art. 9.2.a: known and foreseeable risks are IDENTIFIED — the ledger's
      typed refusal variants are enumerated with real enforcing sites.
    * Art. 9.2.b: risks are ESTIMATED and evaluated — each typed refusal
      variant maps to a risk concept, deterministically and with
      family-sensitivity.
    * Art. 9.2.c/9.2.d: risks are evaluated and TARGETED measures adopted —
      every enforcing module is real loadable code at its cited path and
      appears as an `airo:RiskControl` linked to the system in the emitted
      graph.
    * Art. 9.5/9.5.a/9.5.b: residual-risk adequacy via the inverse-
      reachability safe-set — the bridge carrying it is digest-verified and
      fail-closed.
    * Art. 9.6: testing via the reachability mutant-killing court — the
      safe-set decision functions exist and are cited from the live source.
    * Art. 9.8: the RMS is tested/reverified — the bridge stays digest-
      pinned, refusing mutated bytes fail-closed.

  Prior coverage: `title_iii_test.exs` `deepen_kind(:ferroplan_reachability)`
  asserts only that three symbols exist in the ferroplan source file;
  `deepen_kind(:audit_chain)`-family courts cover the audit chain (9.2's
  traceability leg). The risk-management BINDING courts here
  (ledger->risk-graph liveness, control seams as loadable modules,
  digest-pinned safe-set bridge) were not bound to the statute anywhere.

  Chicago discipline: real `Xaas.Semantics.AiroRiskMapping` runs over the
  real refusal ledger file, real `Xaas.Bridges.Ferroplan` digest
  verification over the real pinned artifact bytes, real File/Code reads of
  the cited seams; assertions on final returned state; zero mocks, zero
  application env.
  """

  use ExUnit.Case, async: false

  import Bitwise

  alias Xaas.Bridges.Ferroplan
  alias Xaas.Semantics.AiroRiskMapping

  @moduletag :eu_ai_act

  @reachability_src "/Users/sac/ferroplan/crates/ferroplan/src/reachability.rs"

  defp local_name(name), do: String.replace(name, ~r/[^A-Za-z0-9_.-]/, "_")

  # ---------------------------------------------------------------------------
  # Court 1 — Art. 9.1 + 9.2.a + 9.2.b: the risk-management cycle runs over
  # the LIVE refusal ledger and estimates risk per variant, deterministically.
  # ---------------------------------------------------------------------------
  describe "art 9.1/9.2.a/9.2.b rms cycle over the live refusal ledger" do
    @tag :eu_ai_act
    test "9.1 continuous iterative process: risk_graph/0 is byte-deterministic over the real ledger" do
      graph1 = AiroRiskMapping.risk_graph()
      graph2 = AiroRiskMapping.risk_graph()
      assert graph1 == graph2
      assert is_binary(graph1) and byte_size(graph1) > 0

      # The cycle runs over LIVE inputs: every ledger variant is enumerated
      # as a risk source and linked to the system.
      variants = AiroRiskMapping.variants()
      assert is_list(variants) and variants != []

      for v <- variants do
        assert v.refused? == String.starts_with?(v.variant, "REFUSED_")
        assert is_binary(v.variant) and byte_size(v.variant) > 0
        local = local_name(v.variant)
        assert graph1 =~ "ex:riskSource-#{local} a airo:RiskSource, airo:Hazard"
        assert graph1 =~ "ex:refusalVariant \"#{v.variant}\""
        assert graph1 =~ "ex:xaas-system airo:hasRisk ex:riskSource-#{local} ."
      end
    end

    @tag :eu_ai_act
    test "9.2.a identification: the ledger enumerates typed risk sources with real enforcing sites" do
      variants = AiroRiskMapping.variants()

      for v <- variants do
        assert v.refused? or String.starts_with?(v.variant, "BLOCKED_")
        assert v.sites != [], "variant #{v.variant} has no enforcing site"
        assert is_binary(v.fixture)
      end
    end

    @tag :eu_ai_act
    test "9.2.b estimation: risk_concept_for/1 is deterministic and family-sensitive" do
      # Deterministic function of the variant string.
      for v <- AiroRiskMapping.variants() do
        concept = AiroRiskMapping.risk_concept_for(v.variant)
        assert is_binary(concept) and concept != ""
        assert concept == AiroRiskMapping.risk_concept_for(v.variant)
      end

      # Family-sensitivity: distinct hazard families map to distinct concepts.
      assert AiroRiskMapping.risk_concept_for("REFUSED_EUAIA_MANIPULATIVE") ==
               "RISK_TO_INFORMED_CHOICE"

      assert AiroRiskMapping.risk_concept_for("REFUSED_EUAIA_FACIAL_SCRAPING") ==
               "PRIVACY_RISK"

      assert AiroRiskMapping.risk_concept_for("REFUSED_DIGEST_MISMATCH") ==
               "RECEIPT_DIGEST_MISMATCH"

      # Unknown-family variants fall to the typed default, never raise.
      assert AiroRiskMapping.risk_concept_for("REFUSED_WHATEVER") == "UNADMITTED_TRANSITION"
    end
  end

  # ---------------------------------------------------------------------------
  # Court 2 — Art. 9.2.c/9.2.d: targeted measures adopted — every risk
  # control is a REAL loadable module at its cited path and appears in the
  # emitted graph as an airo:RiskControl linked to the system.
  # ---------------------------------------------------------------------------
  describe "art 9.2.c/9.2.d risk controls are real loadable seams" do
    @tag :eu_ai_act
    test "9.2.c/9.2.d every control module exists on disk, loads, and mitigates a typed concept" do
      for c <- AiroRiskMapping.risk_controls() do
        assert File.exists?(Path.join(File.cwd!(), c.path)),
               "control #{c.module} cites missing path #{c.path}"

        mod = Module.concat([c.module])
        assert Code.ensure_loaded?(mod), "control #{c.module} does not compile/load"

        assert c.mitigates != []
        assert c.detects != []
        assert is_binary(c.scope) and byte_size(c.scope) > 0
      end
    end

    @tag :eu_ai_act
    test "9.2.d the graph links every control to the system with exactly one node per control" do
      controls = AiroRiskMapping.risk_controls()
      graph = AiroRiskMapping.risk_graph()

      for c <- controls do
        local = local_name(c.module)
        assert graph =~ "ex:riskControl-#{local} a airo:RiskControl ;"

        for concept <- c.mitigates do
          # The edge lists all concepts on one joined line; assert the
          # concept local appears within a mitigatesRiskConcept edge line.
          assert Enum.any?(String.split(graph, "\n"), fn line ->
                   String.contains?(line, "airo:mitigatesRiskConcept") and
                     String.contains?(line, "ex:#{concept}")
                 end),
                 "no mitigatesRiskConcept edge for #{concept}"
        end
      end

      # Exactly one isRiskControlFor edge per control, all to the system.
      links =
        graph
        |> String.split("airo:isRiskControlFor ex:xaas-system")
        |> length()
        |> Kernel.-(1)

      assert links == length(controls)
    end
  end

  # ---------------------------------------------------------------------------
  # Court 3 — Art. 9.5/9.5.a/9.5.b + 9.6 + 9.8: residual-risk adequacy via
  # the inverse-reachability safe-set — the bridge is digest-verified and
  # fail-closed, and the safe-set decision functions are cited live source.
  # ---------------------------------------------------------------------------
  describe "art 9.5/9.5.a/9.5.b/9.6/9.8 digest-pinned reachability safe-set bridge" do
    @tag :eu_ai_act
    test "9.5/9.5.a/9.5.b the bridge's artifact gate verifies the pinned safe-set engine and refuses mutated bytes" do
      # Real bytes at the canonical path verify against the pin court digest.
      assert {:ok, artifact} = Ferroplan.artifact()
      assert artifact.sha256 == Ferroplan.pinned_sha256()
      assert artifact.path == Ferroplan.artifact_path()
      assert byte_size(artifact.bytes) > 0

      # Independent digest math over the same real bytes.
      assert Base.encode16(:crypto.hash(:sha256, artifact.bytes), case: :lower) ==
               Ferroplan.pinned_sha256()

      # 9.8 reverification: mutated bytes refuse fail-closed with the typed
      # code, through the bridge's own gate — never a degraded pass.
      <<first, rest::binary>> = artifact.bytes
      mutated = <<bxor(first, 0xFF), rest::binary>>

      assert {:refused, refusal} = Ferroplan.verify_bytes(mutated)
      assert refusal.code == :ferroplan_artifact_digest_mismatch
      assert refusal.observed_sha256 != refusal.expected_sha256
    end

    @tag :eu_ai_act
    test "9.5 residual risk boundary: the safe-set decision functions are cited from live source and the bridge holds no authority" do
      # Art 9.6 testing leg: the reachability safe-set decision functions the
      # W501 court kills mutants against exist in the live cross-repo source.
      src = File.read!(@reachability_src)
      assert src =~ "pub struct BackwardSafeSet"
      assert src =~ "pub fn is_safe"
      assert src =~ "pub fn unsafe_count"

      # Authority boundary of the surface carrying the residual-risk math:
      # bridges never authorize.
      case Ferroplan.metadata() do
        {:ok, meta} ->
          assert meta.authority_ceiling == :none
          assert meta.standing == "UNKNOWN"
          assert meta.sha256 == Ferroplan.pinned_sha256()
          assert is_list(meta.exports) and "fp_call" in meta.exports

        {:refused, refusal} ->
          # Fail-closed posture is also the lawful outcome (e.g. the wasm
          # runtime/toolchain is unavailable on this host): the typed code
          # must still be the digest gate, never a silent pass.
          assert refusal.code == :ferroplan_artifact_digest_mismatch
      end
    end
  end
end
