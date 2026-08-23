defmodule Xaas.Billing.FiboRevenueProfile do
  @moduledoc """
  Closed-world admission profile for revenue-capable economic mechanisms over FIBO.

  FIBO is a modular financial ontology, not a normative accounting chart of revenue
  accounts. XAAS therefore does not pretend that a finite enum is "all of FIBO".
  Instead this module provides:

    * a broad named profile of revenue-capable mechanisms used by the runtime;
    * explicit exclusions for cash movements that must never be inferred as revenue;
    * a generic FIBO-IRI path so newly published or more specific FIBO concepts can be
      admitted without weakening the namespace or accounting boundary.

  Every admitted source is anchored in FIBO. The generic cash-flow anchor is the FIBO
  FND `CashFlow` class; more specific source IRIs may be supplied by callers when their
  evidence names a narrower FIBO concept. Accounting classification remains explicit:
  cash movement alone never establishes revenue standing.
  """

  @fibo "https://spec.edmcouncil.org/fibo/ontology/"
  @cash_flow @fibo <> "FND/Accounting/CashFlows/CashFlow"

  @revenue_sources %{
    "subscription_fee" => {"recurring_service", "Subscription fee"},
    "usage_fee" => {"recurring_service", "Usage fee"},
    "service_fee" => {"service", "Service fee"},
    "platform_fee" => {"service", "Platform fee"},
    "transaction_fee" => {"transaction", "Transaction fee"},
    "payment_processing_fee" => {"transaction", "Payment processing fee"},
    "interchange_fee" => {"transaction", "Interchange fee"},
    "marketplace_take_rate" => {"transaction", "Marketplace take rate"},
    "brokerage_commission" => {"commission", "Brokerage commission"},
    "sales_commission" => {"commission", "Sales commission"},
    "referral_fee" => {"commission", "Referral fee"},
    "management_fee" => {"fiduciary_service", "Management fee"},
    "advisory_fee" => {"fiduciary_service", "Advisory fee"},
    "administration_fee" => {"fiduciary_service", "Administration fee"},
    "custody_fee" => {"fiduciary_service", "Custody fee"},
    "servicing_fee" => {"fiduciary_service", "Servicing fee"},
    "origination_fee" => {"financing_service", "Origination fee"},
    "underwriting_fee" => {"financing_service", "Underwriting fee"},
    "arrangement_fee" => {"financing_service", "Arrangement fee"},
    "commitment_fee" => {"financing_service", "Commitment fee"},
    "guarantee_fee" => {"financing_service", "Guarantee fee"},
    "interest_income" => {"financing_return", "Interest income"},
    "coupon_income" => {"financing_return", "Coupon income"},
    "discount_accretion" => {"financing_return", "Discount accretion"},
    "dividend_income" => {"investment_return", "Dividend income"},
    "investment_distribution" => {"investment_return", "Investment distribution"},
    "securities_lending_fee" => {"investment_service", "Securities lending fee"},
    "insurance_premium" => {"insurance", "Insurance premium"},
    "reinsurance_premium" => {"insurance", "Reinsurance premium"},
    "option_premium" => {"derivative", "Option premium"},
    "swap_net_receipt" => {"derivative", "Swap net receipt"},
    "fx_spread" => {"spread", "Foreign-exchange spread"},
    "bid_ask_spread" => {"spread", "Bid/ask spread"},
    "market_making_spread" => {"spread", "Market-making spread"},
    "realized_trading_gain" => {"trading", "Realized trading gain"},
    "performance_fee" => {"performance_compensation", "Performance fee"},
    "carried_interest" => {"performance_compensation", "Carried interest"},
    "licensing_fee" => {"intellectual_property", "Licensing fee"},
    "royalty_income" => {"intellectual_property", "Royalty income"},
    "rental_income" => {"property", "Rental income"},
    "lease_income" => {"property", "Lease income"},
    "advertising_income" => {"media", "Advertising income"},
    "late_fee" => {"penalty", "Late fee"},
    "prepayment_fee" => {"penalty", "Prepayment fee"},
    "termination_fee" => {"penalty", "Termination fee"},
    "exit_fee" => {"penalty", "Exit fee"}
  }

  @non_revenue_sources MapSet.new([
                         "principal_repayment",
                         "loan_proceeds",
                         "customer_deposit",
                         "collateral_return",
                         "security_deposit_return",
                         "capital_contribution",
                         "equity_proceeds",
                         "debt_proceeds",
                         "custodial_cash",
                         "settlement_pass_through",
                         "tax_collected",
                         "refund_reversal",
                         "internal_transfer",
                         "asset_sale_principal"
                       ])

  @doc "Canonical FIBO ontology namespace admitted by the revenue compiler."
  def fibo_namespace, do: @fibo

  @doc "FIBO FND cash-flow class used as the conservative economic anchor."
  def cash_flow_iri, do: @cash_flow

  @doc "Returns every named XAAS revenue-capable mechanism and its FIBO anchor."
  def named_sources do
    @revenue_sources
    |> Enum.map(fn {key, {family, label}} ->
      %{key: key, family: family, label: label, ontology_iri: @cash_flow}
    end)
    |> Enum.sort_by(& &1.key)
  end

  @doc "Returns the explicitly excluded non-revenue cash-flow classifications."
  def non_revenue_sources, do: @non_revenue_sources |> MapSet.to_list() |> Enum.sort()

  @doc "Admits one named or generic FIBO-grounded revenue source."
  @spec admit_source(String.t() | atom() | map()) :: {:ok, map()} | {:error, term()}
  def admit_source(source) when is_atom(source), do: admit_source(Atom.to_string(source))

  def admit_source(source) when is_binary(source) do
    cond do
      MapSet.member?(@non_revenue_sources, source) ->
        {:error, {:non_revenue_cash_flow, source}}

      source_meta = Map.get(@revenue_sources, source) ->
        {family, label} = source_meta

        {:ok,
         %{
           key: source,
           family: family,
           label: label,
           ontology_iri: @cash_flow,
           generic?: false
         }}

      String.starts_with?(source, @fibo) ->
        {:ok,
         %{
           key: "custom_fibo",
           family: "fibo_cash_flow",
           label: source,
           ontology_iri: source,
           generic?: true
         }}

      true ->
        {:error, {:unknown_revenue_source, source}}
    end
  end

  def admit_source(%{} = source) do
    key = Map.get(source, :key) || Map.get(source, "key") || "custom_fibo"
    label = Map.get(source, :label) || Map.get(source, "label")
    family = Map.get(source, :family) || Map.get(source, "family") || "fibo_cash_flow"
    iri = Map.get(source, :ontology_iri) || Map.get(source, "ontology_iri")

    cond do
      is_binary(key) and MapSet.member?(@non_revenue_sources, key) ->
        {:error, {:non_revenue_cash_flow, key}}

      not fibo_iri?(iri) ->
        {:error, {:non_fibo_revenue_source, iri}}

      not is_binary(label) or label == "" ->
        {:error, :source_label_required}

      not is_binary(family) or family == "" ->
        {:error, :source_family_required}

      true ->
        {:ok,
         %{
           key: to_string(key),
           family: family,
           label: label,
           ontology_iri: iri,
           generic?: true
         }}
    end
  end

  def admit_source(other), do: {:error, {:invalid_revenue_source, other}}

  @doc "True only for identifiers in the canonical FIBO ontology namespace."
  def fibo_iri?(iri) when is_binary(iri), do: String.starts_with?(iri, @fibo)
  def fibo_iri?(_), do: false

  @doc "True when a named key is explicitly known to be a non-revenue inflow."
  def non_revenue?(source) when is_atom(source), do: non_revenue?(Atom.to_string(source))
  def non_revenue?(source) when is_binary(source), do: MapSet.member?(@non_revenue_sources, source)
  def non_revenue?(_), do: false
end
