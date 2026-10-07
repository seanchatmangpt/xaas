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
end
