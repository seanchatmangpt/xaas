defmodule Xaas.CS2.AshA2ABridge do
  @moduledoc """
  Normalizes an Ash/A2A packet into the canonical CS2 engineer workflow.

  This replaces the earlier parallel `XaaS.CS2.*` namespace fragment with
  the repository's real `Xaas.*` namespace and preserves the full subject
  IRI used by the fleet contract.
  """

  alias Xaas.CS2.FleetContract

  @spec from_a2a(map()) :: {:ok, map()} | {:error, term()}
  def from_a2a(packet) when is_map(packet) do
    packet
    |> strings()
    |> normalize_subject()
    |> FleetContract.engineer_workflow()
  end

  def from_a2a(packet), do: {:error, {:unsupported_cs2_packet, packet}}

  defp normalize_subject(%{"subject" => "RFC-CS2-001"} = packet),
    do: Map.put(packet, "subject", FleetContract.subject())

  defp normalize_subject(packet), do: packet

  defp strings(v) when is_map(v) and not is_struct(v),
    do: Map.new(v, fn {k, x} -> {to_string(k), strings(x)} end)

  defp strings(v) when is_list(v), do: Enum.map(v, &strings/1)
  defp strings(v), do: v
end
