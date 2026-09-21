defmodule Xaas.Billing.FiboRevenueActuationTest do
  @moduledoc """
  Chicago-style qualification for the FIBO revenue admission and Reactor DO boundary.
  """

  use ExUnit.Case, async: true

  alias Xaas.Billing.{FiboRevenueProfile, Revenue, RevenueRecognition}
  alias Xaas.Operations.ActuationReceipt
  alias Xaas.Semantics.Registry

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp revenue_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        org_id: "org-fibo-revenue",
        accounting_classification: "revenue",
        recognition_basis: "performance_obligation_satisfied",
        amount: "125.50",
        currency: "USD",
        contract_ref: "contract-123",
        external_ref: "invoice-123",
        evidence: %{"kind" => "invoice", "id" => "invoice-123"}
      },
      overrides
    )
  end

  defp actuation_input do
    %{
      org_id: "org-fibo-direct",
      source_key: "service_fee",
      source_label: "Service fee",
      source_iri: FiboRevenueProfile.cash_flow_iri(),
      source_revision: FiboRevenueProfile.fibo_revision(),
      economic_family: "service",
      accounting_classification: "revenue",
      recognition_basis: "earned",
      amount: Decimal.new("10.00"),
      currency: "USD",
      evidence: %{}
    }
  end

  test "the named revenue profile is broad, FIBO-grounded and revision-pinned" do
    sources = FiboRevenueProfile.named_sources()

    assert length(sources) >= 90
    assert Enum.all?(sources, &FiboRevenueProfile.fibo_iri?(&1.ontology_iri))
    assert Enum.all?(sources, &(&1.ontology_revision == FiboRevenueProfile.fibo_revision()))
    assert Enum.any?(sources, &(&1.key == "product_sale"))
    assert Enum.any?(sources, &(&1.key == "subscription_fee"))
    assert Enum.any?(sources, &(&1.key == "interest_income"))
    assert Enum.any?(sources, &(&1.key == "dividend_income"))
    assert Enum.any?(sources, &(&1.key == "insurance_premium"))
    assert Enum.any?(sources, &(&1.key == "option_premium"))
    assert Enum.any?(sources, &(&1.key == "fx_spread"))
    assert Enum.any?(sources, &(&1.key == "carried_interest"))
    assert Enum.any?(sources, &(&1.key == "licensing_fee"))
    assert Enum.any?(sources, &(&1.key == "rental_income"))

    for source <- FiboRevenueProfile.non_revenue_sources() do
      assert {:error, {:non_revenue_cash_flow, ^source}} =
               FiboRevenueProfile.admit_source(source)
    end
  end

  test "a future exact FIBO concept can be admitted without widening namespace or revision" do
    iri =
      "https://spec.edmcouncil.org/fibo/ontology/FBC/DebtAndEquities/Debt/InterestPayment"

    assert {:ok, source} =
             FiboRevenueProfile.admit_source(%{
               key: "contract_interest",
               label: "Contractual interest payment",
               family: "financing_return",
               ontology_iri: iri
             })

    assert source.ontology_iri == iri
    assert source.ontology_revision == FiboRevenueProfile.fibo_revision()
    assert source.generic?

    assert {:error, {:unadmitted_fibo_revision, "other", _}} =
             FiboRevenueProfile.admit_source(%{
               key: "contract_interest",
               label: "Contractual interest payment",
               family: "financing_return",
               ontology_iri: iri,
               ontology_revision: "other"
             })

    assert {:error, {:non_fibo_revenue_source, _}} =
             FiboRevenueProfile.admit_source(%{
               key: "private_term",
               label: "Private term",
               ontology_iri: "https://xaas.local/vocab#Revenue"
             })
  end

  test "revenue recognition has a public ontology projection with FIBO amount and version semantics" do
    projection = RevenueRecognition.ontology_projection!()
    amount = Enum.find(projection.attributes, &(&1.ash_name == :amount))
    source_revision = Enum.find(projection.attributes, &(&1.ash_name == :source_revision))

    assert "http://www.w3.org/ns/prov#Activity" in projection.classes

    assert amount.predicate ==
             "https://spec.edmcouncil.org/fibo/ontology/FND/Accounting/CurrencyAmount/hasMonetaryAmount"

    assert source_revision.predicate == "http://purl.org/dc/terms/hasVersion"
    assert Registry.public_iri?(amount.predicate)
    assert Registry.public_iri?(source_revision.predicate)
    assert Registry.namespaces().fibo == FiboRevenueProfile.fibo_namespace()
  end

  test "direct consequential revenue create is refused without Reactor context" do
    assert {:error, %Ash.Error.Invalid{}} =
             RevenueRecognition
             |> Ash.Changeset.for_create(:actuate_recognition, actuation_input())
             |> Ash.create(authorize?: false)
  end

  test "revenue recognition actuates once, seals a receipt and replays deterministically" do
    key = "revenue-recognition-#{System.unique_integer([:positive])}"
    authority = %{kind: "accounting_admission", evidence_ref: "invoice-123"}

    assert {:ok, first} =
             Revenue.recognize(:service_fee, revenue_attrs(),
               idempotency_key: key,
               authority: authority
             )

    assert first.status == :succeeded
    refute first.replay?
    assert first.receipt.status == :succeeded
    assert first.receipt.ontology_projection_hash == RevenueRecognition.ontology_projection_hash()

    recognition = first.result
    assert recognition.source_key == "service_fee"
    assert recognition.source_iri == FiboRevenueProfile.cash_flow_iri()
    assert recognition.source_revision == FiboRevenueProfile.fibo_revision()
    assert recognition.accounting_classification == "revenue"
    assert recognition.currency == "USD"
    assert Decimal.equal?(recognition.amount, Decimal.new("125.50"))

    recognition_count = RevenueRecognition |> Ash.read!(authorize?: false) |> length()
    receipt_count = ActuationReceipt |> Ash.read!(authorize?: false) |> length()

    assert {:ok, replay} =
             Revenue.recognize(:service_fee, revenue_attrs(),
               idempotency_key: key,
               authority: authority
             )

    assert replay.status == :replayed
    assert replay.replay?
    assert replay.receipt.id == first.receipt.id
    assert RevenueRecognition |> Ash.read!(authorize?: false) |> length() == recognition_count
    assert ActuationReceipt |> Ash.read!(authorize?: false) |> length() == receipt_count
  end

  test "recognition refuses missing authority, invalid amount and non-revenue source" do
    assert {:error, :revenue_authority_evidence_required} =
             Revenue.recognize(:service_fee, revenue_attrs(), idempotency_key: "no-authority")

    assert {:error, {:revenue_amount_must_be_positive, "0"}} =
             Revenue.recognize(:service_fee, revenue_attrs(%{amount: "0"}),
               idempotency_key: "zero-amount",
               authority: %{kind: "test"}
             )

    assert {:error, {:non_revenue_cash_flow, "principal_repayment"}} =
             Revenue.recognize(:principal_repayment, revenue_attrs(),
               idempotency_key: "principal-is-not-revenue",
               authority: %{kind: "test"}
             )
  end
end
