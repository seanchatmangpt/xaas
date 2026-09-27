defmodule Xaas.CS2.FleetContract do
  @moduledoc """
  XaaS projection of the canonical RFC-CS2-001 fleet contract.
  """

  @subject "https://chatman.ai/cs2#RFC-CS2-001"
  @contract "cs2-fleet-contract/26.9.26"

  def subject, do: @subject
  def contract, do: @contract

  def engineer_workflow(%{subject: @subject} = packet) do
    %{
      kind: "cs2.engineer_workflow",
      contract: @contract,
      subject: @subject,
      source: "ash_a2a",
      evidence: packet
    }
  end
end
