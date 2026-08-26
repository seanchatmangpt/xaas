defmodule Xaas.Billing.Revenue do
  @moduledoc """
  Admission and actuation API for FIBO-grounded revenue recognition.

  This module never infers revenue from a cash receipt. It requires a revenue-capable
  FIBO source, explicit accounting classification and recognition basis, a positive
  monetary amount, an idempotency key, and non-empty authority evidence. Successful
  recognition is then delegated to `Xaas.Actuation`, which is the exclusive DO path.
  """

  alias Xaas.Billing.{FiboRevenueProfile, RevenueRecognition}

  @accounting_classifications MapSet.new([
                                "revenue",
                                "other_income",
                                "contra_revenue"
                              ])

  @doc "Recognizes an admitted economic source through the Ash.Reactor actuation boundary."
  @spec recognize(String.t() | atom() | map(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def recognize(source, attrs, opts \\ [])

  def recognize(source, attrs, opts) when is_map(attrs) do
    with {:ok, source_meta} <- FiboRevenueProfile.admit_source(source),
         {:ok, idempotency_key} <- required_string(opts, :idempotency_key),
         {:ok, authority} <- required_authority(opts),
         {:ok, org_id} <- required_attr(attrs, :org_id),
         {:ok, classification} <- accounting_classification(attrs),
         {:ok, recognition_basis} <- required_attr(attrs, :recognition_basis),
         {:ok, amount} <- positive_amount(attrs),
         {:ok, currency} <- currency(attrs) do
      input =
        attrs
        |> optional_input()
        |> Map.merge(%{
          org_id: org_id,
          source_key: source_meta.key,
          source_label: source_meta.label,
          source_iri: source_meta.ontology_iri,
          source_revision: source_meta.ontology_revision,
          economic_family: source_meta.family,
          accounting_classification: classification,
          recognition_basis: recognition_basis,
          amount: amount,
          currency: currency
        })

      authority =
        Map.merge(authority, %{
          revenue_control: "fibo_revenue_profile",
          revenue_source_iri: source_meta.ontology_iri,
          revenue_source_revision: source_meta.ontology_revision,
          revenue_source_key: source_meta.key
        })

      Xaas.Actuation.run(
        RevenueRecognition,
        :actuate_recognition,
        input,
        idempotency_key: idempotency_key,
        actor: Keyword.get(opts, :actor),
        tenant: Keyword.get(opts, :tenant),
        authorize?: false,
        authority: authority
      )
    end
  end

  def recognize(_source, _attrs, _opts), do: {:error, :revenue_attributes_must_be_a_map}

  defp accounting_classification(attrs) do
    with {:ok, value} <- required_attr(attrs, :accounting_classification),
         true <- MapSet.member?(@accounting_classifications, value) do
      {:ok, value}
    else
      false -> {:error, {:invalid_accounting_classification, attr(attrs, :accounting_classification)}}
      {:error, _} = error -> error
    end
  end

  defp positive_amount(attrs) do
    case attr(attrs, :amount) do
      nil ->
        {:error, {:required_revenue_attribute, :amount}}

      value ->
        case Decimal.cast(value) do
          {:ok, decimal} ->
            if Decimal.compare(decimal, Decimal.new(0)) == :gt do
              {:ok, decimal}
            else
              {:error, {:revenue_amount_must_be_positive, value}}
            end

          :error ->
            {:error, {:invalid_revenue_amount, value}}
        end
    end
  end

  defp currency(attrs) do
    case attr(attrs, :currency) do
      currency when is_binary(currency) ->
        currency = String.upcase(currency)

        if String.match?(currency, ~r/^[A-Z]{3}$/) do
          {:ok, currency}
        else
          {:error, {:invalid_currency_code, currency}}
        end

      other ->
        {:error, {:invalid_currency_code, other}}
    end
  end

  defp required_attr(attrs, key) do
    case attr(attrs, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, {:required_revenue_attribute, key}}
    end
  end

  defp required_string(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, key}
    end
  end

  defp required_authority(opts) do
    case Keyword.get(opts, :authority) do
      authority when is_map(authority) and map_size(authority) > 0 -> {:ok, authority}
      _ -> {:error, :revenue_authority_evidence_required}
    end
  end

  defp optional_input(attrs) do
    [
      :contract_ref,
      :counterparty_ref,
      :external_ref,
      :evidence,
      :period_start,
      :period_end,
      :recognized_at
    ]
    |> Enum.reduce(%{}, fn key, acc ->
      case attr(attrs, key) do
        nil -> acc
        value -> Map.put(acc, key, value)
      end
    end)
  end

  defp attr(attrs, key), do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))
end
