defmodule Xaas.Semantics.VKG.Query do
  @moduledoc """
  XaaS admission object for a read-only virtual knowledge graph request.

  The object expresses application purpose and resource bounds. Source/mapping
  identities remain owned by the AshR2RML catalog and cannot be supplied or
  overridden by callers through this boundary.
  """

  alias AshR2RML.Refusal

  @enforce_keys [:id, :contract_ids, :purpose]
  defstruct [
    :id,
    :contract_ids,
    :purpose,
    max_rows: 5_000,
    timeout_ms: 10_000,
    merge: :union,
    capability: :select,
    authority: :NONE
  ]

  @type purpose ::
          :engineering_read
          | :failure_analysis
          | :semantic_jira
          | :process_intelligence
          | :knowledge_lookup

  @type t :: %__MODULE__{
          id: String.t(),
          contract_ids: [String.t()],
          purpose: purpose(),
          max_rows: pos_integer(),
          timeout_ms: pos_integer(),
          merge: :union | :by_subject,
          capability: atom(),
          authority: :NONE
        }

  @purposes [
    :engineering_read,
    :failure_analysis,
    :semantic_jira,
    :process_intelligence,
    :knowledge_lookup
  ]

  @spec new(map()) :: {:ok, t()} | {:error, Refusal.t()}
  def new(attrs) when is_map(attrs) do
    query = %__MODULE__{
      id: fetch(attrs, :id),
      contract_ids: fetch(attrs, :contract_ids) || [],
      purpose: fetch(attrs, :purpose),
      max_rows: fetch(attrs, :max_rows) || 5_000,
      timeout_ms: fetch(attrs, :timeout_ms) || 10_000,
      merge: fetch(attrs, :merge) || :union,
      capability: fetch(attrs, :capability) || :select,
      authority: normalize_authority(fetch(attrs, :authority))
    }

    admit(query)
  end

  def new(other), do: refusal(:query, "VKG query input must be a map", %{value: inspect(other)})

  @spec admit(t()) :: {:ok, t()} | {:error, Refusal.t()}
  def admit(%__MODULE__{} = query) do
    cond do
      not is_binary(query.id) or String.trim(query.id) == "" ->
        refusal(:id, "VKG query requires a stable non-empty id", %{id: query.id})

      not valid_contract_ids?(query.contract_ids) ->
        refusal(
          :contract_ids,
          "VKG query requires a non-empty list of unique source contract ids",
          %{contract_ids: query.contract_ids}
        )

      query.purpose not in @purposes ->
        refusal(:purpose, "VKG query purpose is not admitted", %{purpose: query.purpose})

      not is_integer(query.max_rows) or query.max_rows <= 0 ->
        refusal(:max_rows, "VKG query row bound must be a positive integer", %{max_rows: query.max_rows})

      not is_integer(query.timeout_ms) or query.timeout_ms <= 0 ->
        refusal(
          :timeout_ms,
          "VKG query timeout bound must be a positive integer",
          %{timeout_ms: query.timeout_ms}
        )

      query.merge not in [:union, :by_subject] ->
        refusal(:merge, "VKG query merge policy is unsupported", %{merge: query.merge})

      not is_atom(query.capability) ->
        refusal(:capability, "VKG query capability must be an atom", %{capability: query.capability})

      query.authority != :NONE ->
        refusal(
          :authority,
          "XaaS semantic observation cannot acquire consequential DO authority",
          %{authority: query.authority}
        )

      true ->
        {:ok, query}
    end
  end

  @spec digest(t()) :: String.t()
  def digest(%__MODULE__{} = query) do
    {
      query.id,
      query.contract_ids,
      query.purpose,
      query.max_rows,
      query.timeout_ms,
      query.merge,
      query.capability,
      query.authority
    }
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @spec with_contracts(t(), [String.t()]) :: {:ok, t()} | {:error, Refusal.t()}
  def with_contracts(%__MODULE__{} = query, contract_ids) do
    admit(%{query | contract_ids: contract_ids})
  end

  defp valid_contract_ids?(ids) when is_list(ids) and ids != [] do
    Enum.all?(ids, &(is_binary(&1) and String.trim(&1) != "")) and
      length(ids) == length(Enum.uniq(ids))
  end

  defp valid_contract_ids?(_), do: false

  defp normalize_authority(nil), do: :NONE
  defp normalize_authority(authority), do: authority

  defp fetch(map, key), do: Map.get(map, key, Map.get(map, Atom.to_string(key)))

  defp refusal(subject, detail, evidence) do
    {:error, Refusal.new(:REFUSED_XAAS_VKG_QUERY, subject, detail, evidence)}
  end
end
