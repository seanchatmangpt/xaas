defmodule Xaas.Deepening.Art102fgBiasGateMeasurementLivenessTest do
  @moduledoc """
  Lane W984by — evidenced-line deepening wave 7, corpus lines **10.2.f**
  and **10.2.g** (Art. 10(2)(f)/(g): bias examination, and
  detect/prevent/mitigate of biases in the data — evidence lanes W502,
  surface `lib/xaas/semantics/dataset_admission.ex`, corpus lines
  "bias examination via the sliced-W1 bias gate" and "bias
  detect/prevent/mitigate via typed bias-threshold refusal").

  Existing coverage asserts verdict-level facts only: skewed →
  REFUSED_BIAS_THRESHOLD, balanced → ADMITTED, determinism, unobservable
  population fail-closed, overflow/dim-0 typed refusals
  (`test/xaas/semantics/dataset_admission_test.exs`). W984a deepened the
  gate-order and the eta (completeness) causality and the ADMITTED
  envelope identity; W984al's 9.4 courts exercise the gate family under
  hostile env. The uncovered property class is MEASUREMENT LIVENESS of
  the executed bias measure itself:

  1. the REFUSED_BIAS_THRESHOLD envelope carries the real executed
     measurement: its `w1_proxy` equals an independent recomputation via
     the public `sliced_w1/3`, its `epsilon_bias` echoes the call
     argument, and the gate boundary is the STRICT inequality
     `w1_proxy > epsilon_bias` — the same biased population flips
     ADMITTED <-> typed bias refusal purely on the `epsilon_bias` call
     argument at the measured value as the exact boundary;
  2. the seeded projection machinery is LIVE: across seeds the measured
     `w1_proxy` genuinely varies (a hardcoded/stale seed is observable),
     across projection counts `k` the measured value genuinely depends
     on `k`, while the verdict stays stable; same-seed reruns are
     bit-identical;
  3. the executed measure is scale-equivariant: scaling every feature of
     a population by c > 0 scales the measured W1 by exactly c
     (projection directions are scale-invariant, 1-D W1 is 1-homogeneous)
     — a measure mutation that normalizes, clips, or switches to a
     non-homogeneous statistic breaks this while every verdict-level
     court still passes.

  Mutation rationale (per court):
    1. hardcoding/echoing a stale epsilon in the bias gate, or
       envelope-value drift from the executed computation, fails court 1
       while verdict-level courts still pass (any epsilon on the same
       side of the boundary gives the same verdict);
    2. freezing the seed or ignoring the `:projections` option fails
       court 2 (the measured value stops responding to seed/k) while
       single-seed verdict courts still pass;
    3. replacing the mean-over-slices W1 with a normalized or clipped
       statistic fails court 3 while verdict-level courts still pass.

  Chicago discipline: real pure-module executions of
  `DatasetAdmission.admit/2` / `sliced_w1/3` over real sample data;
  assertions on returned final state only. No mocks.
  """

  use ExUnit.Case, async: false

  # 10.2.f / 10.2.g are evidenced corpus lines (W502) — eu_ai_act census.
  @moduletag :eu_ai_act

  alias Xaas.Semantics.DatasetAdmission

  @opts [seed: 42, epsilon_bias: 0.1, eta: 0.1, projections: 16, required_fields: []]

  # A shifted population: the sensitive groups carry the same feature
  # multisets up to a constant shift `delta` along feature :a, so the
  # measured W1 is nonzero but tunable, and (being paired) every
  # direction gives the same projected shift magnitude pattern —
  # deterministic and small enough to ADMIT under epsilon 0.1.
  defp shifted_population(delta) do
    for k <- 1..10, s <- [0, 1] do
      a = k * 1.0 + if(s == 1, do: delta, else: 0.0)

      %{features: %{a: a, b: :math.fmod(k * 1.0, 3.0)}, label: :ok, sensitive: s}
    end
  end

  defp biased_population do
    # Large shift: W1 well above the 0.1 epsilon, real typed bias refusal.
    shifted_population(1.0)
  end

  # -- court 1: bias-refusal envelope identity + strict-inequality boundary --

  test "court 1 — the bias refusal carries the executed measurement: envelope w1_proxy equals the recomputed sliced_w1, epsilon echoes the call argument, and the same population flips ADMITTED <-> REFUSED_BIAS_THRESHOLD exactly at the measured value" do
    biased = biased_population()

    # The default-ish epsilon refuses with the typed envelope.
    assert {:error, {:REFUSED_BIAS_THRESHOLD, %{w1_proxy: w1, epsilon_bias: eps}}} =
             DatasetAdmission.admit(biased, @opts)

    assert eps == 0.1

    # Declared = executed: the envelope's w1_proxy is the real measure,
    # independently recomputed via the public helper.
    assert w1 == DatasetAdmission.sliced_w1(biased, 42, 16)

    # Strict boundary: refusing iff w1_proxy > epsilon. The exact measured
    # value as epsilon ADMITS (w1 > w1 is false); half a ulp below refuses.
    assert {:ok, :ADMITTED, %{w1_proxy: ^w1}} =
             DatasetAdmission.admit(biased, Keyword.put(@opts, :epsilon_bias, w1))

    below = w1 - 1.0e-12

    assert {:error, {:REFUSED_BIAS_THRESHOLD, %{w1_proxy: ^w1}}} =
             DatasetAdmission.admit(biased, Keyword.put(@opts, :epsilon_bias, below))

    # And above the measured value it admits again.
    assert {:ok, :ADMITTED, _} =
             DatasetAdmission.admit(biased, Keyword.put(@opts, :epsilon_bias, w1 + 1.0e-9))
  end

  # -- court 2: seeded measurement liveness -----------------------------------

  test "court 2 — the seeded projection machinery is live: the measured w1_proxy responds to seed and projections k, the verdict stays stable, same-seed reruns are bit-identical" do
    pop = shifted_population(0.05)

    # Same seed twice: bit-identical measured value.
    w1_a = measured(pop, 7, 16)
    assert w1_a == measured(pop, 7, 16)

    # Across seeds the measurement genuinely varies.
    seed_values =
      for seed <- 1..8, uniq: true do
        measured(pop, seed, 16)
      end

    assert length(seed_values) >= 2,
           "w1_proxy identical across 8 seeds — the seeded projection machinery is not live"

    # Across projection counts k the measurement genuinely depends on k,
    # and the envelope's projections field echoes the k actually used.
    w1_k2 = measured(pop, 42, 2)
    w1_k64 = measured(pop, 42, 64)

    assert w1_k2 != w1_k64,
           "w1_proxy identical at k=2 and k=64 — the :projections option is not live"

    # Verdict stays ADMITTED throughout (population shift 0.05 keeps every
    # seed's estimate below the 0.1 epsilon) and the envelope's projections
    # field equals the k used.
    for seed <- 1..8 do
      assert {:ok, :ADMITTED, %{w1_proxy: w1, projections: 16}} =
               DatasetAdmission.admit(pop, seed: seed, epsilon_bias: 0.1, eta: 0.1, projections: 16)

      assert w1 == DatasetAdmission.sliced_w1(pop, seed, 16)
    end
  end

  # -- court 3: scale equivariance of the executed measure --------------------

  test "court 3 — scale equivariance: scaling every feature by c > 0 scales the measured W1 by exactly c" do
    base = shifted_population(0.05)

    w1_base = DatasetAdmission.sliced_w1(base, 42, 16)
    assert is_float(w1_base) and w1_base > 0.0

    for c <- [0.5, 2.0, 10.0] do
      scaled =
        Enum.map(base, fn %{features: f} = s ->
          %{s | features: Map.new(f, fn {k, v} -> {k, v * c} end)}
        end)

      w1_scaled = DatasetAdmission.sliced_w1(scaled, 42, 16)

      assert_in_delta w1_scaled, c * w1_base, 1.0e-9,
        "W1 did not scale by c=#{c}: base=#{w1_base} scaled=#{w1_scaled}"
    end
  end

  # -- helpers ----------------------------------------------------------------

  defp measured(pop, seed, k) do
    case DatasetAdmission.admit(pop,
           seed: seed,
           epsilon_bias: 1.0e9,
           eta: 0.1,
           projections: k
         ) do
      {:ok, :ADMITTED, %{w1_proxy: w1}} -> w1
      other -> flunk("expected ADMITTED with permissive epsilon, got: #{inspect(other)}")
    end
  end
end
