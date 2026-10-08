defmodule Xaas.Deepening.Art102h103DatasetGateCausalityTest do
  @moduledoc """
  W984a — corpus deepening wave 3: EU AI Act Art. 10(2)(h) + Art. 10(3)
  bound to the real executed dataset gate (`Xaas.Semantics.DatasetAdmission`).

  Article text (docs/eu_ai_act/corpus.json):

    * 10.2.h — "techniques to ensure... appropriate measures to detect,
      prevent, mitigate... identification of gaps, and how those gaps are
      addressed" (Art. 10(2)(h): data-governance duties incl. examination
      for gaps). The executed gap identification is the completeness gate:
      `admit/2` computes `completeness/2` over the real samples and refuses
      typed `{:error, {:REFUSED_INCOMPLETE_DATASET, %{completeness:, threshold:}}}`
      — the refusal IS the gap identification, carried numerically.
    * 10.3 — "data governance: ... relevant, sufficiently representative...
      examination in view of the intended purpose" — the executed
      representativeness examination is the sliced-W1 bias gate, and the
      completeness/bias gates compose in the documented order.

  What is deepened beyond the existing W502 court
  (test/xaas/semantics/dataset_admission_test.exs — single-gate verdicts,
  determinism, overflow) and the W982z FRIA-evidence courts (bias gate
  both directions as FRIA evidence):

    1. GATE ORDER — a dataset that is simultaneously incomplete AND biased
       refuses with the COMPLETENESS atom first (documented gate order
       1→2→3 in the moduledoc). Mutation rationale: reordering the gates in
       lib/xaas/semantics/dataset_admission.ex (bias before completeness)
       passes every existing single-gate court but fails this one — the
       order is itself the evidenced behavior of Art. 10(2)(h) before 10(3).
    2. THRESHOLD CAUSALITY (Art. 10(2)(h) gap identification as a function
       of the eta call argument): the same boundary dataset flips between
       ADMITTED and typed incomplete refusal purely by eta — and the
       measured completeness in the refusal/admit envelope equals an
       INDEPENDENT recomputation of `completeness/2` over the same samples
       (the gap is identified by the executed measure, not an invented
       number). Mutation rationale: hardcoding completeness, dropping the
       eta parameter from the comparison, or drifting the envelope value
       from the executed measure all fail court 2 while structure courts
       still pass.
    3. ART. 10(3) REPRESENTATIVENESS MEASURE IDENTITY: the `w1_proxy` in
       the ADMITTED envelope equals an independent recomputation of the
       executed `sliced_w1/3` over the same samples and seed (the
       representativeness examination is the executed measure, end to end).
       Mutation rationale: any drift between the envelope's declared
       representativeness number and the real gate computation fails, while
       verdict-level courts still pass.

  Chicago-style: real pure-module executions over real sample data — no
  mocks, no doubles; assertions are on final returned state only.
  """

  use ExUnit.Case, async: true

  @moduletag :eu_ai_act

  alias Xaas.Semantics.DatasetAdmission

  @seed 98_401

  # A balanced, gap-free population: sensitive 0/1 halves with IDENTICAL
  # feature distributions, so the bias (W1) gate measures ~0 and the
  # verdict isolates the completeness gate.
  defp balanced_samples(n, feature_fun) do
    for i <- 1..n do
      v = feature_fun.(i)

      %{
        features: %{a: v, b: v},
        label: :ok,
        sensitive: rem(i, 2)
      }
    end
  end

  # Same population with `missing` of the samples missing field :b —
  # completeness becomes (2n - missing) / 2n.
  defp gapped_samples(n, missing, feature_fun) do
    balanced_samples(n, feature_fun)
    |> Enum.with_index()
    |> Enum.map(fn {s, idx} ->
      if idx < missing, do: put_in(s, [:features, :b], nil), else: s
    end)
    |> Enum.map(&%{&1 | features: Map.new(&1.features)})
  end

  test "gate order: incomplete + biased refuses INCOMPLETE first (Art 10(2)(h) gap identification precedes the Art 10(3) bias examination)" do
    # Maximally biased: sensitive=1 population at 100.0, sensitive=0 at 0.0
    # — W1 is far above any epsilon. Also half the samples miss :b, so
    # completeness 12/16 = 0.75 < 1 - 0.1.
    samples =
      gapped_samples(8, 4, fn i -> if rem(i, 2) == 1, do: 100.0, else: 0.0 end)

    assert {:error, {:REFUSED_INCOMPLETE_DATASET, %{completeness: c, threshold: t}}} =
             DatasetAdmission.admit(samples,
               seed: @seed,
               eta: 0.1,
               epsilon_bias: 0.01,
               required_fields: [:a, :b]
             )

    assert c == 0.75
    assert t == 1 - 0.1

    # The same bias, on a COMPLETE dataset, reaches the bias gate — the
    # refusal difference is caused by the gap gate running first, not by
    # the bias being unmeasurable.
    complete_biased = balanced_samples(8, fn i -> if rem(i, 2) == 1, do: 100.0, else: 0.0 end)

    assert {:error, {:REFUSED_BIAS_THRESHOLD, _}} =
             DatasetAdmission.admit(complete_biased,
               seed: @seed,
               eta: 0.1,
               epsilon_bias: 0.01,
               required_fields: [:a, :b]
             )
  end

  test "eta threshold causality: the same boundary dataset flips ADMITTED <-> typed incomplete purely on the eta call argument, with the gap identified numerically" do
    # 10 samples x 2 required fields = 20 slots; 2 missing -> completeness
    # exactly 18/20 = 0.9.
    samples = gapped_samples(10, 2, fn _i -> 1.0 end)

    # eta = 0.1: threshold 1 - 0.1 = 0.9; completeness >= threshold admits.
    assert {:ok, :ADMITTED, %{completeness: 0.9}} =
             DatasetAdmission.admit(samples,
               seed: @seed,
               eta: 0.1,
               epsilon_bias: 0.5,
               required_fields: [:a, :b]
             )

    # eta = 0.05: threshold 0.95 > 0.9 — the IDENTICAL samples now refuse,
    # with the gap carried as measured completeness + threshold.
    assert {:error, {:REFUSED_INCOMPLETE_DATASET, %{completeness: 0.9, threshold: 0.95}}} =
             DatasetAdmission.admit(samples,
               seed: @seed,
               eta: 0.05,
               epsilon_bias: 0.5,
               required_fields: [:a, :b]
             )

    # Completeness strictly below the threshold refuses too.
    fewer = gapped_samples(10, 3, fn _i -> 1.0 end)

    assert {:error, {:REFUSED_INCOMPLETE_DATASET, %{completeness: 0.85, threshold: 0.9}}} =
             DatasetAdmission.admit(fewer,
               seed: @seed,
               eta: 0.1,
               epsilon_bias: 0.5,
               required_fields: [:a, :b]
             )

    # The identified gap equals an INDEPENDENT recomputation of the
    # executed measure over the same samples (evidence pointer, not an
    # invented number).
    for s <- [samples, fewer] do
      assert {:error, {:REFUSED_INCOMPLETE_DATASET, %{completeness: c}}} =
               DatasetAdmission.admit(s,
                 seed: @seed,
                 eta: 0.05,
                 epsilon_bias: 0.5,
                 required_fields: [:a, :b]
               )

      assert c == DatasetAdmission.completeness(s, [:a, :b])
    end
  end

  test "Art 10(3) representativeness: the ADMITTED envelope's w1_proxy equals an independent recomputation of the executed sliced_w1/3" do
    seed = 606_042

    # A near-identical population (W1 well below 0.5) so the bias gate
    # admits and the envelope carries the measured representativeness.
    samples =
      for base <- 1..6, s <- [0, 1] do
        # Both sensitive populations cover the SAME value range; a tiny
        # jitter on group 1 keeps the measured W1 nonzero but admitable.
        jitter = if s == 1, do: 0.001, else: 0.0

        %{features: %{a: base * 1.0 + jitter, b: base * 1.0}, label: :ok, sensitive: s}
      end

    assert {:ok, :ADMITTED, %{w1_proxy: w1, completeness: comp, projections: k}} =
             DatasetAdmission.admit(samples,
               seed: seed,
               epsilon_bias: 0.5,
               projections: 16,
               required_fields: [:a, :b]
             )

    assert comp == 1.0
    assert k == 16

    # Independent recomputation via the public executed helper, same seed.
    assert w1 == DatasetAdmission.sliced_w1(samples, seed, 16)
    assert is_float(w1) and w1 >= 0.0
  end
end
