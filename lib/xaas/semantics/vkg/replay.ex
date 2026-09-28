defmodule Xaas.Semantics.VKG.Replay do
  @moduledoc """
  XaaS replay boundary for canonical VKG witnesses and workspaces.

  Replay delegates semantic result verification to AshR2RML and verifies the
  XaaS application envelope separately. No reconstructed evidence is promoted
  to source authority.
  """

  alias AshR2RML.Refusal
  alias AshR2RML.VKG.{Replay, Serializer}
  alias Xaas.Semantics.VKG.{Witness, Workspace}

  @spec witness(Witness.t()) :: {:ok, map()} | {:error, Refusal.t()}
  def witness(%Witness{} = witness) do
    with :ok <- Witness.verify(witness),
         {:ok, replay} <- Replay.compare(witness.session.receipt, witness.session.result) do
      {:ok,
       Map.merge(replay, %{
         witness_id: witness.id,
         query_id: witness.query_id,
         query_sha256: witness.query_sha256,
         authority: :NONE
       })}
    end
  end

  @spec workspace(Workspace.t()) :: {:ok, map()} | {:error, Refusal.t()}
  def workspace(%Workspace{} = workspace) do
    with :ok <- Workspace.verify(workspace),
         {:ok, witness_receipts} <- replay_all(workspace.witnesses) do
      {:ok,
       %{
         workspace_id: workspace.id,
         workspace_sha256: workspace.sha256,
         witness_count: length(workspace.witnesses),
         witness_replays: witness_receipts,
         authority: :NONE,
         deterministic?: true
       }}
    end
  end

  @spec serialized_witness(Witness.t()) :: {:ok, map()} | {:error, Refusal.t()}
  def serialized_witness(%Witness{} = witness) do
    with :ok <- Witness.verify(witness),
         encoded <- Serializer.encode_session!(witness.session),
         {:ok, decoded} <- Jason.decode(encoded),
         result_sha when is_binary(result_sha) <- get_in(decoded, ["result", "sha256"]),
         receipt_result_sha when is_binary(receipt_result_sha) <-
           get_in(decoded, ["receipt", "result_sha256"]),
         true <- result_sha == witness.result_sha256,
         true <- receipt_result_sha == witness.result_sha256 do
      {:ok,
       %{
         witness_id: witness.id,
         encoded_sha256: sha256(encoded),
         result_sha256: result_sha,
         deterministic?: true
       }}
    else
      {:error, %Jason.DecodeError{} = error} ->
        refusal(:serialization, "canonical VKG session JSON did not decode", %{
          error: Exception.message(error)
        })

      _ ->
        refusal(
          :serialization,
          "serialized VKG witness does not preserve result identity",
          %{witness_id: witness.id}
        )
    end
  end

  defp replay_all(witnesses) do
    witnesses
    |> Enum.reduce_while({:ok, []}, fn witness, {:ok, acc} ->
      case witness(witness) do
        {:ok, replay} -> {:cont, {:ok, [replay | acc]}}
        {:error, refusal} -> {:halt, {:error, refusal}}
      end
    end)
    |> case do
      {:ok, replays} -> {:ok, Enum.reverse(replays)}
      error -> error
    end
  end

  defp sha256(bytes) do
    :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
  end

  defp refusal(subject, detail, evidence) do
    {:error, Refusal.new(:REFUSED_XAAS_VKG_REPLAY, subject, detail, evidence)}
  end
end
