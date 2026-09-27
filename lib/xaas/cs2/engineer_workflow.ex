defmodule Xaas.CS2.EngineerWorkflow do
  @moduledoc """
  Engineer-facing CS2 composition.

  A2A evidence and Semantic-Jira execution candidates remain distinct inputs.
  The latter is projected into an authority-free execution package whose
  lease request is data only.
  """

  alias Xaas.CS2.{AshA2ABridge, FleetContract, SemanticJiraBridge}

  @spec from_a2a(map()) :: {:ok, map()} | {:error, term()}
  def from_a2a(packet), do: AshA2ABridge.from_a2a(packet)

  @spec from_a2a_batch([map()]) :: {:ok, [map()]} | {:error, term()}
  def from_a2a_batch(packets) when is_list(packets) do
    packets
    |> Enum.reduce_while({:ok, []}, fn packet, {:ok, acc} ->
      case from_a2a(packet) do
        {:ok, workflow} -> {:cont, {:ok, [workflow | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, workflows} -> {:ok, Enum.reverse(workflows)}
      error -> error
    end
  end

  def from_a2a_batch(_), do: {:error, :expected_packet_list}

  @spec from_semantic_candidate(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def from_semantic_candidate(candidate, provider) do
    with {:ok, package} <- SemanticJiraBridge.execution_package(candidate, provider) do
      {:ok,
       %{
         "kind" => "cs2.engineer_workflow",
         "contract" => FleetContract.contract(),
         "subject" => package["subject"],
         "source" => "semantic_jira",
         "execution_package" => package,
         "authority" => "NONE"
       }}
    end
  end
end
