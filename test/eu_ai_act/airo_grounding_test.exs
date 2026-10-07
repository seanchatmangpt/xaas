defmodule Xaas.EuAiAct.AiroGroundingTest do
  @moduledoc """
  W702 AIRo grounding court (gymact→xaas gap wave; gymact parity with
  `tests/test_airo_risk_description.py`, lane W603's pattern).

  Gymact pins its AIRo risk description TTL and requires that every cited
  consumer file exists BEFORE anything else — grounding is the point. Xaas
  vendors the same AIRo vocabulary (W600/W621b) and projects a risk graph
  over the refusal ledger (W601), but the eu_ai_act suite never tied its
  typed refusal atoms back to the AIRo risk vocabulary. This court closes
  that gap: every Art. 5 refusal atom is grounded to an AIRo risk concept
  in the W601 risk graph, and every AIRo-emitting consumer file cited here
  exists on disk before anything else is asserted.
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.AiroRiskMapping
  alias Xaas.Semantics.EuAiActAdmission

  @repo_root Path.expand("../..", __DIR__)
  @airo_relpath "priv/semantic/airo/airo.ttl"
  @airo_pin_test_relpath "test/xaas/semantics/airo_vendored_pin_test.exs"
  @airo_mapping_test_relpath "test/xaas/semantics/airo_risk_mapping_test.exs"

  @doc """
  Deterministic AIRo risk concept for one Art. 5 refusal atom, via the
  mapping's own family function applied to the atom string.
  """
  def risk_concept_for_atom(atom_string) do
    AiroRiskMapping.risk_concept_for(atom_string)
  end

  test "cited AIRo consumer files exist BEFORE anything else (grounding first)" do
    missing =
      [
        Path.join(@repo_root, @airo_relpath),
        Path.join(@repo_root, @airo_pin_test_relpath),
        Path.join(@repo_root, @airo_mapping_test_relpath)
      ]
      |> Enum.reject(&File.exists?/1)

    assert missing == [], "cited AIRo files missing on disk: #{inspect(missing)}"
  end

  test "vendored airo.ttl carries the real AIRo namespace" do
    text = File.read!(Path.join(@repo_root, @airo_relpath))
    assert text =~ "https://w3id.org/airo#"
  end

  test "eu_ai_act Art. 5 refusal atoms are non-empty and each has a describe/2" do
    atoms = EuAiActAdmission.refusal_atoms()
    assert is_list(atoms) and atoms != []

    for atom <- atoms do
      description = EuAiActAdmission.describe(atom)
      assert is_binary(description) and description != "", "empty describe for #{inspect(atom)}"
    end
  end

  test "W657 EVIDENCED: each Art. 5 atom grounds to its own EUAIA risk concept" do
    # Flipped from the W702 pinned gap: `risk_concept_for/1` now carries the
    # EUAIA family (W657), so every Art. 5 atom maps to a distinct
    # dissertation-partition concept instead of UNADMITTED_TRANSITION.
    expected = %{
      "REFUSED_EUAIA_MANIPULATIVE" => "RISK_TO_INFORMED_CHOICE",
      "REFUSED_EUAIA_VULNERABILITY_EXPLOIT" => "RISK_TO_VULNERABLE_PERSONS",
      "REFUSED_EUAIA_SOCIAL_SCORING" => "CROSS_CONTEXT_RISK",
      "REFUSED_EUAIA_PREDICTIVE_POLICING" => "DUE_PROCESS_RISK",
      "REFUSED_EUAIA_FACIAL_SCRAPING" => "PRIVACY_RISK",
      "REFUSED_EUAIA_EMOTION_RECOGNITION" => "MENTAL_PRIVACY_RISK",
      "REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION" => "DISCRIMINATION_RISK",
      "REFUSED_EUAIA_REALTIME_RBI" => "SURVEILLANCE_RISK"
    }

    atoms = EuAiActAdmission.refusal_atoms()
    assert length(atoms) == map_size(expected)

    for atom <- atoms do
      atom_string = to_string(atom)
      concept = risk_concept_for_atom(atom_string)

      assert concept == Map.fetch!(expected, atom_string),
             "atom #{atom_string} -> #{concept}, expected #{Map.fetch!(expected, atom_string)}"

      refute concept == "UNADMITTED_TRANSITION",
             "atom #{atom_string} still falls through to the generic fallback"
    end
  end

  test "generic fallback still correct for a truly unknown (bogus) atom" do
    # The EUAIA flip must not have broken the fallback ladder: a variant that
    # matches no family still grounds to the typed generic concept.
    assert AiroRiskMapping.risk_concept_for("REFUSED_TOTALLY_BOGUS_ATOM") ==
             "UNADMITTED_TRANSITION"

    # ...and the fallback remains a deterministic pure function.
    assert AiroRiskMapping.risk_concept_for("REFUSED_TOTALLY_BOGUS_ATOM") ==
             AiroRiskMapping.risk_concept_for("REFUSED_TOTALLY_BOGUS_ATOM")
  end

  test "every Art. 5 refusal atom grounds to a deterministic, emitted AIRo risk concept" do
    for {atom_string, _} <- Enum.map(EuAiActAdmission.refusal_atoms(), &{to_string(&1), nil}) do
      concept = risk_concept_for_atom(atom_string)

      assert is_binary(concept) and concept != "" and concept != "UNKNOWN",
             "atom #{atom_string} grounds to a generic concept"

      # determinism: the grounding is a pure function of the atom
      assert risk_concept_for_atom(atom_string) == concept
    end
  end

  test "grounded concepts are emitted by the W601 AIRo risk graph" do
    graph = AiroRiskMapping.risk_graph()

    concepts =
      EuAiActAdmission.refusal_atoms()
      |> MapSet.new(&risk_concept_for_atom(to_string(&1)))

    assert MapSet.size(concepts) > 0

    for concept <- concepts do
      assert String.contains?(graph, "mapsToRiskConcept ex:#{concept}"),
             "AIRo risk concept #{concept} not emitted by the W601 risk graph"
    end
  end
end
