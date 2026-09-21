defmodule Xaas.Coupling.EngineTest do
  use ExUnit.Case, async: true

  alias Xaas.Coupling.Engine

  describe "unconstrained (l/u = +-infinity) weighted mean" do
    test "couples two 1-D proposals to their exact weighted mean" do
      proposals = [
        %{id: "a", vector: [10.0], confidence: 1.0, staleness: 0.0},
        %{id: "b", vector: [20.0], confidence: 1.0, staleness: 0.0}
      ]

      assert {:ok, %{z: [z], weights: weights, receipt: receipt}} =
               Engine.couple(proposals, %{})

      # equal weight, equal confidence/staleness -> exact midpoint
      assert_in_delta z, 15.0, 1.0e-9
      assert weights["a"] == weights["b"]
      assert {:weighted_mean, contributions} = receipt[0]
      assert length(contributions) == 2
    end

    test "staleness decay reduces a stale proposal's real influence on z" do
      fresh = %{id: "fresh", vector: [0.0], confidence: 1.0, staleness: 0.0}
      stale = %{id: "stale", vector: [100.0], confidence: 1.0, staleness: 10.0}

      assert {:ok, %{z: [z]}} = Engine.couple([fresh, stale], %{})

      # exp(-10) is tiny, so z should sit very close to the fresh proposal,
      # not near the midpoint of [0, 100] -- a real, checkable consequence
      # of the staleness-weighting formula, not just "some number came back".
      assert z < 1.0
    end
  end

  describe "box-constrained (l <= z <= u)" do
    test "clamps the weighted mean to an upper bound and receipt records the clamp" do
      proposals = [
        %{id: "a", vector: [100.0], confidence: 1.0, staleness: 0.0}
      ]

      assert {:ok, %{z: [10.0], receipt: receipt}} =
               Engine.couple(proposals, %{lower: [0.0], upper: [10.0]})

      assert {:bound_clamped, %{bound: :upper, value: 10.0, unconstrained_mean: 100.0}} =
               receipt[0]
    end

    test "returns the exact unconstrained mean when it already lies inside the bounds" do
      proposals = [
        %{id: "a", vector: [5.0], confidence: 1.0, staleness: 0.0}
      ]

      assert {:ok, %{z: [5.0]}} = Engine.couple(proposals, %{lower: [0.0], upper: [10.0]})
    end

    test "infeasible when a bound pair conflicts, and names the exact conflicting coordinate" do
      proposals = [%{id: "a", vector: [5.0, 5.0], confidence: 1.0, staleness: 0.0}]

      assert {:infeasible, %{minimal_unsatisfiable_constraints: [conflict]}} =
               Engine.couple(proposals, %{lower: [10.0, 0.0], upper: [1.0, 10.0]})

      assert conflict.coordinate == 0
      assert conflict.lower == 10.0
      assert conflict.upper == 1.0
    end
  end

  describe "deterministic tie-breaking" do
    test "identical proposals/weights in different input orders produce bit-identical z" do
      proposals = [
        %{id: "p3", vector: [3.0, -1.0], confidence: 0.9, staleness: 2.0},
        %{id: "p1", vector: [1.0, 4.0], confidence: 0.4, staleness: 0.0},
        %{id: "p2", vector: [7.0, 0.0], confidence: 0.7, staleness: 1.0}
      ]

      {:ok, %{z: z1}} = Engine.couple(proposals, %{})
      {:ok, %{z: z2}} = Engine.couple(Enum.reverse(proposals), %{})
      {:ok, %{z: z3}} = Engine.couple(Enum.shuffle(proposals), %{})

      assert z1 == z2
      assert z1 == z3
    end
  end

  describe "general affine constraints (A z <= b, E z = f) -- honest UNSUPPORTED" do
    test "refuses rather than fabricating a QP solve when A is present" do
      proposals = [%{id: "a", vector: [1.0], confidence: 1.0, staleness: 0.0}]

      assert {:unsupported, %{reason: :general_affine_constraints_unsupported}} =
               Engine.couple(proposals, %{a_ineq: [[1.0]], b_ineq: [5.0]})
    end

    test "refuses rather than fabricating a QP solve when E is present" do
      proposals = [%{id: "a", vector: [1.0], confidence: 1.0, staleness: 0.0}]

      assert {:unsupported, %{reason: :general_affine_constraints_unsupported}} =
               Engine.couple(proposals, %{e_eq: [[1.0]], f_eq: [1.0]})
    end
  end

  describe "zero total weight (all proposals carry no real influence)" do
    test "all-zero-confidence proposals are infeasible, not a division-by-zero crash" do
      proposals = [
        %{id: "a", vector: [1.0], confidence: 0.0, staleness: 0.0},
        %{id: "b", vector: [2.0], confidence: 0.0, staleness: 0.0}
      ]

      assert {:infeasible, %{reason: :zero_total_weight}} = Engine.couple(proposals, %{})
    end

    test "staleness large enough to underflow exp(-staleness) to 0.0 is infeasible" do
      proposals = [
        %{id: "a", vector: [1.0], confidence: 1.0, staleness: 1.0e4}
      ]

      assert {:infeasible, %{reason: :zero_total_weight}} = Engine.couple(proposals, %{})
    end

    test "a mix of zero-confidence and underflowed-staleness proposals is still infeasible" do
      proposals = [
        %{id: "a", vector: [1.0, 2.0], confidence: 0.0, staleness: 0.0},
        %{id: "b", vector: [3.0, 4.0], confidence: 1.0, staleness: 1.0e4}
      ]

      assert {:infeasible, %{reason: :zero_total_weight}} = Engine.couple(proposals, %{})
    end
  end

  describe "malformed input" do
    test "empty proposal set is a typed error, not a crash" do
      assert {:error, %{reason: :empty_proposal_set}} = Engine.couple([], %{})
    end

    test "mismatched vector dimensions is a typed error" do
      proposals = [
        %{id: "a", vector: [1.0, 2.0], confidence: 1.0, staleness: 0.0},
        %{id: "b", vector: [1.0], confidence: 1.0, staleness: 0.0}
      ]

      assert {:error, %{reason: :mismatched_vector_dimensions}} = Engine.couple(proposals, %{})
    end
  end
end
