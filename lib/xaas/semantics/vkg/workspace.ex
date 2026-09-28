defmodule Xaas.Semantics.VKG.Workspace do
  @moduledoc """
  Application-facing composition of multiple XaaS VKG witnesses.

  Workspaces are immutable read models. They preserve all source receipts and
  never collapse two differing semantic subjects into an untraceable row.
  """

  alias AshR2RML.Refusal
  alias Xaas.Semantics.VKG.Witness

  @enforce_keys [:id, :witnesses, :entities, :sha256]
  defstruct [:id, :witnesses, :entities, :sha256, authority: :NONE]

  @type t :: %__MODULE__{}

  @spec build(String.t(), [Witness.t()]) :: {:ok, t()} | {:error, Refusal.t()}
  def build(id, witnesses) when is_binary(id) and is_list(witnesses) and witnesses != [] do
    with :ok <- validate_witnesses(witnesses),
         :ok <- unique_query_ids(witnesses) do
      ordered = Enum.sort_by(witnesses, & &1.query_id)
      entities = index_entities(ordered)
      sha256 = digest({id, Enum.map(ordered, &Witness.summary/1), canonical_entities(entities)})

      {:ok,
       %__MODULE__{
         id: id,
         witnesses: ordered,
         entities: entities,
         sha256: sha256,
         authority: :NONE
       }}
    end
  end

  def build(id, witnesses) do
    refusal(
      :workspace,
      "workspace requires a string id and at least one VKG witness",
      %{id: inspect(id), witness_count: if(is_list(witnesses), do: length(witnesses), else: nil)}
    )
  end

  @spec subjects(t()) :: [String.t()]
  def subjects(%__MODULE__{entities: entities}), do: entities |> Map.keys() |> Enum.sort()

  @spec fetch(t(), String.t()) :: {:ok, [map()]} | {:error, Refusal.t()}
  def fetch(%__MODULE__{entities: entities}, subject) do
    case Map.fetch(entities, subject) do
      {:ok, rows} -> {:ok, rows}
      :error -> refusal(subject, "semantic subject is not present in the workspace", %{})
    end
  end

  @spec provenance(t(), String.t()) :: {:ok, [map()]} | {:error, Refusal.t()}
  def provenance(%__MODULE__{} = workspace, subject) do
    with {:ok, rows} <- fetch(workspace, subject) do
      {:ok,
       rows
       |> Enum.map(&Map.get(&1, "_vkg"))
       |> Enum.reject(&is_nil/1)}
    end
  end

  @spec witness_index(t()) :: map()
  def witness_index(%__MODULE__{witnesses: witnesses}) do
    Map.new(witnesses, fn witness -> {witness.query_id, Witness.summary(witness)} end)
  end

  @spec verify(t()) :: :ok | {:error, Refusal.t()}
  def verify(%__MODULE__{} = workspace) do
    with :ok <- validate_witnesses(workspace.witnesses),
         true <- workspace.authority == :NONE,
         true <-
           workspace.sha256 ==
             digest({
               workspace.id,
               Enum.map(workspace.witnesses, &Witness.summary/1),
               canonical_entities(workspace.entities)
             }) do
      :ok
    else
      {:error, %Refusal{} = refusal} -> {:error, refusal}
      _ -> refusal(:workspace, "workspace digest or authority is invalid", %{id: workspace.id})
    end
  end

  defp validate_witnesses(witnesses) do
    witnesses
    |> Enum.reduce_while(:ok, fn witness, :ok ->
      case Witness.verify(witness) do
        :ok -> {:cont, :ok}
        {:error, refusal} -> {:halt, {:error, refusal}}
      end
    end)
  end

  defp unique_query_ids(witnesses) do
    ids = Enum.map(witnesses, & &1.query_id)

    if length(ids) == length(Enum.uniq(ids)) do
      :ok
    else
      refusal(:query_ids, "workspace refuses duplicate query identities", %{query_ids: ids})
    end
  end

  defp index_entities(witnesses) do
    Enum.reduce(witnesses, %{}, fn witness, acc ->
      Enum.reduce(witness.session.result.rows, acc, fn row, entities ->
        subject = get_in(row, ["_vkg", "subject"]) || synthetic_subject(row)

        annotated =
          Map.put(row, "_xaas", %{
            "query_id" => witness.query_id,
            "witness_id" => witness.id,
            "receipt_id" => witness.receipt_id
          })

        Map.update(entities, subject, [annotated], &[annotated | &1])
      end)
    end)
    |> Map.new(fn {subject, rows} -> {subject, Enum.reverse(rows)} end)
  end

  defp canonical_entities(entities) do
    entities
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {subject, rows} ->
      {subject, Enum.sort_by(rows, &:erlang.term_to_binary(&1, [:deterministic]))}
    end)
  end

  defp synthetic_subject(row) do
    "urn:xaas:vkg:row:" <>
      (row
       |> Map.delete("_vkg")
       |> :erlang.term_to_binary([:deterministic])
       |> then(&:crypto.hash(:sha256, &1))
       |> Base.encode16(case: :lower)
       |> binary_part(0, 24))
  end

  defp digest(term) do
    term
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp refusal(subject, detail, evidence) do
    {:error, Refusal.new(:REFUSED_XAAS_VKG_WORKSPACE, subject, detail, evidence)}
  end
end
