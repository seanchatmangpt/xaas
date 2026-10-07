defmodule Xaas.Billing.FiboProfileAdmissionBoundaryW650yTest do
  @moduledoc """
  Lane W650y coverage court on `Xaas.Billing.FiboRevenueProfile` — the closed-world
  admission boundary that decides which economic mechanisms may become real
  `Xaas.Billing.RevenueRecognition` state.

  Existing coverage (fibo_revenue_actuation_test.exs) courts only happy paths:
  named-source admission, one generic-FIBO map admission, revision mismatch and a
  non-FIBO IRI refusal. The error arms that actually gate the accounting boundary
  — label/family requiredness, non-revenue keys arriving through the map form,
  atom/other dispatch, and closed-world consistency between the named profile and
  the non-revenue exclusion set — were uncourted. Each test below names the
  mutation it kills.
  """

  use ExUnit.Case, async: true

  alias Xaas.Billing.FiboRevenueProfile

  @fibo FiboRevenueProfile.fibo_namespace()
  @revision FiboRevenueProfile.fibo_revision()
  @cash_flow FiboRevenueProfile.cash_flow_iri()

  describe "string/atom-form admission dispatch" do
    test "named binary admits with exact family/label and generic?: false" do
      # Mutation rationale: if a named entry's family/label tuple is corrupted
      # (or `generic?: false` is dropped), revenue rows would be created with a
      # wrong economic classification while still passing the happy-path court,
      # which only spot-checks a handful of keys.
      assert {:ok, s} = FiboRevenueProfile.admit_source("late_fee")
      assert s.key == "late_fee"
      assert s.family == "penalty"
      assert s.label == "Late fee"
      assert s.generic? == false
      assert s.ontology_iri == @cash_flow
      assert s.ontology_revision == @revision

      assert {:ok, s2} = FiboRevenueProfile.admit_source("marketplace_take_rate")
      assert s2.family == "transaction"
      assert s2.generic? == false
    end

    test "unknown binary is a typed refusal; non-revenue set wins over any other arm" do
      # Mutation rationale: reordering the cond so the named-source arm precedes
      # the non-revenue arm (or deleting the unknown-source fallthrough) would
      # let principal flows (debt proceeds, customer deposits) be admitted as
      # revenue — the exact accounting-boundary failure this module exists to
      # prevent. The "loan_proceeds" key must refuse even though it is a
      # plausible-looking binary.
      assert {:error, {:unknown_revenue_source, "crypto_gains"}} =
               FiboRevenueProfile.admit_source("crypto_gains")

      for source <- FiboRevenueProfile.non_revenue_sources() do
        assert {:error, {:non_revenue_cash_flow, ^source}} =
                 FiboRevenueProfile.admit_source(source)
      end

      assert {:error, {:non_revenue_cash_flow, "loan_proceeds"}} =
               FiboRevenueProfile.admit_source("loan_proceeds")
    end

    test "atom form delegates to binary form; non-binary garbage is an invalid-source refusal" do
      # Mutation rationale: removing the atom clause or the catch-all clause
      # would raise FunctionClauseError on caller input instead of returning a
      # typed refusal, turning an accounting-boundary rejection into a 500.
      assert {:ok, s} = FiboRevenueProfile.admit_source(:subscription_fee)
      assert s.key == "subscription_fee"
      assert s.family == "recurring_service"

      assert {:error, {:invalid_revenue_source, 42}} = FiboRevenueProfile.admit_source(42)
      assert {:error, {:invalid_revenue_source, []}} = FiboRevenueProfile.admit_source([])

      # nil is an atom in Elixir, so it routes through the atom clause and is
      # stringified: still a typed refusal, never a raise. Pinned as-observed.
      assert {:error, {:unknown_revenue_source, "nil"}} = FiboRevenueProfile.admit_source(nil)
    end
  end

  describe "map-form admission (generic FIBO path)" do
    test "requiredness refusals: empty label, empty family, missing IRI, wrong revision" do
      # Mutation rationale: each arm below is a distinct weakening of the
      # closed-world gate. Accepting an empty label or family produces unlabeled
      # revenue rows; accepting a nil/external IRI breaks FIBO namespace
      # containment; accepting a drifted revision breaks semantic replay of
      # historical receipts (the revision is pinned into every admission).
      iri = @fibo <> "FND/Accounting/CashFlows/CashFlow"

      assert {:error, :source_label_required} =
               FiboRevenueProfile.admit_source(%{
                 key: "k",
                 label: "",
                 family: "f",
                 ontology_iri: iri
               })

      assert {:error, :source_label_required} =
               FiboRevenueProfile.admit_source(%{
                 key: "k",
                 family: "f",
                 ontology_iri: iri
               })

      assert {:error, :source_family_required} =
               FiboRevenueProfile.admit_source(%{
                 key: "k",
                 label: "L",
                 family: "",
                 ontology_iri: iri
               })

      assert {:error, {:non_fibo_revenue_source, nil}} =
               FiboRevenueProfile.admit_source(%{key: "k", label: "L", family: "f"})

      assert {:error, {:unadmitted_fibo_revision, "1999", @revision}} =
               FiboRevenueProfile.admit_source(%{
                 key: "k",
                 label: "L",
                 family: "f",
                 ontology_iri: iri,
                 ontology_revision: "1999"
               })
    end

    test "defaults and string-keyed maps: family/key defaults applied, string keys honored, non-revenue key refuses" do
      # Mutation rationale: dropping the Map.get || Map.get("...") fallbacks or
      # the "custom_fibo"/"fibo_cash_flow" defaults silently changes the shape
      # of every generic admission; letting a non-revenue key through the map
      # form would allow debt proceeds to become revenue by simply wrapping
      # them in a map — bypassing the binary-form refusal courted above.
      assert {:ok, s} =
               FiboRevenueProfile.admit_source(%{
                 "ontology_iri" => @fibo <> "FBC/DebtAndEquities/Debt/InterestPayment",
                 "label" => "Contract interest"
               })

      assert s.key == "custom_fibo"
      assert s.family == "fibo_cash_flow"
      assert s.generic? == true
      assert s.ontology_revision == @revision

      assert {:ok, s2} =
               FiboRevenueProfile.admit_source(%{
                 key: :contract_interest,
                 label: "Contract interest",
                 ontology_iri: @fibo <> "FND/Accounting/CashFlows/CashFlow"
               })

      assert s2.key == "contract_interest"
      assert s2.family == "fibo_cash_flow"

      assert {:error, {:non_revenue_cash_flow, "customer_deposit"}} =
               FiboRevenueProfile.admit_source(%{
                 key: "customer_deposit",
                 label: "Deposit",
                 family: "f",
                 ontology_iri: @cash_flow
               })

      assert {:error, {:non_revenue_cash_flow, "tax_collected"}} =
               FiboRevenueProfile.admit_source(%{
                 "key" => "tax_collected",
                 "label" => "Tax",
                 "family" => "f",
                 "ontology_iri" => @cash_flow
               })
    end
  end

  describe "closed-world consistency and predicate guards" do
    test "named profile and non-revenue set are disjoint; every named source admits" do
      # Mutation rationale: if a key is added to both @revenue_sources and
      # @non_revenue_sources (split-brain edit), the binary cond silently
      # classifies it as non-revenue while named_sources still advertises it as
      # revenue-capable — the advertised surface and the admission gate
      # disagree. The sorted-order assertion also kills a mutation that breaks
      # deterministic enumeration of the profile.
      named_keys = FiboRevenueProfile.named_sources() |> Enum.map(& &1.key)
      excluded = FiboRevenueProfile.non_revenue_sources()

      assert named_keys == Enum.sort(named_keys)
      assert excluded == Enum.sort(excluded)
      assert MapSet.disjoint?(MapSet.new(named_keys), MapSet.new(excluded))

      for key <- named_keys do
        assert {:ok, s} = FiboRevenueProfile.admit_source(key)
        assert s.generic? == false
        assert s.ontology_revision == @revision
        assert s.ontology_iri == @cash_flow
      end
    end

    test "fibo_iri?/non_revenue? are total predicates that never raise on non-binary input" do
      # Mutation rationale: removing the catch-all clauses would make these
      # predicates raise FunctionClauseError on caller input (e.g. nil IRI from
      # a malformed map), converting a containment check into a crash.
      assert FiboRevenueProfile.fibo_iri?(@fibo <> "FND/Accounting/CashFlows/CashFlow")
      refute FiboRevenueProfile.fibo_iri?("https://xaas.local/vocab#Revenue")
      refute FiboRevenueProfile.fibo_iri?(nil)
      refute FiboRevenueProfile.fibo_iri?(:fibo)
      refute FiboRevenueProfile.fibo_iri?(123)

      assert FiboRevenueProfile.non_revenue?(:principal_repayment)
      assert FiboRevenueProfile.non_revenue?("internal_transfer")
      refute FiboRevenueProfile.non_revenue?("subscription_fee")
      refute FiboRevenueProfile.non_revenue?(123)
      refute FiboRevenueProfile.non_revenue?(nil)
    end
  end
end
