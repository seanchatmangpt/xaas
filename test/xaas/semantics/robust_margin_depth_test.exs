defmodule Xaas.Semantics.RobustMarginDepthTest do
  @moduledoc """
  W984aa — depth court, batch 2 (W980i pattern): boundary invariants of
  `Xaas.Semantics.RobustMargin` (EU AI Act Art.15 Theorem 5.3 gate) that the
  pre-existing `robust_margin_test.exs` (8 courts) leaves uncourted — typed-refusal
  and boundary-arithmetic edges where an untyped crash would turn a certificate
  decision into an untyped 500:

  - the W630 arithmetic-rescue clauses: float overflow in the slope arithmetic
    or the penalty product must surface as `{:error, :REFUSED_ARITHMETIC_OVERFLOW}`,
    never a raw `ArithmeticError` raise;
  - coincident pairs (zero input distance) witness no slope — 0.0 by the
    documented guard, and a zero Lipschitz estimate must not rescue an inverted
    margin;
  - negative constants refuse typed (MALFORMED_MARGIN_INPUT) rather than
    producing a negative penalty that could flip a refusal into an admission;
  - the verdict is monotone in epsilon: raising the adversarial radius can flip
    ADMITTED -> refusal, never the reverse.

  Mutation rationale: delete either `rescue ArithmeticError` clause and courts
  (1)-(2) crash with a raw ArithmeticError instead of returning the typed term.
  Delete the `denominator == 0` guard in `estimate_lipschitz/2` and court (3)
  raises badarith instead of returning 0.0. Flip the admission comparison
  `>= 0` to `> 0` and court (4)'s exact-zero-margin point flips to refusal
  while the rest of the sweep in court (5) stays green. Drop the guard-domain
  catch-all clause and court (5b) raises FunctionClauseError instead of
  returning the typed MALFORMED refusal.
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.RobustMargin

  @max :math.pow(2, 1023)

  test "(1) slope arithmetic overflow refuses typed, not badarith (W630)" do
    assert {:error, :REFUSED_ARITHMETIC_OVERFLOW} =
             RobustMargin.estimate_lipschitz(fn x -> x end, [{@max, -@max}])
  end

  test "(2) penalty-product overflow propagates the typed refusal through admit/4" do
    assert {:error, :REFUSED_ARITHMETIC_OVERFLOW} =
             RobustMargin.admit(0.0, @max, @max, 2.0)
  end

  test "(3) coincident pairs witness no slope (0.0) and a zero L cannot rescue an inverted margin" do
    assert RobustMargin.estimate_lipschitz(fn x -> x * 100.0 end, [{5.0, 5.0}]) == 0.0

    # Zero penalty (L_h = 0) with a negative margin still refuses: the gate is
    # on the margin itself, not on the penalty.
    assert RobustMargin.admit(-1.0, 0.0, 0.0, 0.0) == {:error, :REFUSED_ROBUST_MARGIN}
  end

  test "(5) exact-zero-margin boundary admits (>= 0, not > 0)" do
    # penalty = 2.0 * 1.0 * 2.0 = 4.0, margin 4.0 - 4.0 = exactly 0.0
    assert RobustMargin.admit(4.0, 2.0, 1.0, 2.0) == :ADMITTED
  end

  test "(6) verdict is monotone in epsilon: ADMITTED can flip to refusal, never the reverse" do
    epsilons = [0.0, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 100.0]

    verdicts =
      Enum.map(epsilons, fn eps ->
        {eps, RobustMargin.admit(6.0, 2.0, 1.0, eps)}
      end)

    {admitted, refused} = Enum.split_with(verdicts, fn {_e, v} -> v == :ADMITTED end)
    assert admitted != []
    assert refused != []

    # every admitted epsilon is <= every refused epsilon (prefix property)
    max_admitted = admitted |> Enum.map(fn {e, _} -> e end) |> Enum.max()
    min_refused = refused |> Enum.map(fn {e, _} -> e end) |> Enum.min()
    assert max_admitted <= min_refused
  end

  test "(5b) negative l_h / negative epsilon refuse typed MALFORMED_MARGIN_INPUT" do
    assert RobustMargin.admit(10.0, -1.0, 1.0, 1.0) == {:error, :REFUSED_MALFORMED_MARGIN_INPUT}
    assert RobustMargin.admit(10.0, 1.0, 1.0, -0.5) == {:error, :REFUSED_MALFORMED_MARGIN_INPUT}
  end
end
