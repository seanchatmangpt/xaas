defmodule Xaas.CS2.EngineerWorkflow do
  @moduledoc "Consumes the CS2 fleet contract as engineer-facing workflow data."

  alias Xaas.CS2.FleetContract

  def from_a2a(%{subject: subject} = packet) when subject == "https://chatman.ai/cs2#RFC-CS2-001" do
    FleetContract.engineer_workflow(packet)
  end

  def from_a2a_batch(packets) when is_list(packets), do: Enum.map(packets, &from_a2a/1)
end
