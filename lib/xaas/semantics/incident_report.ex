defmodule Xaas.Semantics.IncidentReport do
  @moduledoc """
  Art 73 (serious-incident reporting) builder over the witnessed receipt
  corpus.

  ## Mapping (Art 73(1) triggers -> classification derivation)

  Art 73(1) defines a serious incident by its trigger class. Each witnessed
  receipt carries a typed refusal atom (or an actuation-failure status); the
  classification is *derived*, never asserted:

  | Art 73(1) trigger class          | receipt evidence                              | classification atom |
  |---|---|---|
  | infringement of Union law        | typed refusal atom `REFUSED_EUAIA_*` (Art 5(1) prohibited-practice corpus, `eu_ai_act_admission.ex`) | `:INFRINGES_UNION_LAW` |
  | harm to fundamental rights       | refusal atom matching `*_RIGHTS_*`/`*_HARM_*` or receipt field `rights_harm: true` | `:HARM_TO_RIGHTS` |
  | malfunction / unauthorized actuation | actuation receipt with `status: :refused` / `:error` carrying any other refusal atom | `:MALFUNCTION` |

  A receipt may evidence more than one trigger; the classification is the
  deterministically sorted list of all applicable atoms.

  ## Honest delivery channel

  The report builder is real. The transmission channel to a market
  surveillance authority is **typed OPEN** per corpus 73.4-73.5: no authority
  endpoint exists in this deployment, so `transmit/1` returns
  `{:ok, %{status: :PREPARED_NOT_TRANSMITTED, ...}}` — prepared, never
  silently "sent".

  This module is a semantics surface only. It never actuates and is wired
  into no live route.
  """

  @refusal_prefix "REFUSED_EUAIA_"

  @type classification ::
          :INFRINGES_UNION_LAW
          | :HARM_TO_RIGHTS
          | :MALFUNCTION

  @typedoc """
  A witnessed receipt. Only structural fields are inspected: a digest (or
  id), an optional typed refusal atom, and an optional status.
  """
  @type receipt :: %{
          optional(:digest) => term(),
          optional(:id) => term(),
          optional(:refusal_atom) => atom() | String.t(),
          optional(:status) => atom(),
          optional(:rights_harm) => boolean(),
          optional(:observed_at) => term()
        }

  @type report :: %{
          incident_id: String.t(),
          originating_receipt_digests: [term()],
          description: String.t(),
          classification: [classification()],
          temporal: %{first_observed: term(), last_observed: term()}
        }

  @spec build([receipt()], keyword()) ::
          {:ok, report()} | {:error, :REFUSED_NO_INCIDENT_EVIDENCE}
  def build(receipts, opts \\ [])

  def build([], _opts), do: {:error, :REFUSED_NO_INCIDENT_EVIDENCE}
  def build(nil, _opts), do: {:error, :REFUSED_NO_INCIDENT_EVIDENCE}

  def build(receipts, opts) when is_list(receipts) do
    digests = Enum.map(receipts, &receipt_digest/1)

    classification =
      receipts
      |> Enum.flat_map(&classifications_for/1)
      |> Enum.uniq()
      |> Enum.sort()

    description =
      Keyword.get(opts, :description) || default_description(receipts, classification)

    incident_id =
      Keyword.get(opts, :incident_id) ||
        ("INC-" <> Base.encode16(:crypto.hash(:sha256, :erlang.term_to_iovec(digests)), padding: false))

    temporal = %{
      first_observed: receipts |> Enum.map(&observed_at/1) |> Enum.min(),
      last_observed: receipts |> Enum.map(&observed_at/1) |> Enum.max()
    }

    {:ok,
     %{
       incident_id: incident_id,
       originating_receipt_digests: digests,
       description: description,
       classification: classification,
       temporal: temporal
     }}
  end

  @doc """
  Art 73 transmission channel. Typed OPEN: no authority endpoint exists, so
  the report is returned PREPARED, never transmitted.
  """
  @spec transmit(report() | map()) ::
          {:ok, %{status: :PREPARED_NOT_TRANSMITTED, reason: String.t()}}
  def transmit(_report) do
    {:ok,
     %{
       status: :PREPARED_NOT_TRANSMITTED,
       reason: "no authority endpoint exists — typed OPEN per corpus 73.4-73.5"
     }}
  end

  defp default_description(receipts, classification) do
    "Art 73(1) serious-incident report built from #{length(receipts)} witnessed " <>
      "receipt(s); classification #{inspect(classification)} derived from typed " <>
      "refusal evidence. Transmission to a market surveillance authority is typed " <>
      "OPEN (corpus 73.4-73.5)."
  end

  ## Classification derivation

  defp classifications_for(receipt) do
    refusal = normalized_refusal(receipt)

    []
    |> maybe_add_infringement(refusal)
    |> maybe_add_rights_harm(refusal, receipt)
    |> maybe_add_malfunction(refusal, receipt)
  end

  defp maybe_add_infringement(acc, refusal) when is_binary(refusal) do
    if String.starts_with?(refusal, @refusal_prefix),
      do: [:INFRINGES_UNION_LAW | acc],
      else: acc
  end

  defp maybe_add_infringement(acc, _), do: acc

  defp maybe_add_rights_harm(acc, refusal, receipt) do
    rights_harm? =
      receipt[:rights_harm] == true or
        (is_binary(refusal) and
           (String.contains?(refusal, "_RIGHTS_") or String.contains?(refusal, "_HARM_")))

    if rights_harm?, do: [:HARM_TO_RIGHTS | acc], else: acc
  end

  defp maybe_add_malfunction(acc, refusal, receipt) do
    malfunction? =
      (is_binary(refusal) and not String.starts_with?(refusal, @refusal_prefix) and
         refusal != "") or
        receipt[:status] in [:refused, :error]

    if malfunction?, do: [:MALFUNCTION | acc], else: acc
  end

  ## Field extraction

  defp normalized_refusal(%{refusal_atom: a}) when is_atom(a), do: Atom.to_string(a)
  defp normalized_refusal(%{refusal_atom: s}) when is_binary(s), do: s
  defp normalized_refusal(_), do: nil

  defp receipt_digest(%{digest: d}) when not is_nil(d), do: d
  defp receipt_digest(%{id: id}) when not is_nil(id), do: id

  defp receipt_digest(receipt) do
    # Deterministic fallback digest over the receipt's structural fields.
    "sha256:" <>
      Base.encode16(:crypto.hash(:sha256, :erlang.term_to_iovec(receipt)), padding: false)
  end

  defp observed_at(%{observed_at: t}) when not is_nil(t), do: t
  defp observed_at(_), do: ~U[1970-01-01 00:00:00Z]
end
