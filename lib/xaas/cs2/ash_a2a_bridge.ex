defmodule XaaS.CS2.AshA2ABridge do
  alias XaaS.CS2.Contract
  def from_a2a(%{subject: "RFC-CS2-001", evidence: evidence} = packet) do
    Contract.engineer_packet(evidence, Map.get(packet, :provenance, %{}))
  end
  def from_a2a(packet), do: {:error, {:unsupported_cs2_packet, packet}}
end
