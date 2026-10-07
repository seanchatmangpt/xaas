defmodule Xaas.CouplingDeepeningTest do
  @moduledoc """
  W735 coupling deepening: hand-computed exact WLS solutions, real boundary
  clamping on both bounds, the full typed-refusal contract, and determinism
  x3 -- through both the pure engine and the real Ash admission action.
  Chicago-style: real modules, real Postgres via the SQL sandbox, no mocks.
  """

  use ExUnit.Case, async: true

  alias Xaas.Coupling.CouplingRun
  alias Xaas.Coupling.Engine

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  describe "(a) analytically-solvable weighted least squares" do
    test "1-D exact solution with unequal weights" do
      # w_a = 0.5 * exp(0) = 0.5; w_b = 0.25 * exp(-ln 2) = 0.125.
      # z = (0.5*4 + 0.125*6) / 0.625 = 2.75 / 0.625 = 4.4 exactly.
      ln2 = :math.log(2)
      proposals = [
        %{id: "a", vector: [4.0], confidence: 0.5, staleness: 0.0},
        %{id: "b", vector: [6.0], confidence: 0.25, staleness: ln2}
      ]

      assert {:ok, %{z: [z], weights: weights, receipt: receipt}} =
               Engine.couple(proposals, %{})

      assert_in_delta z, 4.4, 1.0e-12
      assert_in_delta weights["a"], 0.5, 1.0e-12
      assert_in_delta weights["b"], 0.125, 1.0e-12

      assert {:weighted_mean, contributions} = receipt[0]
      by_id = Map.new(contributions, &{&1.proposal_id, &1.fraction})
      # fractions are w_i / total: 0.5/0.625 and 0.125/0.625
      assert_in_delta by_id["a"], 0.8, 1.0e-12
      assert_in_delta by_id["b"], 0.2, 1.0e-12
    end

    test "2-D exact solution: each coordinate is an independent 1-D WLS" do
      # w_p = 1.0, w_q = 0.6 (both fresh). total = 1.6.
      # coord0: (0*1 + 10*0.6)/1.6 = 3.75; coord1: (10*1 + 20*0.6)/1.6 = 13.75.
      proposals = [
        %{id: "p", vector: [0.0, 10.0], confidence: 1.0, staleness: 0.0},
        %{id: "q", vector: [10.0, 20.0], confidence: 0.6, staleness: 0.0}
      ]

      assert {:ok, %{z: z}} = Engine.couple(proposals, %{})
      assert_in_delta Enum.at(z, 0), 3.75, 1.0e-12
      assert_in_delta Enum.at(z, 1), 13.75, 1.0e-12
    end

    test "the same exact solution through the real Ash :couple action" do
      # Same arithmetic as the 1-D case above, via string-keyed JSON-shaped
      # input, asserting on persisted state.
      ln2 = :math.log(2)

      {:ok, run} =
        CouplingRun
        |> Ash.Changeset.for_create(:couple, %{
          proposals: [
            %{"id" => "a", "vector" => [4.0], "confidence" => 0.5, "staleness" => 0.0},
            %{"id" => "b", "vector" => [6.0], "confidence" => 0.25, "staleness" => ln2}
          ],
          constraints: %{}
        })
        |> Ash.create()

      assert run.status == :solved
      assert [z] = run.z
      assert_in_delta z, 4.4, 1.0e-12
      assert_in_delta run.weights["a"], 0.5, 1.0e-12
    end
  end

  describe "(b) box constraints actually bind" do
    test "clamps to the lower bound and the receipt names it" do
      proposals = [%{id: "a", vector: [-100.0], confidence: 1.0, staleness: 0.0}]

      assert {:ok, %{z: [-5.0], receipt: receipt}} =
               Engine.couple(proposals, %{lower: [-5.0], upper: [5.0]})

      assert {:bound_clamped, %{bound: :lower, value: -5.0, unconstrained_mean: -100.0}} =
               receipt[0]
    end

    test "mixed 2-D: one coordinate clamped low, one clamped high, one mean would be neither" do
      # unconstrained mean is [-100.0, 200.0]; box is [-5, 0] <= z <= [5, 100].
      proposals = [%{id: "a", vector: [-100.0, 200.0], confidence: 1.0, staleness: 0.0}]

      assert {:ok, %{z: z, receipt: receipt}} =
               Engine.couple(proposals, %{lower: [-5.0, 0.0], upper: [5.0, 100.0]})

      assert z == [-5.0, 100.0]

      assert {:bound_clamped, %{bound: :lower, value: -5.0}} = receipt[0]
      assert {:bound_clamped, %{bound: :upper, value: 100.0}} = receipt[1]
    end

    test "clamping through the Ash action persists the real clamped z" do
      {:ok, run} =
        CouplingRun
        |> Ash.Changeset.for_create(:couple, %{
          proposals: [%{"id" => "a", "vector" => [-100.0, 200.0],
                        "confidence" => 1.0, "staleness" => 0.0}],
          constraints: %{"lower" => [-5.0, 0.0], "upper" => [5.0, 100.0]}
        })
        |> Ash.create()

      assert run.status == :solved
      assert run.z == [-5.0, 100.0]
      assert run.receipt["0"]["kind"] == "bound_clamped"
      assert run.receipt["0"]["detail"]["bound"] == "lower"
      assert run.receipt["1"]["detail"]["bound"] == "upper"
    end
  end

  describe "(c) typed refusals on degenerate inputs (real engine contract)" do
    test "empty proposal set" do
      assert {:error, %{reason: :empty_proposal_set}} = Engine.couple([], %{})
    end

    test "mismatched vector dimensions" do
      proposals = [
        %{id: "a", vector: [1.0, 2.0], confidence: 1.0, staleness: 0.0},
        %{id: "b", vector: [1.0], confidence: 1.0, staleness: 0.0}
      ]

      assert {:error, %{reason: :mismatched_vector_dimensions, dims: [2, 1]}} =
               Engine.couple(proposals, %{})
    end

    test "bound-vector dimension mismatch" do
      proposals = [%{id: "a", vector: [1.0, 2.0], confidence: 1.0, staleness: 0.0}]

      assert {:error, %{reason: :mismatched_bound_dimensions}} =
               Engine.couple(proposals, %{lower: [0.0], upper: [1.0, 1.0]})
    end

    test "zero total weight (all confidence 0) -- no division by zero" do
      proposals = [
        %{id: "a", vector: [1.0], confidence: 0.0, staleness: 0.0},
        %{id: "b", vector: [2.0], confidence: 0.0, staleness: 0.0}
      ]

      assert {:infeasible, %{reason: :zero_total_weight}} = Engine.couple(proposals, %{})
    end

    test "infeasible box names the exact conflicting coordinate" do
      proposals = [%{id: "a", vector: [5.0, 5.0], confidence: 1.0, staleness: 0.0}]

      assert {:infeasible,
              %{reason: :box_constraints_infeasible,
                minimal_unsatisfiable_constraints: [conflict]}} =
               Engine.couple(proposals, %{lower: [10.0, 0.0], upper: [1.0, 10.0]})

      assert conflict == %{coordinate: 0, lower: 10.0, upper: 1.0}
    end

    test "malformed proposal (confidence out of range) is a typed error" do
      proposals = [%{id: "a", vector: [1.0], confidence: 1.5, staleness: 0.0}]

      assert {:error, %{reason: :malformed_proposal}} = Engine.couple(proposals, %{})
    end

    test "general affine constraints are refused, not faked (UNSUPPORTED)" do
      proposals = [%{id: "a", vector: [1.0], confidence: 1.0, staleness: 0.0}]

      assert {:unsupported, %{reason: :general_affine_constraints_unsupported}} =
               Engine.couple(proposals, %{e_eq: [[1.0, 1.0]], f_eq: [3.0]})
    end

    test "degenerate inputs through the Ash action: infeasible persists, error fails admission" do
      # zero-weight case persists as a real :infeasible run
      {:ok, run} =
        CouplingRun
        |> Ash.Changeset.for_create(:couple, %{
          proposals: [%{"id" => "a", "vector" => [1.0], "confidence" => 0.0, "staleness" => 0.0}],
          constraints: %{}
        })
        |> Ash.create()

      assert run.status == :infeasible
      assert run.unsupported_reason["reason"] == "zero_total_weight"
      assert run.z == nil

      # empty set fails admission with a real changeset error
      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               CouplingRun
               |> Ash.Changeset.for_create(:couple, %{proposals: [], constraints: %{}})
               |> Ash.create()

      assert Enum.any?(errors, &(&1.field == :proposals))
    end
  end

  describe "(d) determinism x3" do
    test "engine: three runs over shuffled inputs give bit-identical z, weights, receipt" do
      ln2 = :math.log(2)

      proposals = [
        %{id: "a", vector: [4.0, -1.0], confidence: 0.5, staleness: 0.0},
        %{id: "b", vector: [6.0, 3.0], confidence: 0.25, staleness: ln2},
        %{id: "c", vector: [2.0, 0.5], confidence: 0.9, staleness: 0.25}
      ]

      {:ok, r1} = Engine.couple(proposals, %{lower: [-10.0, -10.0], upper: [10.0, 10.0]})
      {:ok, r2} = Engine.couple(Enum.reverse(proposals), %{lower: [-10.0, -10.0], upper: [10.0, 10.0]})
      {:ok, r3} = Engine.couple(Enum.shuffle(proposals), %{lower: [-10.0, -10.0], upper: [10.0, 10.0]})

      assert r1.z == r2.z
      assert r1.z == r3.z
      assert r1.weights == r2.weights
      assert r1.weights == r3.weights
      assert r1.receipt == r3.receipt
    end

    test "Ash action: three identical creates produce bit-identical solved state" do
      proposals = [
        %{"id" => "a", "vector" => [4.0, -1.0], "confidence" => 0.5, "staleness" => 0.0},
        %{"id" => "b", "vector" => [6.0, 3.0], "confidence" => 0.25, "staleness" => 0.6931}
      ]

      runs =
        for _ <- 1..3 do
          {:ok, run} =
            CouplingRun
            |> Ash.Changeset.for_create(:couple, %{proposals: proposals, constraints: %{}})
            |> Ash.create()

          run
        end

      assert [r1, r2, r3] = runs
      assert r1.status == :solved
      assert r1.z == r2.z and r1.z == r3.z
      assert r1.weights == r2.weights and r1.weights == r3.weights
      assert r1.receipt == r2.receipt and r1.receipt == r3.receipt
    end
  end
end
