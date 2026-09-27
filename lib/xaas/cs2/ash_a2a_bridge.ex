defmodule Xaas.CS2.AshA2ABridge do
  @moduledoc """
  API bridge from AshA2A CS2 evidence/triage packets to XaaS workflow data.
  """

  alias Xaas.CS2.EngineerWorkflow

  @spec ingest(map()) :: {:ok, map()} | {:error, term()}
  def ingest(packet) do
    with {:ok, workflow} <- EngineerWorkflow.project(packet) do
      {:ok,
       Map.merge(workflow, %{
         bridge: "ash_a2a->xaas",
         consequence: :none,
         selected_action: nil
       })}
    end
  end

  @spec ingest_many([map()]) :: %{accepted: [map()], refused: [term()]}
  def ingest_many(packets) when is_list(packets) do
    Enum.reduce(packets, %{accepted: [], refused: []}, fn packet, acc ->
      case ingest(packet) do
        {:ok, projected} -> %{acc | accepted: [projected | acc.accepted]}
        {:error, reason} -> %{acc | refused: [reason | acc.refused]}
      end
    end)
    |> then(fn acc ->
      %{accepted: Enum.reverse(acc.accepted), refused: Enum.reverse(acc.refused)}
    end)
  end
end
