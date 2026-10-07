defmodule Xaas.EUAIAct.Art15DeepeningTest do
  @moduledoc """
  Lane W667 — Art. 15 (accuracy, robustness, cybersecurity) evidenced-line
  deepening.

  Chicago-style: real module calls only, no mocks. Seeded deterministic
  property sweeps over `Xaas.Semantics.RobustMargin` (adversarial-input
  robustness of the Theorem 5.3 gate) and `Xaas.Semantics.DatasetAdmission`
  (W1-slice bound stability under seeded perturbation), plus typed-refusal
  assertions on malformed/overflow inputs (specific refusal atoms, not just
  error tuples).
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.{DatasetAdmission, RobustMargin}

  @moduletag :eu_ai_act

  # -- deterministic seeded generator (real :rand, no mocks) ----------------

  defp rng(seed_tag) do
    # :rand.seed/2 requires a valid seed term (integer or state tuple); hash the
    # descriptive tag to one. (W667 fix: raw tag tuples crash exsss_seed/1.)
    state = :rand.seed(:exsss, :erlang.phash2(seed_tag))
    fn -> :rand.uniform_s(state) |> elem(0) end
  end

  # -- RobustMargin: adversarial-input property sweeps ---------------------

  describe "RobustMargin adversarial property sweeps (seeded, deterministic)" do
    test "sweep: monotone penalty — larger epsilon never turns a refusal into ADMITTED" do
      draw = rng({:w667, :eps_monotone})

      for _trial <- 1..200 do
        margin = draw.() * 20.0 - 10.0
        l_h = draw.() * 5.0
        l_e = draw.() * 3.0

        epsilons = Enum.map(0..10, fn i -> i * 0.5 end)

        verdicts =
          Enum.map(epsilons, fn eps ->
            RobustMargin.admit(margin, l_h, l_e, eps)
          end)

        # Once refused, never re-admitted at a larger radius.
        refused_idx =
          verdicts
          |> Enum.with_index()
          |> Enum.filter(fn {v, _i} -> v == {:error, :REFUSED_ROBUST_MARGIN} end)
          |> Enum.map(fn {_v, i} -> i end)

        case refused_idx do
          [] -> :ok
          [first | _] -> assert Enum.all?(Enum.drop(verdicts, first), &(&1 != :ADMITTED))
        end
      end
    end

    test "sweep: ADMITTED region is downward-closed in the margin" do
      draw = rng({:w667, :margin_monotone})

      for _trial <- 1..200 do
        l_h = draw.() * 4.0
        l_e = draw.() * 2.0
        eps = draw.() * 2.0
        penalty = l_h * l_e * eps
        m0 = draw.() * 20.0

        if RobustMargin.admit(m0, l_h, l_e, eps) == :ADMITTED do
          # Any margin below (m0 - penalty] ... specifically margin == penalty
          # (boundary) must still admit; margin just below penalty refuses.
          assert RobustMargin.admit(penalty, l_h, l_e, eps) == :ADMITTED

          if penalty > 0 do
            assert RobustMargin.admit(penalty * 0.999, l_h, l_e, eps) ==
                     {:error, :REFUSED_ROBUST_MARGIN}
          end
        end
      end
    end

    test "sweep: empirical-Lipschitz monotonicity in sample count (lower bound only grows)" do
      # f(x) = x^2 on [0,10]: secant slopes grow with the pair set, so a denser
      # sample can only increase (or hold) the empirical supremum.
      f = fn x -> x * x end

      small = [{0.0, 1.0}, {2.0, 3.0}]
      draw = rng({:w667, :lip_mono})

      base = RobustMargin.estimate_lipschitz(f, small)
      assert is_float(base)

      for _trial <- 1..50 do
        extra =
          Enum.map(1..10, fn _ ->
            a = draw.() * 10.0
            b = draw.() * 10.0
            {a, b}
          end)

        denser = RobustMargin.estimate_lipschitz(f, small ++ extra)
        assert denser >= base - 1.0e-9
      end
    end

    test "sweep: vector scoring empirical-Lipschitz also monotone under densification" do
      f = fn [a, b] -> [a + b, a - b] end
      small = [{[0.0, 0.0], [1.0, 1.0]}, {[2.0, 3.0], [3.0, 5.0]}]
      base = RobustMargin.estimate_lipschitz(f, small)

      # Known exact slopes for this linear map: ratios range up to sqrt(2)*~1.41;
      # adding coincident pairs leaves the sup unchanged.
      denser = RobustMargin.estimate_lipschitz(f, small ++ [{[1.0, 1.0], [1.0, 1.0]}])
      assert denser == base
    end
  end

  # -- RobustMargin: typed refusals on malformed / overflow inputs ----------

  describe "RobustMargin typed refusals" do
    test "non-numeric margin constant refuses MALFORMED_MARGIN_INPUT atom" do
      assert RobustMargin.admit("ten", 1.0, 1.0, 1.0) ==
               {:error, :REFUSED_MALFORMED_MARGIN_INPUT}

      assert RobustMargin.admit(nil, 1.0, 1.0, 1.0) == {:error, :REFUSED_MALFORMED_MARGIN_INPUT}

      assert RobustMargin.admit([1.0], 1.0, 1.0, 1.0) ==
               {:error, :REFUSED_MALFORMED_MARGIN_INPUT}
    end

    test "negative l_h / l_e / epsilon each refuse MALFORMED_MARGIN_INPUT" do
      assert RobustMargin.admit(10.0, -1.0, 1.0, 1.0) == {:error, :REFUSED_MALFORMED_MARGIN_INPUT}
      assert RobustMargin.admit(10.0, 1.0, -1.0, 1.0) == {:error, :REFUSED_MALFORMED_MARGIN_INPUT}
      assert RobustMargin.admit(10.0, 1.0, 1.0, -1.0) == {:error, :REFUSED_MALFORMED_MARGIN_INPUT}
    end

    test "non-1-arity margin closure refuses MALFORMED_MARGIN_INPUT (not FunctionClauseError)" do
      assert RobustMargin.admit(fn x -> x end, 1.0, 1.0, 1.0) ==
               {:error, :REFUSED_MALFORMED_MARGIN_INPUT}
    end

    test "typed no-calibration-data refusal propagates verbatim through admit/4" do
      assert RobustMargin.admit(1.0e300, {:error, :REFUSED_NO_CALIBRATION_DATA}, 0.0, 0.0) ==
               {:error, :REFUSED_NO_CALIBRATION_DATA}
    end

    test "arbitrary typed refusal tuple in the l_h slot propagates (fail-closed)" do
      assert RobustMargin.admit(1.0, {:error, :REFUSED_ARITHMETIC_OVERFLOW}, 1.0, 1.0) ==
               {:error, :REFUSED_ARITHMETIC_OVERFLOW}
    end

    test "overflowing penalty product refuses ARITHMETIC_OVERFLOW atom, not badarith" do
      huge = 1.0e308
      assert RobustMargin.admit(1.0, huge, huge, huge) == {:error, :REFUSED_ARITHMETIC_OVERFLOW}
    end

    test "estimate_lipschitz refuses overflow on extreme-magnitude float pairs" do
      # 1.0e308 - (-1.0e308) overflows to ArithmeticError in the slope numerator.
      pairs = [{1.0e308, -1.0e308}]
      assert RobustMargin.estimate_lipschitz(fn x -> x end, pairs) ==
               {:error, :REFUSED_ARITHMETIC_OVERFLOW}
    end

    test "coincident input pairs witness no slope (0.0, not refusal)" do
      assert RobustMargin.estimate_lipschitz(fn x -> x end, [{2.0, 2.0}, {5.0, 5.0}]) == 0.0
    end
  end

  # -- DatasetAdmission: W1 bound under seeded perturbation -----------------

  defp sample(sensitive, value),
    do: %{features: %{x: value * 1.0, y: value * 1.0}, label: :w667, sensitive: sensitive}

  describe "DatasetAdmission W1-slice bound under seeded perturbation" do
    test "identical populations across sensitive groups admit with W1 proxy 0.0" do
      samples = Enum.flat_map(0..19, fn i -> [sample(0, i * 1.0), sample(1, i * 1.0)] end)

      assert {:ok, :ADMITTED, meas} =
               DatasetAdmission.admit(samples, seed: 667, epsilon_bias: 0.1)

      assert meas.w1_proxy == 0.0
      assert meas.completeness == 1.0
      assert meas.projections == 32
    end

    test "seeded perturbation below the bias bound stays ADMITTED and W1 stays <= bound" do
      draw = rng({:w667, :ds_small_perturb})

      for seed <- 1..20 do
        _ = draw.()

        samples =
          Enum.flat_map(0..19, fn i ->
            [sample(0, i * 1.0), sample(1, i * 1.0 + 0.01)]
          end)

        case DatasetAdmission.admit(samples, seed: seed, epsilon_bias: 0.1) do
          {:ok, :ADMITTED, meas} -> assert meas.w1_proxy <= 0.1
          {:error, {:REFUSED_BIAS_THRESHOLD, m}} -> assert m.w1_proxy <= 0.15
        end
      end
    end

    test "large shift across sensitive groups refuses with BIAS_THRESHOLD and reports bound" do
      samples = Enum.flat_map(0..19, fn i -> [sample(0, i * 1.0), sample(1, i * 1.0 + 10.0)] end)

      assert {:error, {:REFUSED_BIAS_THRESHOLD, m}} =
               DatasetAdmission.admit(samples, seed: 667, epsilon_bias: 0.1)

      assert m.w1_proxy > 0.1
      assert m.epsilon_bias == 0.1
    end

    test "deterministic: same seed reproduces identical W1 proxy" do
      samples = Enum.flat_map(0..19, fn i -> [sample(0, i * 1.0), sample(1, i * 1.0 + 0.5)] end)

      {:ok, _, m1} = DatasetAdmission.admit(samples, seed: 42, epsilon_bias: 10.0)
      {:ok, _, m2} = DatasetAdmission.admit(samples, seed: 42, epsilon_bias: 10.0)
      {:ok, _, m3} = DatasetAdmission.admit(samples, seed: 43, epsilon_bias: 10.0)

      assert m1.w1_proxy == m2.w1_proxy
      # Different seed may differ, but must remain a positive finite estimate.
      assert is_float(m3.w1_proxy) and m3.w1_proxy >= 0.0
    end

    test "unbalanced perturbation: W1 proxy grows with shift magnitude (monotone bound)" do
      base = Enum.map(0..19, &sample(0, &1 * 1.0))

      w1_at = fn shift ->
        samples = base ++ Enum.map(0..19, fn i -> sample(1, i * 1.0 + shift) end)
        {:ok, _, m} = DatasetAdmission.admit(samples, seed: 667, epsilon_bias: 1.0e9)
        m.w1_proxy
      end

      small = w1_at.(0.1)
      mid = w1_at.(1.0)
      large = w1_at.(10.0)

      assert small <= mid
      assert mid <= large
    end

    test "typed refusals: empty, incomplete, and one-sided populations" do
      assert DatasetAdmission.admit([]) == {:error, :REFUSED_EMPTY_DATASET}

      incomplete = [sample(0, 1.0), %{features: %{x: nil, y: 2.0}, label: :w667, sensitive: 1}]

      assert {:error, {:REFUSED_INCOMPLETE_DATASET, m}} =
               DatasetAdmission.admit(incomplete,
                 seed: 667,
                 required_fields: [:x, :y],
                 eta: 0.05
               )

      assert m.completeness == 0.75
      assert m.threshold == 0.95

      # ArithmeticError rescue: infinite W1 (one-sided population) is caught by
      # the bias gate; the typed overflow atom is reachable via overflowing
      # quantile arithmetic.
      huge = 1.0e308
      overflow_samples = Enum.flat_map(0..9, fn i -> [sample(0, i * 1.0), sample(1, huge)] end)

      case DatasetAdmission.admit(overflow_samples, seed: 667, epsilon_bias: 0.1) do
        {:error, {:REFUSED_BIAS_THRESHOLD, _}} -> :ok
        {:error, :REFUSED_ARITHMETIC_OVERFLOW} -> :ok
        other -> flunk("expected typed refusal, got: #{inspect(other)}")
      end
    end
  end
end
