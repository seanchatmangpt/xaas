defmodule Xaas.Semantics.RobustMargin do
  @moduledoc """
  EU AI Act Art.15 adversarial-robustness gate — dissertation Ch5, Theorem 5.3.

      Margin(x) = h(E(x)) - L_h * L_E * epsilon >= 0

  where `h` is the decision margin function, `E` the (Lipschitz-bounded) encoder
  with empirical constant `L_E`, `L_h` the Lipschitz constant of the scoring
  function, and `epsilon` the certified adversarial perturbation radius.

  ## Conditional-certificate honesty note

  `estimate_lipschitz/2` computes the EMPIRICAL Lipschitz constant: the
  supremum of `||f(x1) - f(x2)|| / ||x1 - x2||` over the *provided* sample
  pairs only. This is a LOWER BOUND on the true Lipschitz constant `L` — a
  denser sample can only increase it. Consequently:

  > The admission certificate produced by `admit/4` is CONDITIONAL. It states
  > "Margin >= 0 given that the empirical estimate equals the true L on the
  > operating region". The dissertation's Theorem 5.3 holds given a TRUE
  > Lipschitz constant; v2 scope replaces the empirical estimate with a
  > certified constant via interval arithmetic.

  `epsilon` is a call argument (zero-config): no ambient application state
  gates the certificate.

  Norms: inputs may be plain numbers or lists of numbers (L2 norm of the
  difference is used for lists).
  """

  @typedoc "Empirical (lower-bound) Lipschitz constant."
  @type empirical_l :: float()

  @doc """
  Empirical Lipschitz constant of `scoring_fun` over `pairs`.

  `pairs` is a list of `{x1, x2}` tuples. Returns the supremum of
  `||f(x1) - f(x2)|| / ||x1 - x2||` over the pairs, or
  `{:error, :REFUSED_NO_CALIBRATION_DATA}` when `pairs` is empty
  (fail-closed: no certificate without calibration data).
  """
  @spec estimate_lipschitz((term() -> number()), [{term(), term()}]) ::
          empirical_l()
          | {:error, :REFUSED_NO_CALIBRATION_DATA}
          | {:error, :REFUSED_ARITHMETIC_OVERFLOW}
  def estimate_lipschitz(_scoring_fun, []), do: {:error, :REFUSED_NO_CALIBRATION_DATA}

  def estimate_lipschitz(scoring_fun, pairs) when is_function(scoring_fun, 1) do
    # Gate-boundary arithmetic rescue (W630): overflowing the slope arithmetic
    # (sub/norm on extreme-magnitude floats) is typed, not badarith.
    try do
      pairs
      |> Enum.map(fn {x1, x2} ->
        numerator = norm(sub(scoring_fun.(x1), scoring_fun.(x2)))
        denominator = norm(sub(x1, x2))

        if denominator == 0 do
          # Coincident inputs cannot witness any slope; they carry no bits.
          0.0
        else
          numerator / denominator
        end
      end)
      |> Enum.max()
    rescue
      ArithmeticError -> {:error, :REFUSED_ARITHMETIC_OVERFLOW}
    end
  end

  @doc """
  Theorem 5.3 admission gate.

  * `margin` — the evaluated decision margin `h(E(x))` (number) or a zero-arity
    closure producing it.
  * `l_h` — Lipschitz constant (or empirical lower bound) of the scoring
    function.
  * `l_e` — empirical Lipschitz constant of the encoder.
  * `epsilon` — certified adversarial perturbation radius, a call argument.

  Returns `:ADMITTED` when `h(E(x)) - L_h * L_E * epsilon >= 0`, otherwise
  `{:error, :REFUSED_ROBUST_MARGIN}`.

  Fail-closed: when `l_h` is the typed refusal `{:error,
  :REFUSED_NO_CALIBRATION_DATA}` (as returned by `estimate_lipschitz/2` on an
  empty pair set), the gate refuses with that same term — a certificate
  without calibration data is not a certificate.
  """
  @spec admit(number() | (-> number()), number() | {:error, term()}, number(), number()) ::
          :ADMITTED
          | {:error, :REFUSED_ROBUST_MARGIN}
          | {:error, :REFUSED_NO_CALIBRATION_DATA}
          | {:error, :REFUSED_ARITHMETIC_OVERFLOW}
          | {:error, :REFUSED_MALFORMED_MARGIN_INPUT}
  def admit(margin, l_h, l_e, epsilon)

  def admit(_margin, {:error, refusal}, _l_e, _epsilon) when is_atom(refusal) do
    {:error, refusal}
  end

  def admit(margin, l_h, l_e, epsilon)
      when is_number(l_h) and is_number(l_e) and is_number(epsilon) and
             l_h >= 0 and l_e >= 0 and epsilon >= 0 do
    # Gate-boundary arithmetic rescue (W630): float overflow in the penalty
    # product or the margin subtraction is a typed refusal, not a badarith raise.
    try do
      margin_value =
        case margin do
          fun when is_function(fun, 0) -> fun.()
          value when is_number(value) -> value
        end

      penalty = l_h * l_e * epsilon

      if margin_value - penalty >= 0 do
        :ADMITTED
      else
        {:error, :REFUSED_ROBUST_MARGIN}
      end
    rescue
      ArithmeticError -> {:error, :REFUSED_ARITHMETIC_OVERFLOW}
    end
  end

  # Catch-all (W630): guard-domain mismatches — non-numeric or negative
  # l_h/l_e/epsilon — refuse typed instead of raising FunctionClauseError.
  def admit(_margin, _l_h, _l_e, _epsilon), do: {:error, :REFUSED_MALFORMED_MARGIN_INPUT}

  # -- norms ---------------------------------------------------------------

  defp sub(x1, x2) when is_number(x1) and is_number(x2), do: x1 - x2

  defp sub(x1, x2) when is_list(x1) and is_list(x2) do
    Enum.zip(x1, x2) |> Enum.map(fn {a, b} -> a - b end)
  end

  defp norm(x) when is_number(x), do: abs(x * 1.0)
  defp norm(xs) when is_list(xs), do: xs |> Enum.map(&(&1 * &1)) |> Enum.sum() |> :math.sqrt()
end
