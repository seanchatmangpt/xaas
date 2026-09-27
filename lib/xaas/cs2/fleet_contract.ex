defmodule Xaas.CS2.FleetContract do
  @moduledoc """
  XaaS projection of the canonical RFC-CS2-001 fleet contract.

  This module is a representation boundary only. It packages admitted CS2
  evidence for engineer-facing consumers and never creates runtime authority.
  """

  @subject "https://chatman.ai/cs2#RFC-CS2-001"
  @contract "cs2-fleet-contract/26.9.27"

  def subject, do: @subject
  def contract, do: @contract

  @spec engineer_workflow(map()) :: {:ok, map()} | {:error, term()}
  def engineer_workflow(packet) when is_map(packet) do
    packet = strings(packet)

    if packet["subject"] == @subject do
      {:ok,
       %{
         "kind" => "cs2.engineer_workflow",
         "contract" => @contract,
         "subject" => @subject,
         "source" => packet["source"] || "semantic_jira",
         "evidence" => packet,
         "authority" => "NONE"
       }}
    else
      {:error, {:unsupported_cs2_subject, packet["subject"]}}
    end
  end

  def engineer_workflow(packet), do: {:error, {:unsupported_cs2_packet, packet}}

  defp strings(v) when is_map(v) and not is_struct(v),
    do: Map.new(v, fn {k, x} -> {to_string(k), strings(x)} end)

  defp strings(v) when is_list(v), do: Enum.map(v, &strings/1)
  defp strings(v), do: v
end
