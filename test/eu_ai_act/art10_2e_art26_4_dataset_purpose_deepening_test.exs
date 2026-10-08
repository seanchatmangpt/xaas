defmodule Xaas.EUAIAct.Art10_2eArt26_4DatasetPurposeDeepeningTest do
  @moduledoc """
  Lane W984ec — corpus evidenced-line deepening, Art. 10(2)(e) + Art. 26(4)
  (dataset suitability / input-data relevance in view of the INTENDED PURPOSE).

  Statute (Regulation (EU) 2024/1689):

    * Art. 10(2)(e): training, testing and validation data shall undergo
      "examination in view of its intended purposes" — availability, quantity
      and suitability.
    * Art. 26(4): the deployer shall monitor the operation of the AI system
      "with a view to ... the input data ... being relevant and sufficiently
      representative in view of the intended purpose" — a duty that is,
      by construction, under the deployer's control.

  Prior coverage: the generated EVIDENCED tests in `title_iii_test.exs` assert
  surface EXISTENCE (evidence paths on disk, gate-order block present).
  Waves 1–7 took 10.2.f, 10.2.g, 10.2.h, 10.3 (bias envelope, gate causality).
  The completeness/intended-purpose leg (10.2.e) and the deployer-control leg
  (26.4) were court-free. These courts assert the repo's REAL typed behavior
  on those legs.

  Chicago discipline: real `Xaas.Semantics.DatasetAdmission` executions over
  real in-test populations; assertions on final returned state; zero mocks.
  Zero-config: every threshold/field set is a call argument — no application
  env participates.
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.DatasetAdmission

  @moduletag :eu_ai_act

  # -- fixtures --------------------------------------------------------------

  # A balanced, bias-free population: identical features regardless of the
  # sensitive attribute, so the sliced-W1 projection law yields w1_proxy == 0.0
  # exactly, isolating the completeness/intended-purpose leg under test.
  defp sample(sensitive, feature_overrides \\ %{}) do
    %{
      features: Map.merge(%{score: 0.5, tenure: 2.0}, feature_overrides),
      label: :approve,
      sensitive: sensitive
    }
  end

  defp purpose_population do
    for i <- 1..10 do
      if rem(i, 10) == 0 do
        # exactly one sample (i == 10) misses the purpose-relevant field
        sample(0, %{purpose_score: nil})
      else
        sample(rem(i, 2), %{purpose_score: 0.7})
      end
    end
  end

  # -- Court 1 — 10.2.e: suitability verdict binds the MEASURED completeness --

  test "10.2.e - suitability verdict flips exactly at the measured completeness against the eta threshold" do
    # Ground truth measured by the REAL gate, not by the test: run admit/2
    # with a huge eta so the completeness gate cannot bind, and read the
    # measured completeness out of the ADMITTED envelope.
    {:ok, :ADMITTED, %{completeness: measured, w1_proxy: w1}} =
      DatasetAdmission.admit(purpose_population(),
        seed: 7,
        eta: 1.0,
        required_fields: [:purpose_score],
        epsilon_bias: 100.0
      )

    # Real contract fact (W984ec repair): the sliced-W1 projection vector
    # includes the purpose field, so the nil-carrier sample makes the groups
    # asymptotically distinct — w1 is NOT identically 0.0 on this fixture.
    # The isolation of the completeness leg instead comes from epsilon being
    # set far above any reachable w1 (100.0), so only completeness can refuse.
    assert is_float(w1) and w1 >= 0.0
    assert is_float(measured) and measured > 0.0 and measured < 1.0

    # The measured completeness is exactly the share of non-nil purpose_score
    # over the population (independent recomputation over the raw fixtures).
    non_nil =
      purpose_population()
      |> Enum.count(&(not is_nil(&1.features[:purpose_score])))

    total = length(purpose_population())
    assert measured == non_nil / total

    # Boundary discipline: the gate refuses when completeness < 1 - eta
    # STRICTLY, so eta == 1 - measured places the threshold exactly ON the
    # measured value and the dataset must still be ADMITTED.
    on_boundary = 1.0 - measured

    assert {:ok, :ADMITTED, %{completeness: ^measured}} =
             DatasetAdmission.admit(purpose_population(),
               seed: 7,
               eta: on_boundary,
               required_fields: [:purpose_score]
             )

    # One notch tighter flips the verdict to the typed refusal, and the
    # refusal envelope echoes the REAL measured value and threshold.
    assert {:error, {:REFUSED_INCOMPLETE_DATASET,
                     %{completeness: ^measured, threshold: tighter}}} =
             DatasetAdmission.admit(purpose_population(),
               seed: 7,
               eta: on_boundary - 1.0e-6,
               required_fields: [:purpose_score]
             )

    assert tighter == 1.0 - (on_boundary - 1.0e-6)
    assert tighter > measured
  end

  # -- Court 2 — 10.2.e: availability/quantity leg of the intended purpose ----

  test "10.2.e - availability/quantity: a population missing the purpose field everywhere is refused, and the deployer's declared field set determines availability" do
    # Art. 10(2)(e) names availability and QUANTITY alongside suitability. The
    # gate realizes the quantity leg through population size/non-totality:
    # an empty population carries zero evidence for ANY intended purpose.
    assert {:error, :REFUSED_EMPTY_DATASET} =
             DatasetAdmission.admit([], seed: 7, eta: 1.0)

    # Non-totality at any size means the purpose-relevant field is not even
    # AVAILABLE across the declared quantity: tighten eta so the measured
    # non-nil share cannot clear the floor.
    thin =
      purpose_population()
      |> Enum.map(fn s -> put_in(s.features[:purpose_score], nil) end)

    assert {:error, {:REFUSED_INCOMPLETE_DATASET, %{completeness: measured, threshold: floor}}} =
             DatasetAdmission.admit(thin,
               seed: 7,
               eta: 0.05,
               required_fields: [:purpose_score]
             )

    # the measured completeness on the fully-missed field is exactly 0.0
    assert measured == 0.0
    assert floor == 0.95

    # and the SAME population with NO field declared required admits with
    # completeness 1.0 — the deployer's declared field set, not the raw
    # data alone, determines availability. (Real exec, both verdicts.)
    assert {:ok, :ADMITTED, %{completeness: 1.0}} =
             DatasetAdmission.admit(thin, seed: 7, eta: 0.05)
  end

  # -- Court 3 — 26.4: deployer control + declared gate order -----------------

  test "26.4 - deployer control: call-argument knobs alone flip the verdict, and the completeness gate precedes the bias gate on a doubly-defective population" do
    pop = purpose_population()

    # (a) Deployer control via the eta knob: identical data, the deployer's
    # threshold is the only thing that changes between ADMITTED and refusal.
    assert {:ok, :ADMITTED, _} =
             DatasetAdmission.admit(pop,
               seed: 7,
               eta: 0.5,
               required_fields: [:purpose_score]
             )

    assert {:error, {:REFUSED_INCOMPLETE_DATASET, _}} =
             DatasetAdmission.admit(pop,
               seed: 7,
               eta: 0.05,
               required_fields: [:purpose_score]
             )

    # (b) Deployer control via the required-field set: the same population,
    # the same eta, a different declared purpose field set.
    assert {:ok, :ADMITTED, _} =
             DatasetAdmission.admit(pop, seed: 7, eta: 0.05, required_fields: [:score])

    # (c) Declared gate ORDER on a doubly-defective population: the dataset
    # is both fully incomplete on the purpose field AND maximally biased
    # (all sensitive=0 vs all sensitive=1 across differing features). The
    # declared order is completeness BEFORE bias, so the typed refusal must
    # be INCOMPLETE, never BIAS — the deployer sees the gate that binds FIRST.
    biased_and_incomplete =
      Enum.map(1..6, fn i ->
        if rem(i, 2) == 0 do
          sample(1, %{score: 9.0, purpose_score: nil})
        else
          sample(0, %{score: -9.0, purpose_score: nil})
        end
      end)

    assert {:error, {:REFUSED_INCOMPLETE_DATASET, _}} =
             DatasetAdmission.admit(biased_and_incomplete,
               seed: 7,
               eta: 0.05,
               required_fields: [:purpose_score]
             )

    # Same population with the completeness gate disabled (eta = 1) exposes
    # the bias gate behind it: the refusal now names the BIAS threshold with
    # the real measured w1_proxy and the deployer's epsilon.
    assert {:error, {:REFUSED_BIAS_THRESHOLD,
                     %{w1_proxy: w1, epsilon_bias: 0.001}}} =
             DatasetAdmission.admit(biased_and_incomplete,
               seed: 7,
               eta: 1.0,
               required_fields: [:purpose_score],
               epsilon_bias: 0.001
             )

    assert w1 > 0.001
  end
end
