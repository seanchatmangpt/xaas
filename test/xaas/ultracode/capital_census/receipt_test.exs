defmodule Xaas.Ultracode.CapitalCensus.ReceiptTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Qualification of the CapitalReceipt invariant chain (GC-26926-CENSUS):
  construction defaults + string-payload normalization; the partition /
  admitted⊆candidates / closure / residual-gap / route invariants as
  ANTI-VACUOUS refusals (a valid receipt is mutated one invariant at a
  time and every mutant is refused with the exact typed tuple); the
  residual-gap math including Gap = ∅ ⇒ LLM reasoning = 0; and the
  never-raise law on garbage input.
  """

  alias Xaas.Ultracode.CapitalCensus.Receipt

  @refusal {:refused, :unsupported_capability}

  defp world do
    %{
      observed_world: %{"repo" => "xaas", "base_sha" => String.duplicate("a", 40)},
      required_capabilities: ["compile", "test", "migrate"],
      candidates: [
        %{id: {:pack, "ash"}, covers: ["compile", "test"]},
        %{id: {:pack, "phx"}, covers: ["migrate"]},
        %{id: {:pack, "llm"}, covers: ["freeform"]}
      ],
      admitted: [{:pack, "ash"}],
      rejected: [{:pack, "phx"}],
      unknown: [{:pack, "llm"}],
      route: "plan"
    }
  end

  defp sealed, do: Receipt.new(world())

  defp mutant(edit), do: Map.merge(sealed(), edit)

  # -- construction + happy paths -----------------------------------------

  describe "new/1 + validate/1 happy paths" do
    test "a fully classified census receipt validates with derived closure and gap" do
      receipt = sealed()

      assert :ok = Receipt.validate(receipt)
      assert receipt.closure == ["compile", "test"]
      assert receipt.residual_gap == ["migrate"]
      assert receipt.route == :plan
    end

    test "missing buckets and derived fields default and still validate" do
      receipt = Receipt.new(%{required_capabilities: ["a", "b"]})

      assert :ok = Receipt.validate(receipt)
      assert receipt.candidates == []
      assert receipt.admitted == []
      assert receipt.closure == []
      assert receipt.residual_gap == ["a", "b"]
      assert receipt.route == nil
    end

    test "string-keyed payloads (JSON claim blocks) normalize onto atom keys" do
      receipt =
        Receipt.new(%{
          "observed_world" => %{"work_order" => "GC-26926-01"},
          "required_capabilities" => ["compile"],
          "candidates" => [%{"id" => {:pack, "ash"}, "covers" => ["compile"]}],
          "admitted" => [{:pack, "ash"}],
          "route" => "reuse"
        })

      assert :ok = Receipt.validate(receipt)
      assert receipt.route == :reuse
      assert receipt.residual_gap == []
    end

    test "the route lattice is the directive's eight rungs in order" do
      assert Receipt.lattice() == [
               :reuse,
               :compose,
               :rule,
               :plan,
               :constraint,
               :generate,
               :specialized_model,
               :llm
             ]
    end

    test "set semantics: reordering admitted or required stays admissible" do
      assert :ok = sealed() |> Map.update!(:admitted, &Enum.reverse/1) |> Receipt.validate()

      reordered =
        sealed()
        |> Map.put(:required_capabilities, ["migrate", "test", "compile"])
        |> Receipt.new()

      assert :ok = Receipt.validate(reordered)
      assert Receipt.residual_gap(reordered) == ["migrate"]
    end
  end

  # -- anti-vacuity: every mutant refused with the exact tuple -------------

  describe "validate/1 anti-vacuity: each violated invariant returns the exact refusal" do
    test "an admitted id outside the candidates is refused" do
      mutant = mutant(%{admitted: [{:pack, "ash"}, {:ghost, 1}]})

      assert @refusal = Receipt.validate(mutant)

      assert Enum.sort(Receipt.problems(mutant)) == [
               :admitted_outside_candidates,
               :candidates_not_partitioned
             ]
    end

    test "an unclassified candidate is a refusal, never a silent drop" do
      mutant = Map.update!(sealed(), :unknown, &List.delete(&1, {:pack, "llm"}))

      assert @refusal = Receipt.validate(mutant)
      assert Receipt.problems(mutant) == [:candidates_not_partitioned]
    end

    test "an id in two buckets breaks the partition" do
      mutant = Map.update!(sealed(), :unknown, &[{:pack, "phx"} | &1])

      assert @refusal = Receipt.validate(mutant)
      assert Receipt.problems(mutant) == [:candidates_not_partitioned]
    end

    test "a carried closure that disagrees with the admitted set is refused" do
      mutant = Map.put(sealed(), :closure, ["compile", "test", "freeform"])

      assert @refusal = Receipt.validate(mutant)
      assert Receipt.problems(mutant) == [:closure_mismatch]
    end

    test "a carried residual gap that disagrees with required − closure is refused" do
      mutant = Map.put(sealed(), :residual_gap, [])

      assert @refusal = Receipt.validate(mutant)
      assert Receipt.problems(mutant) == [:residual_gap_mismatch]
    end

    test "a route off the lattice is refused" do
      telepathy = mutant(%{route: :telepathy})
      numeric = mutant(%{route: 5})

      assert @refusal = Receipt.validate(telepathy)
      assert Receipt.problems(telepathy) == [:unknown_route]
      assert @refusal = Receipt.validate(numeric)
    end

    test "schema violations are refused" do
      assert @refusal = Receipt.validate("not a receipt")
      assert Receipt.problems("not a receipt") == [:invalid_schema]
      assert Receipt.problems(Map.delete(sealed(), :admitted)) == [:invalid_schema]

      assert Receipt.problems(Map.put(sealed(), :required_capabilities, "compile")) ==
               [:invalid_schema]
    end

    test "candidate shape violations are refused" do
      no_covers = Map.put(sealed(), :candidates, [%{id: :bare}])

      assert @refusal = Receipt.validate(no_covers)
      assert Receipt.problems(no_covers) == [:invalid_schema]

      dup_ids = Map.put(sealed(), :candidates, [%{id: :x, covers: []}, %{id: :x, covers: []}])

      assert @refusal = Receipt.validate(dup_ids)
      assert Receipt.problems(dup_ids) == [:invalid_schema]
    end

    test "new/1 carries malformed values verbatim for validate to refuse" do
      receipt = Receipt.new(%{required_capabilities: "compile", candidates: :all_of_it})

      assert @refusal = Receipt.validate(receipt)
      assert Receipt.problems(receipt) == [:invalid_schema]
    end
  end

  # -- gap math -------------------------------------------------------------

  describe "residual_gap/1 + closure/1: only ADMISSION closes capability" do
    test "found-but-unadmitted capital does not close the gap" do
      receipt =
        Receipt.new(%{
          required_capabilities: ["compile", "migrate"],
          candidates: [%{id: :found_only, covers: ["compile", "migrate"]}],
          rejected: [:found_only]
        })

      assert :ok = Receipt.validate(receipt)
      assert Receipt.closure(receipt) == []
      assert Receipt.residual_gap(receipt) == ["compile", "migrate"]
      assert Receipt.llm_reasoning_required?(receipt) == true
    end

    test "admitted capital closes exactly what it covers" do
      receipt =
        Receipt.new(%{
          required_capabilities: ["compile", "test", "migrate"],
          candidates: [%{id: :ash, covers: ["migrate", "compile", "extra"]}],
          admitted: [:ash]
        })

      assert :ok = Receipt.validate(receipt)
      assert Receipt.closure(receipt) == ["compile", "extra", "migrate"]
      assert Receipt.residual_gap(receipt) == ["test"]
    end
  end

  describe "the Gap = ∅ law" do
    test "full admitted coverage empties the gap and the owed LLM reasoning" do
      receipt =
        Receipt.new(%{
          required_capabilities: ["compile", "test"],
          candidates: [%{id: :pack, covers: ["test", "compile"]}],
          admitted: [:pack]
        })

      assert :ok = Receipt.validate(receipt)
      assert receipt.residual_gap == []
      assert Receipt.residual_gap(receipt) == []
      assert Receipt.llm_reasoning_required?(receipt) == false
    end

    test "a non-empty gap owes exactly the uncovered capabilities" do
      assert Receipt.llm_reasoning_required?(sealed()) == true
      assert Receipt.residual_gap(sealed()) == ["migrate"]
    end
  end

  # -- never raise ----------------------------------------------------------

  describe "never raises on garbage" do
    for garbage <- [nil, [], "receipt", 42, {:tuple, 1}] do
      test "validate/problems/residual_gap/closure survive #{inspect(garbage)}" do
        garbage = unquote(Macro.escape(garbage))

        assert @refusal = Receipt.validate(garbage)
        assert Receipt.problems(garbage) == [:invalid_schema]
        assert Receipt.residual_gap(garbage) == []
        assert Receipt.closure(garbage) == []
        assert Receipt.llm_reasoning_required?(garbage) == false
      end
    end
  end
end
