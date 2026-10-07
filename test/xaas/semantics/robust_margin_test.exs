defmodule Xaas.Semantics.RobustMarginTest do
  use ExUnit.Case, async: true

  alias Xaas.Semantics.RobustMargin

  describe "estimate_lipschitz/2" do
    test "recovers the exact slope for 2x scoring on scalar pairs" do
      pairs = [{0.0, 1.0}, {2.0, 5.0}, {-3.0, 0.0}]
      # f(x) = 2x: every pair witnesses ratio exactly 2.0.
      assert RobustMargin.estimate_lipschitz(fn x -> 2 * x end, pairs) == 2.0
    end

    test "recovers exact vector slopes (L2 norm) for 2x scoring" do
      # f([3,4]) = [6,8], L2 diff 10.0 over input distance 5.0 -> 2.0
      pairs = [{[0.0, 0.0], [3.0, 4.0]}, {[1.0, 1.0], [1.0, 1.0]}]
      assert RobustMargin.estimate_lipschitz(fn x -> Enum.map(x, &(&1 * 2)) end, pairs) == 2.0
    end

    test "identity scoring has empirical Lipschitz constant exactly 1.0" do
      pairs = [{0.0, 1.0}, {2.0, 5.0}, {-3.0, 0.0}]
      assert RobustMargin.estimate_lipschitz(fn x -> x end, pairs) == 1.0
    end

    test "empty pairs refuse with typed no-calibration-data" do
      assert RobustMargin.estimate_lipschitz(fn x -> x end, []) ==
               {:error, :REFUSED_NO_CALIBRATION_DATA}
    end
  end

  describe "admit/4" do
    test "positive margin after penalty admits" do
      # h = 10.0, penalty = 2.0 * 1.5 * 2.0 = 6.0 -> margin 4.0 >= 0
      assert RobustMargin.admit(10.0, 2.0, 1.5, 2.0) == :ADMITTED
    end

    test "adversarial epsilon large enough to invert the margin refuses" do
      # h = 1.0, penalty = 2.0 * 1.0 * 1.0 = 2.0 -> margin -1.0 < 0
      assert RobustMargin.admit(1.0, 2.0, 1.0, 1.0) == {:error, :REFUSED_ROBUST_MARGIN}
    end

    test "boundary margin exactly zero admits (>= 0)" do
      # h = 4.0, penalty = 2.0 * 1.0 * 2.0 = 4.0 -> margin 0.0
      assert RobustMargin.admit(4.0, 2.0, 1.0, 2.0) == :ADMITTED
    end

    test "accepts a zero-arity margin closure" do
      assert RobustMargin.admit(fn -> 5.0 end, 1.0, 2.0, 2.0) == :ADMITTED
    end

    test "propagates typed no-calibration-data refusal (fail-closed)" do
      assert RobustMargin.admit(100.0, {:error, :REFUSED_NO_CALIBRATION_DATA}, 1.0, 0.0) ==
               {:error, :REFUSED_NO_CALIBRATION_DATA}
    end

    # W676 regression: before the guard fix, a non-numeric margin ("ten") or a
    # non-0-arity closure reached the inner `case margin do` in the numeric
    # clause and raised CaseClauseError — the outer catch-all clause was never
    # reached because the numeric guards all passed. Mutation check: reverting
    # the guard (dropping `(is_number(margin) or is_function(margin, 0)) and`
    # from the first clause head) makes both assertions below raise
    # CaseClauseError instead of returning the typed refusal.
    test "non-numeric margin constant refuses typed MALFORMED_MARGIN_INPUT (W676)" do
      assert RobustMargin.admit("ten", 1.0, 1.0, 1.0) ==
               {:error, :REFUSED_MALFORMED_MARGIN_INPUT}
    end

    test "non-0-arity margin closure refuses typed MALFORMED_MARGIN_INPUT (W676)" do
      assert RobustMargin.admit(fn x -> x end, 1.0, 1.0, 1.0) ==
               {:error, :REFUSED_MALFORMED_MARGIN_INPUT}
    end
  end

  describe "end-to-end Theorem 5.3 gate" do
    test "empirical L_E + L_h feed the margin gate and adversarial epsilon flips the verdict" do
      # Encoder E = identity on scalars; true L_E = 1.0, empirically exact.
      encoder = fn x -> x end
      l_e = RobustMargin.estimate_lipschitz(encoder, [{0.0, 1.0}, {5.0, 7.0}])
      assert l_e == 1.0

      # Scoring h(x) = 2x; true L_h = 2.0. Margin at x=5 is 10.0.
      l_h = RobustMargin.estimate_lipschitz(fn x -> 2 * x end, [{0.0, 1.0}, {3.0, 5.0}])
      assert l_h == 2.0

      # epsilon = 2.5: penalty 2*1*2.5 = 5.0, margin 10 - 5 = 5 >= 0.
      assert RobustMargin.admit(10.0, l_h, l_e, 2.5) == :ADMITTED

      # epsilon = 6.0: penalty 12.0, margin -2.0 < 0 -> typed refusal.
      assert RobustMargin.admit(10.0, l_h, l_e, 6.0) == {:error, :REFUSED_ROBUST_MARGIN}
    end
  end
end
