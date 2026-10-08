defmodule Xaas.Semantics.AiroRiskMappingDepthTest do
  @moduledoc """
  W984bj depth court on `Xaas.Semantics.AiroRiskMapping` (thinnest semantics
  coverage: one prior test file, 155 lines, no precedence/boundary courts).

  Real invariants against the real module + real ledger file, Chicago-style:
  1. cond-branch precedence ordering (deterministic ×2) — mutation rationale:
     reordering the cond branches silently re-families every variant string
     that matches multiple keywords, and no existing test pins the order.
  2. typed fallback boundary: unknown / empty / keyword-partial strings must
     land on the closed-set "UNADMITTED_TRANSITION" concept, never raise —
     mutation rationale: deleting the catch-all cond arm crashes the whole
     risk_graph build.
  3. `variants/0` idempotency + sortedness over the real ledger (×2 fresh
     calls) — mutation rationale: dropping Enum.sort_by or leaking per-call
     accumulation breaks downstream deterministic graph emission.
  4. graph structural uniqueness: every emitted riskSource local name is
     unique and every variant/EUAIA atom gets exactly one hasRisk edge —
     mutation rationale: a safe_local collision would silently merge two
     distinct risks into one RDF node.
  5. conjunction boundary of the CASTLE+IDENTITY branch: CASTLE alone must
     NOT map to IDENTITY_SPOOFING (both keywords required) — mutation
     rationale: loosening the guard's `and` to `or` is invisible to every
     existing test.
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.AiroRiskMapping

  @tag w984bj: true
  test "1. cond precedence ordering is fixed and deterministic x2" do
    pairs = [
      # MALFORMED beats AUTHORITY (MALFORMED arm is earlier)
      {"REFUSED_MALFORMED_AUTHORITY_ESCAPE", "MALFORMED_INPUT_CANDIDATE"},
      # AUTHORITY beats CASTLE+IDENTITY (authority arm is earlier)
      {"REFUSED_CASTLE_IDENTITY_AUTHORITY", "AUTHORITY_ESCAPE"},
      # DIGEST beats RECEIPT (digest arm is earlier)
      {"REFUSED_RECEIPT_DIGEST_MISMATCH", "RECEIPT_DIGEST_MISMATCH"},
      # PROJECTION beats CHECKPOINT
      {"REFUSED_CHECKPOINT_PROJECTION_DRIFT", "SEMANTIC_PROJECTION_DRIFT"},
      # CHECKPOINT beats EVIDENCE
      {"REFUSED_EVIDENCE_CHECKPOINT_CORRUPTION", "CHECKPOINT_STATE_CORRUPTION"},
      # EUAIA family beats MALFORMED (EUAIA arms precede the MALFORMED arm)
      {"REFUSED_MALFORMED_EUAIA_SOCIAL_SCORING", "CROSS_CONTEXT_RISK"},
      # BUDGET beats CHICAGO/JSON
      {"REFUSED_JSON_BUDGET_EXHAUSTION", "RESOURCE_EXHAUSTION"},
      # EXECUTION/INTENT beats the fallback but loses to earlier families
      {"REFUSED_INTENT_EXECUTION", "UNADMITTED_EXECUTION_INTENT"}
    ]

    for {variant, concept} <- pairs do
      assert AiroRiskMapping.risk_concept_for(variant) == concept
      # determinism: pure function of the string, second call identical
      assert AiroRiskMapping.risk_concept_for(variant) == concept
    end
  end

  @tag w984bj: true
  test "2. fallback boundary: unknown, empty, and partial-keyword inputs stay in the closed set" do
    for malformed <- ["", "x", "REFUSED_", "totally_unknown_variant",
                      "blocked_no_keyword_at_all", "REFUSED_lowercase_noise"] do
      assert AiroRiskMapping.risk_concept_for(malformed) == "UNADMITTED_TRANSITION"
      refute AiroRiskMapping.risk_concept_for(malformed) == ""
    end
  end

  @tag w984bj: true
  test "3. variants/0 idempotent and sorted over the real ledger, x2 fresh calls" do
    v1 = AiroRiskMapping.variants()
    v2 = AiroRiskMapping.variants()

    assert v1 == v2
    assert v1 == Enum.sort_by(v1, & &1.variant)
    assert length(v1) > 0

    for v <- v1 do
      assert is_binary(v.variant) and v.variant != ""
      assert is_list(v.sites)
      assert is_boolean(v.refused?)
      assert v.refused? == String.starts_with?(v.variant, "REFUSED_")
      assert MapSet.member?(MapSet.new(["REFUSED", "BLOCKED"]),
                            if(v.refused?, do: "REFUSED", else: "BLOCKED"))
    end
  end

  @tag w984bj: true
  test "4. graph emits exactly one hasRisk edge and one unique local per risk source" do
    graph = AiroRiskMapping.risk_graph()
    vs = AiroRiskMapping.variants()

    # W984ce (fix of the W984bj pinned defect): ledger variants that are also
    # @euaia_atoms entries are deduped by RDF subject, so the atom emission is
    # skipped. Edge total = ledger variants + only the atoms NOT in the ledger.
    euaia_atoms = [
      "REFUSED_EUAIA_MANIPULATIVE",
      "REFUSED_EUAIA_VULNERABILITY_EXPLOIT",
      "REFUSED_EUAIA_SOCIAL_SCORING",
      "REFUSED_EUAIA_PREDICTIVE_POLICING",
      "REFUSED_EUAIA_FACIAL_SCRAPING",
      "REFUSED_EUAIA_EMOTION_RECOGNITION",
      "REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION",
      "REFUSED_EUAIA_REALTIME_RBI"
    ]

    ledger_variant_names = MapSet.new(vs, & &1.variant)
    extra_atoms = Enum.count(euaia_atoms, &not MapSet.member?(ledger_variant_names, &1))

    has_risk_edges =
      graph |> String.split("\n") |> Enum.filter(&String.contains?(&1, "airo:hasRisk ex:riskSource-"))

    # exactly one node per subject: edge count == unique edge count
    assert length(has_risk_edges) == length(Enum.uniq(has_risk_edges))

    # edge count matches the deduped subject total
    assert length(has_risk_edges) == length(vs) + extra_atoms

    # the previously duplicated subject now has exactly one edge
    assert Enum.frequencies(has_risk_edges)["ex:xaas-system airo:hasRisk ex:riskSource-REFUSED_EUAIA_MANIPULATIVE ."] ==
             1

    # one riskSource node per subject in the whole graph
    subjects =
      graph
      |> String.split("\n")
      |> Enum.filter(&String.contains?(&1, " a airo:RiskSource, airo:Hazard ;"))
      |> Enum.map(fn line ->
        [subject | _] = String.split(line, " a airo:RiskSource, airo:Hazard ;")
        subject
      end)

    assert length(subjects) == length(Enum.uniq(subjects))
    assert MapSet.member?(MapSet.new(subjects), "ex:riskSource-REFUSED_EUAIA_MANIPULATIVE")
  end

  @tag w984bj: true
  test "5. CASTLE+IDENTITY branch requires BOTH keywords (conjunction boundary)" do
    # CASTLE without IDENTITY falls through to the closed-set fallback
    assert AiroRiskMapping.risk_concept_for("REFUSED_CASTLE_GATE_BREACH") ==
             "UNADMITTED_TRANSITION"

    # IDENTITY without CASTLE falls through too
    assert AiroRiskMapping.risk_concept_for("REFUSED_IDENTITY_MINT_REFUSED") ==
             "UNADMITTED_TRANSITION"

    # both present -> IDENTITY_SPOOFING, deterministically
    assert AiroRiskMapping.risk_concept_for("REFUSED_CASTLE_IDENTITY_SPOOF") ==
             "IDENTITY_SPOOFING"

    assert AiroRiskMapping.risk_concept_for("REFUSED_CASTLE_IDENTITY_SPOOF") ==
             "IDENTITY_SPOOFING"

    # IDENTITY_SPOOFING is pairwise distinct from all other mapped concepts
    concepts =
      Enum.map(
        ["REFUSED_CASTLE_IDENTITY_SPOOF", "REFUSED_RECEIPT_DIGEST_X", "REFUSED_VKG_X",
         "REFUSED_CHECKPOINT_X", "REFUSED_EVIDENCE_X", "REFUSED_TOKEN_X", "REFUSED_BUDGET_X"],
        &AiroRiskMapping.risk_concept_for/1
      )

    assert MapSet.size(MapSet.new(concepts)) == length(concepts)
  end
end
