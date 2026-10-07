defmodule Xaas.Semantics.DatasetAdmissionTest do
  use ExUnit.Case, async: true

  alias Xaas.Semantics.DatasetAdmission

  defp sample(f, label, a), do: %{features: %{x: f}, label: label, sensitive: a}

  # Balanced: identical feature distribution conditioned on A=0 and A=1.
  defp balanced, do: balanced(100)

  defp balanced(n) when is_integer(n) do
    Enum.map(1..n, fn i ->
      x = :math.sin(div(i, 2) * 1.3) + 0.001 * :rand.uniform()
      label = if i > div(n, 2), do: 1, else: 0
      sample(x, label, rem(i, 2))
    end)
  end

  # Skewed: every positive label lives in the A=1 group — the feature
  # distribution is conditioned hard on the sensitive attribute.
  defp skewed do
    Enum.concat([
      for(i <- 1..50, do: sample(0.0 + 0.001 * i, 0, 0)),
      for(i <- 1..50, do: sample(5.0 + 0.001 * i, 1, 1))
    ])
  end

  test "balanced synthetic data is ADMITTED" do
    assert {:ok, :ADMITTED, meas} = DatasetAdmission.admit(balanced(), seed: 42, epsilon_bias: 0.5)
    assert meas.w1_proxy <= 0.5
    assert meas.completeness == 1.0
    assert meas.projections == 32
  end

  test "skewed sensitive-conditioning is REFUSED_BIAS_THRESHOLD" do
    assert {:error, {:REFUSED_BIAS_THRESHOLD, %{w1_proxy: w1, epsilon_bias: eps}}} =
             DatasetAdmission.admit(skewed(), seed: 7, epsilon_bias: 0.1)

    assert w1 > eps
    assert w1 > 1.0
  end

  test "missing required fields is REFUSED_INCOMPLETE_DATASET" do
    data = [
      sample(1.0, 0, 0),
      %{features: %{}, label: 1, sensitive: 1}
    ]

    assert {:error, {:REFUSED_INCOMPLETE_DATASET, %{completeness: comp, threshold: thr}}} =
             DatasetAdmission.admit(data,
               seed: 7,
               required_fields: [:x],
               eta: 0.05
             )

    assert comp == 0.5
    assert thr == 0.95
  end

  test "determinism: same input and seed twice gives identical verdict and measurement" do
    data = balanced(80)

    v1 = DatasetAdmission.admit(data, seed: 1234, epsilon_bias: 0.5)
    v2 = DatasetAdmission.admit(data, seed: 1234, epsilon_bias: 0.5)
    assert v1 == v2

    # a different seed is a different (still valid) projection set
    {:ok, :ADMITTED, m3} = DatasetAdmission.admit(data, seed: 99, epsilon_bias: 0.5)
    assert is_float(m3.w1_proxy)
  end

  test "zero samples is typed REFUSED_EMPTY_DATASET" do
    assert {:error, :REFUSED_EMPTY_DATASET} = DatasetAdmission.admit([], seed: 1)
  end

  test "unobservable sensitive population refuses bias gate (fail-closed)" do
    data = for i <- 1..20, do: sample(0.5 * i, 0, 1)
    assert {:error, {:REFUSED_BIAS_THRESHOLD, _}} =
             DatasetAdmission.admit(data, seed: 1, epsilon_bias: 0.1)
  end

  # W676 regression: an extreme-magnitude float feature must surface as the
  # typed {:error, :REFUSED_ARITHMETIC_OVERFLOW} refusal (via the gate-boundary
  # ArithmeticError rescue), never as an untyped raise out of admit/2. The
  # samples below deliberately avoid `value * 2.0` in the test helper — an
  # overflow in test-side sample construction is a test defect, not a gate
  # defect (that exact raise at art15_deepening_test.exs:172 is what W659e
  # reproduced). Mutation check: deleting the `ArithmeticError ->
  # {:error, :REFUSED_ARITHMETIC_OVERFLOW}` rescue arm in
  # lib/xaas/semantics/dataset_admission.ex makes the first assertion below
  # raise ArithmeticError (float overflow in the W1 quantile aggregation).
  test "extreme-magnitude float feature refuses typed ARITHMETIC_OVERFLOW (W676)" do
    huge = 1.0e308

    data =
      Enum.flat_map(0..9, fn i ->
        [
          %{features: %{x: i * 1.0, y: 1.0}, label: :w676, sensitive: 0},
          %{features: %{x: huge, y: 1.0}, label: :w676, sensitive: 1}
        ]
      end)

    assert {:error, :REFUSED_ARITHMETIC_OVERFLOW} =
             DatasetAdmission.admit(data, seed: 667, epsilon_bias: 0.1)
  end

  # W865 (OPEN_GAP-3 closure): the HELPER-side site W676 declined —
  # sliced_w1/3 is public and sits outside admit/2's gate-boundary rescue, so
  # a direct call with mixed +-1.0e308 features raised a raw ArithmeticError
  # in the quantile interpolation (`a + (b - a) * frac`, 1e308 - (-1e308)
  # overflows). Same house rescue pattern: the typed atom through the
  # existing closed set, never an untyped raise.
  #
  # Mutation rationale: deleting the `ArithmeticError ->
  # {:error, :REFUSED_ARITHMETIC_OVERFLOW}` rescue arm in sliced_w1/3 makes
  # the first assert below raise ArithmeticError (this direct call is the
  # only path that exercises the helper boundary; admit/2-level tests are
  # additionally shielded by admit's own rescue arm and do not kill that
  # mutation alone).
  test "direct sliced_w1/3 helper call refuses typed ARITHMETIC_OVERFLOW on extreme features (W865)" do
    huge = 1.0e308
    s0 = %{features: %{x: huge, y: 1.0}, label: :w865, sensitive: 0}
    s1 = %{features: %{x: -huge, y: 1.0}, label: :w865, sensitive: 1}

    assert {:error, :REFUSED_ARITHMETIC_OVERFLOW} =
             DatasetAdmission.sliced_w1([s0, s1], 667, 8)
  end

  test "normal inputs are unaffected by the W865 helper rescue ( sliced_w1 still numeric)" do
    s0 = %{features: %{x: 1.0, y: 2.0}, label: :w865, sensitive: 0}
    s1 = %{features: %{x: 1.0, y: 2.0}, label: :w865, sensitive: 1}

    w1 = DatasetAdmission.sliced_w1([s0, s1], 667, 8)
    assert is_float(w1) and w1 == 0.0

    # Gate path still admits identical balanced populations end to end.
    # x depends on div(i+1,2) so the A=0 and A=1 populations are identical
    # (parity on i alone would correlate x with the sensitive attribute).
    data =
      for i <- 1..20,
          do: %{features: %{x: div(i + 1, 2) * 1.0, y: 1.0}, label: :w865, sensitive: rem(i, 2)}

    assert {:ok, :ADMITTED, meas} = DatasetAdmission.admit(data, seed: 667, epsilon_bias: 0.5)
    assert meas.w1_proxy <= 0.5
  end
end
