defmodule Xaas.Deepening.Art271cdFriaEvidenceLivenessTest do
  @moduledoc """
  Lane W982z — evidenced-line deepening wave 2, corpus lines **27.1.c**
  ("the categories of natural persons and groups likely to be affected by
  its use in the specific context") and **27.1.d** ("the specific risks of
  harm likely to have an impact on the categories of natural persons or
  groups of persons identified pursuant to point (c)...").

  `oversight_governance_test.exs` (w537) courts only the STRUCTURE of
  `fria/0` (per-right fields nonempty, cited paths exist, determinism).
  The uncovered property is EVIDENCE LIVENESS: the FRIA names refusal
  atoms as per-right protections — the deepening court executes the cited
  surfaces for real and asserts the executed typed contracts match the
  claimed bases, so the FRIA's affected-persons/harm-risk entries are
  machine-checkable facts, not prose.

  Mutation rationale: if a cited surface's refusal contract drifts from
  the FRIA's claimed basis (e.g. `DatasetAdmission` stops returning
  `REFUSED_BIAS_THRESHOLD`, or `EuAiActAdmission` loses/reframes one of
  the eight Art. 5(1) atoms), the evidence-liveness courts here fail
  while the structural FRIA courts (path existence, nonempty text,
  determinism) still pass — catching an assessment decorated with atom
  names the machinery no longer returns.

  Chicago discipline: real deterministic modules over seeded data; no
  mocks, no DB needed.
  """

  use ExUnit.Case, async: true

  # 27.1.c/27.1.d are evidenced corpus lines (w537) — eu_ai_act census.
  @moduletag :eu_ai_act

  alias Xaas.Semantics.DatasetAdmission
  alias Xaas.Semantics.EuAiActAdmission
  alias Xaas.Semantics.OversightGovernance

  # Minimal real candidates, one per Art. 5(1)(a)-(h) refusal atom,
  # derived from the module's own structural predicates (read, not
  # guessed): each refuses with exactly its atom on an otherwise-lawful
  # candidate.
  defp candidates_for_atoms do
    %{
      REFUSED_EUAIA_MANIPULATIVE: %{techniques: [:manipulate_behavior]},
      REFUSED_EUAIA_VULNERABILITY_EXPLOIT: %{techniques: [:exploit_vulnerability]},
      REFUSED_EUAIA_SOCIAL_SCORING: %{
        data_domains: [:social_behavior],
        context_joins: [:unrelated_context_join]
      },
      REFUSED_EUAIA_PREDICTIVE_POLICING: %{
        purpose: :predict_offending,
        context_joins: [:individualized_profile_join]
      },
      REFUSED_EUAIA_FACIAL_SCRAPING: %{data_domains: [:facial_images]},
      REFUSED_EUAIA_EMOTION_RECOGNITION: %{techniques: [:emotion_recognition]},
      REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION: %{
        data_domains: [:biometric],
        inferences: [:race]
      },
      REFUSED_EUAIA_REALTIME_RBI: %{
        setting: :public_space,
        data_domains: [:biometric_identification],
        latency_goal: :realtime
      }
    }
  end

  test "every Art. 5(1) atom the FRIA's due-process evidence names is executed for real" do
    {:ok, fria} = OversightGovernance.fria()
    due = Enum.find(fria.rights, &(&1.right == :due_process))

    # The FRIA claims the eight typed Art. 5 refusal atoms as protection —
    # the citation must be present as data.
    assert Enum.any?(due.evidence, fn e ->
             e.path == "lib/xaas/semantics/eu_ai_act_admission.ex" and
               e.basis =~ "eight typed Art. 5 refusal atoms"
           end)

    # ... and the claim is LIVE: every declared atom is reachable for real,
    # each describe/1 names its Art. 5(1) partition, and the executed set
    # equals the declared set (no phantom atoms, no missing atoms).
    declared = MapSet.new(EuAiActAdmission.refusal_atoms() -- [:REFUSED_EUAIA_MALFORMED_CANDIDATE])
    assert MapSet.size(declared) == 8

    executed =
      candidates_for_atoms()
      |> Enum.map(fn {atom, candidate} ->
        assert {:error, ^atom} = EuAiActAdmission.admit(candidate)
        assert describe = EuAiActAdmission.describe(atom)
        assert describe =~ "Art. 5(1)"
        assert atom in EuAiActAdmission.refusal_atoms()
        atom
      end)
      |> MapSet.new()

    assert executed == declared,
           "executed atom set != declared set: #{inspect(MapSet.to_list(executed))}"
  end

  test "non-discrimination protection is live: the real bias gate refuses with the FRIA-named atom" do
    {:ok, fria} = OversightGovernance.fria()
    nd = Enum.find(fria.rights, &(&1.right == :non_discrimination))

    assert Enum.any?(nd.evidence, &(&1.basis == "REFUSED_BIAS_THRESHOLD"))

    # Real skewed population: group A=0 at ~0, group A=1 at ~100 —
    # W1_proxy far above epsilon (fixture shape from title_ii_deepening).
    skewed =
      Enum.map(1..20, fn i ->
        [
          %{features: %{x: 0.0}, label: :ok, sensitive: 0},
          %{features: %{x: 100.0 + i * 0.1}, label: :ok, sensitive: 1}
        ]
      end)
      |> List.flatten()

    assert {:error, {:REFUSED_BIAS_THRESHOLD, %{w1_proxy: w1, epsilon_bias: eps}}} =
             DatasetAdmission.admit(skewed, seed: 691, epsilon_bias: 0.1)

    assert is_float(w1) and w1 > eps

    # Fail-closed in both directions is witnessed: a balanced population
    # under the same opts admits with a measured w1_proxy within threshold.
    balanced =
      Enum.map(1..20, fn i ->
        [
          %{features: %{x: i * 1.0}, label: :ok, sensitive: 0},
          %{features: %{x: i * 1.0}, label: :ok, sensitive: 1}
        ]
      end)
      |> List.flatten()

    assert {:ok, :ADMITTED, %{w1_proxy: w1_b, completeness: 1.0}} =
             DatasetAdmission.admit(balanced, seed: 691, epsilon_bias: 0.1)

    assert is_float(w1_b) and w1_b <= 0.1

    # Determinism ×2 over the real surface: identical inputs, identical
    # measured quantities.
    assert DatasetAdmission.admit(skewed, seed: 691, epsilon_bias: 0.1) ==
             DatasetAdmission.admit(skewed, seed: 691, epsilon_bias: 0.1)
  end

  test "privacy protection is live: the admission checks never inspect undeclared fields" do
    {:ok, fria} = OversightGovernance.fria()
    privacy = Enum.find(fria.rights, &(&1.right == :privacy))

    # The FRIA's zero-PII claim, present as data.
    assert Enum.any?(privacy.evidence, fn e ->
             e.path == "lib/xaas/semantics/eu_ai_act_admission.ex" and
               e.basis =~ "never inspects free text"
           end)

    # Liveness: the decision over a candidate is INVARIANT under injected
    # undeclared PII-shaped fields — the gate reads only the declared
    # intent schema, for real.
    junk = %{
      free_text_notes: "patient record SSN-123-45-6789",
      model_output: "generated user content",
      user_data: %{email: "victim@example.com"}
    }

    refused_clean = %{techniques: [:manipulate_behavior]}
    refused_dirty = Map.merge(refused_clean, junk)
    lawful_clean = %{purpose: :classify_document}
    lawful_dirty = Map.merge(lawful_clean, junk)

    assert EuAiActAdmission.admit(refused_clean) == {:error, :REFUSED_EUAIA_MANIPULATIVE}
    assert EuAiActAdmission.admit(refused_dirty) == EuAiActAdmission.admit(refused_clean)
    assert EuAiActAdmission.admit(lawful_clean) == {:ok, :admitted}
    assert EuAiActAdmission.admit(lawful_dirty) == EuAiActAdmission.admit(lawful_clean)

    # Determinism ×2 over the real surface.
    assert EuAiActAdmission.admit(refused_dirty) == EuAiActAdmission.admit(refused_dirty)
    assert EuAiActAdmission.admit(lawful_dirty) == EuAiActAdmission.admit(lawful_dirty)
  end
end
