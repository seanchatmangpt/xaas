defmodule Xaas.Semantics.EuAiActAdmissionTest do
  @moduledoc """
  Chicago fixtures for the Art. 5(1)(a)-(h) constructive-nullification admission
  profile. No mocks: the real `Xaas.Semantics.EuAiActAdmission` module over
  plain intent maps, asserting on the exact typed refusal atoms.

  Each partition gets one positive lawful case (admitted) and one violating
  case (exact refusal atom), plus an adversarial multi-partition combination
  case and a mutant-kill witness.

  Mutant-kill witness (anti-vacuity protocol, receipt
  docs/sjira/v26.10.6/plans/w500-art5-admission.md): weakening the (e) emotion
  check's setting disjointness (`affective_in_context?/1` → drop the
  workplace/education conjunct) makes
  `test "(e) emotion recognition in workplace/education is refused"` fail with
  `:ok` instead of `:REFUSED_EUAIA_EMOTION_RECOGNITION`; the check was
  restored and the full suite passes again. The suite is non-vacuous: every
  refusal atom has a killing fixture.
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.EuAiActAdmission

  @lawful_base %{
    id: "lawful-base",
    techniques: [:nudge_transparent],
    purpose: :recommend_content,
    data_domains: [:interaction_events],
    provenance: :consented,
    context_joins: [:own_service_context],
    setting: :consumer_web,
    latency_goal: :batch,
    inferences: [],
    match_token_type: :boolean
  }

  defp lawful(overrides \\ []) do
    Map.merge(@lawful_base, Map.new(overrides))
  end

  describe "admission surface contract" do
    test "nine refusal atoms exposed: 8 Art. 5(1) atoms in article order + malformed fallback" do
      assert EuAiActAdmission.refusal_atoms() == [
               :REFUSED_EUAIA_MANIPULATIVE,
               :REFUSED_EUAIA_VULNERABILITY_EXPLOIT,
               :REFUSED_EUAIA_SOCIAL_SCORING,
               :REFUSED_EUAIA_PREDICTIVE_POLICING,
               :REFUSED_EUAIA_FACIAL_SCRAPING,
               :REFUSED_EUAIA_EMOTION_RECOGNITION,
               :REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION,
               :REFUSED_EUAIA_REALTIME_RBI,
               # W732 closure repair (W713 typed finding): the admit/1
               # fallback verdict is a declared refusal atom.
               :REFUSED_EUAIA_MALFORMED_CANDIDATE
             ]
    end

    test "describe/1 maps Art. 5(1) atoms to their partition; malformed atom to its schema-shape class" do
      for atom <- EuAiActAdmission.refusal_atoms() -- [:REFUSED_EUAIA_MALFORMED_CANDIDATE] do
        assert String.starts_with?(EuAiActAdmission.describe(atom), "Art. 5(1)")
      end

      # W732: the malformed fallback is a declared atom but not an Art. 5(1)
      # prohibited-practice partition.
      refute String.starts_with?(
               EuAiActAdmission.describe(:REFUSED_EUAIA_MALFORMED_CANDIDATE),
               "Art. 5(1)"
             )
    end

    test "plain lawful candidate is admitted, not classified" do
      assert {:ok, :admitted} = EuAiActAdmission.admit(lawful())
    end

    test "malformed (non-map) candidate is refused as malformed, not sniffed" do
      assert {:error, :REFUSED_EUAIA_MALFORMED_CANDIDATE} =
               EuAiActAdmission.admit("classify this text")

      # W732 regression: the emitted atom is a member of the declared closed
      # set and grounds through the W657 MALFORMED family to a real AIRo
      # risk concept (no sentinel, no generic fallback).
      assert :REFUSED_EUAIA_MALFORMED_CANDIDATE in EuAiActAdmission.refusal_atoms()

      assert Xaas.Semantics.AiroRiskMapping.risk_concept_for("REFUSED_EUAIA_MALFORMED_CANDIDATE") ==
               "MALFORMED_INPUT_CANDIDATE"
    end

    test "unknown extra fields never affect the verdict (content-blindness)" do
      noisy = Map.merge(lawful(), %{free_text: "any content whatsoever", score: 0.42})
      assert {:ok, :admitted} = EuAiActAdmission.admit(noisy)
    end
  end

  # -- (a) manipulative -------------------------------------------------------

  describe "(a) REFUSED_EUAIA_MANIPULATIVE" do
    test "transparent persuasion is admitted" do
      assert {:ok, :admitted} =
               EuAiActAdmission.admit(lawful(techniques: [:nudge_transparent, :personalized_ranking]))
    end

    test "subliminal/deceptive technique class is refused" do
      assert {:error, :REFUSED_EUAIA_MANIPULATIVE} =
               EuAiActAdmission.admit(lawful(techniques: [:subliminal]))
    end
  end

  # -- (a) vulnerability exploit ----------------------------------------------

  describe "(a) REFUSED_EUAIA_VULNERABILITY_EXPLOIT" do
    test "audience targeting without a vulnerability predicate is admitted" do
      assert {:ok, :admitted} =
               EuAiActAdmission.admit(
                 lawful(techniques: [:audience_targeting], purpose: :recommend_content)
               )
    end

    test "audience-slice x vulnerability-predicate join is refused" do
      assert {:error, :REFUSED_EUAIA_VULNERABILITY_EXPLOIT} =
               EuAiActAdmission.admit(
                 lawful(techniques: [:exploit_vulnerability], purpose: :drive_purchase)
               )
    end
  end

  # -- (b) social scoring -------------------------------------------------------

  describe "(b) REFUSED_EUAIA_SOCIAL_SCORING" do
    test "domain-scoped social data with own-service join is admitted" do
      assert {:ok, :admitted} =
               EuAiActAdmission.admit(
                 lawful(
                   data_domains: [:social_behavior],
                   context_joins: [:own_service_context]
                 )
               )
    end

    test "social-behavior data joined into an unrelated decision context is refused" do
      assert {:error, :REFUSED_EUAIA_SOCIAL_SCORING} =
               EuAiActAdmission.admit(
                 lawful(
                   data_domains: [:social_behavior],
                   context_joins: [:unrelated_context_join]
                 )
               )
    end
  end

  # -- (c) predictive policing --------------------------------------------------

  describe "(c) REFUSED_EUAIA_PREDICTIVE_POLICING" do
    test "evidence-based offending analysis without individualized joins is admitted" do
      assert {:ok, :admitted} =
               EuAiActAdmission.admit(
                 lawful(
                   purpose: :predict_offending,
                   context_joins: [:evidence_based_join]
                 )
               )
    end

    test "offend-prediction purpose with an individualized profile join is refused" do
      assert {:error, :REFUSED_EUAIA_PREDICTIVE_POLICING} =
               EuAiActAdmission.admit(
                 lawful(
                   purpose: :predict_offending,
                   context_joins: [:individualized_profile_join]
                 )
               )
    end
  end

  # -- (d) facial scraping --------------------------------------------------------

  describe "(d) REFUSED_EUAIA_FACIAL_SCRAPING" do
    test "consented facial images are admitted" do
      assert {:ok, :admitted} =
               EuAiActAdmission.admit(
                 lawful(data_domains: [:facial_images], provenance: :consented)
               )
    end

    test "facial images of non-consented (scraped) provenance are refused" do
      assert {:error, :REFUSED_EUAIA_FACIAL_SCRAPING} =
               EuAiActAdmission.admit(
                 lawful(data_domains: [:facial_images], provenance: :scraped)
               )
    end
  end

  # -- (e) emotion recognition -----------------------------------------------------

  describe "(e) REFUSED_EUAIA_EMOTION_RECOGNITION" do
    test "affective analysis outside workplace/education is admitted" do
      assert {:ok, :admitted} =
               EuAiActAdmission.admit(lawful(data_domains: [:affective], setting: :consumer_web))
    end

    test "affective-state domain in workplace/education settings is refused" do
      assert {:error, :REFUSED_EUAIA_EMOTION_RECOGNITION} =
               EuAiActAdmission.admit(lawful(data_domains: [:affective], setting: :workplace))

      assert {:error, :REFUSED_EUAIA_EMOTION_RECOGNITION} =
               EuAiActAdmission.admit(lawful(data_domains: [:affective], setting: :education))
    end
  end

  # -- (f) biometric categorization --------------------------------------------------

  describe "(f) REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION" do
    test "boolean-only biometric verification with no sensitive inferences is admitted" do
      assert {:ok, :admitted} =
               EuAiActAdmission.admit(
                 lawful(
                   data_domains: [:biometric],
                   inferences: [],
                   match_token_type: :boolean
                 )
               )
    end

    test "biometric surface with sensitive attribute inferences is refused" do
      assert {:error, :REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION} =
               EuAiActAdmission.admit(
                 lawful(
                   data_domains: [:biometric],
                   inferences: [:race, :political_opinion],
                   match_token_type: :boolean
                 )
               )
    end

    test "biometric surface with non-boolean (attribute-vector) match tokens is refused" do
      assert {:error, :REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION} =
               EuAiActAdmission.admit(
                 lawful(
                   data_domains: [:biometric],
                   inferences: [],
                   match_token_type: :attribute_vector
                 )
               )
    end
  end

  # -- (g)/(h) realtime RBI ------------------------------------------------------------

  describe "(g)(h) REFUSED_EUAIA_REALTIME_RBI" do
    test "retrospective (batch) biometric identification in public space is admitted" do
      assert {:ok, :admitted} =
               EuAiActAdmission.admit(
                 lawful(
                   data_domains: [:biometric_identification],
                   setting: :public_space,
                   latency_goal: :batch
                 )
               )
    end

    test "realtime latency goal over public-space biometric identification is refused" do
      assert {:error, :REFUSED_EUAIA_REALTIME_RBI} =
               EuAiActAdmission.admit(
                 lawful(
                   data_domains: [:biometric_identification],
                   setting: :public_space,
                   latency_goal: :realtime
                 )
               )
    end
  end

  # -- adversarial combination ------------------------------------------------------------

  describe "adversarial combination" do
    test "candidate violating every partition simultaneously returns exactly the first (a) refusal, in article order" do
      omniviolation =
        lawful(
          techniques: [:subliminal, :exploit_vulnerability],
          purpose: :predict_offending,
          data_domains: [:social_behavior, :facial_images, :affective, :biometric_identification],
          provenance: :scraped,
          context_joins: [:unrelated_context_join, :individualized_profile_join],
          setting: :public_space,
          latency_goal: :realtime,
          inferences: [:race],
          match_token_type: :attribute_vector
        )

      assert {:error, :REFUSED_EUAIA_MANIPULATIVE} = EuAiActAdmission.admit(omniviolation)
    end

    test "removing the (a) violation surfaces the next partition in article order, not a merged verdict" do
      step =
        lawful(
          techniques: [:exploit_vulnerability],
          data_domains: [:social_behavior],
          context_joins: [:unrelated_context_join]
        )

      assert {:error, :REFUSED_EUAIA_VULNERABILITY_EXPLOIT} = EuAiActAdmission.admit(step)

      step2 = Map.merge(step, %{techniques: [:nudge_transparent]})
      assert {:error, :REFUSED_EUAIA_SOCIAL_SCORING} = EuAiActAdmission.admit(step2)
    end
  end
end
