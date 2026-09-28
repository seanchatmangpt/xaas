defmodule Xaas.Semantics.VKG.Witness do
  @moduledoc """
  XaaS evidence envelope around one canonical AshR2RML VKG session.

  A witness is not authority and is not equivalent to source truth. It records
  the exact query admission identity and canonical federation receipt used by
  downstream XaaS consumers.
  """

  alias AshR2RML.Refusal
  alias AshR2RML.VKG.Session
  alias Xaas.Semantics.VKG.Query

  @enforce_keys [
    :id,
    :query_id,
    :query_sha256,
    :catalog_sha256,
    :plan_sha256,
    :result_sha256,
    :receipt_id,
    :contract_ids,
    :row_count,
    :session
  ]

  defstruct [
    :id,
    :query_id,
    :query_sha256,
    :catalog_sha256,
    :plan_sha256,
    :result_sha256,
    :receipt_id,
    :contract_ids,
    :row_count,
    :session,
    authority: :NONE,
    standing: :observed_not_actuated
  ]

  @type t :: %__MODULE__{}

  @spec from_session(Query.t(), Session.t()) :: {:ok, t()} | {:error, Refusal.t()}
  def from_session(%Query{} = query, %Session{} = session) do
    with {:ok, _} <- Query.admit(query),
         :ok <- Session.verify(session),
         :ok <- exact_contracts(query, session),
         :ok <- no_authority(session) do
      query_sha256 = Query.digest(query)

      identity =
        hash({
          query_sha256,
          session.catalog_sha256,
          session.plan.sha256,
          session.result.sha256,
          session.receipt.id
        })

      {:ok,
       %__MODULE__{
         id: "xaas-vkg-witness-" <> binary_part(identity, 0, 20),
         query_id: query.id,
         query_sha256: query_sha256,
         catalog_sha256: session.catalog_sha256,
         plan_sha256: session.plan.sha256,
         result_sha256: session.result.sha256,
         receipt_id: session.receipt.id,
         contract_ids: session.plan.contract_ids,
         row_count: session.result.row_count,
         session: session,
         authority: :NONE,
         standing: :observed_not_actuated
       }}
    end
  end

  @spec verify(t()) :: :ok | {:error, Refusal.t()}
  def verify(%__MODULE__{} = witness) do
    with :ok <- Session.verify(witness.session),
         true <- witness.catalog_sha256 == witness.session.catalog_sha256,
         true <- witness.plan_sha256 == witness.session.plan.sha256,
         true <- witness.result_sha256 == witness.session.result.sha256,
         true <- witness.receipt_id == witness.session.receipt.id,
         true <- witness.contract_ids == witness.session.plan.contract_ids,
         true <- witness.row_count == witness.session.result.row_count,
         true <- witness.authority == :NONE do
      :ok
    else
      {:error, %Refusal{} = refusal} ->
        {:error, refusal}

      _ ->
        refusal(
          :witness,
          "XaaS VKG witness fields no longer match the canonical session",
          %{witness_id: witness.id}
        )
    end
  end

  @spec summary(t()) :: map()
  def summary(%__MODULE__{} = witness) do
    %{
      id: witness.id,
      query_id: witness.query_id,
      query_sha256: witness.query_sha256,
      catalog_sha256: witness.catalog_sha256,
      plan_sha256: witness.plan_sha256,
      result_sha256: witness.result_sha256,
      receipt_id: witness.receipt_id,
      contract_ids: witness.contract_ids,
      row_count: witness.row_count,
      authority: witness.authority,
      standing: witness.standing
    }
  end

  defp exact_contracts(%Query{contract_ids: ids}, %Session{plan: plan}) do
    if ids == plan.contract_ids do
      :ok
    else
      refusal(
        :contract_ids,
        "canonical VKG plan does not match the admitted XaaS source set",
        %{query: ids, plan: plan.contract_ids}
      )
    end
  end

  defp no_authority(%Session{} = session) do
    if session.receipt.authority == :NONE do
      :ok
    else
      refusal(
        :authority,
        "canonical VKG receipt unexpectedly carries actuation authority",
        %{authority: session.receipt.authority}
      )
    end
  end

  defp hash(term) do
    term
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp refusal(subject, detail, evidence) do
    {:error, Refusal.new(:REFUSED_XAAS_VKG_WITNESS, subject, detail, evidence)}
  end
end
