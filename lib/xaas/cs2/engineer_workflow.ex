defmodule Xaas.CS2.EngineerWorkflow do
  @moduledoc """
  Projects bounded CS2 fleet packets into XaaS engineer-workflow inputs.

  Projection is pure and authority-free. Consequential execution remains in
  the existing XaaS command/runtime boundary.
  """

  alias Xaas.CS2.GeneratedFleetContract

  @spec project(map()) :: {:ok, map()} | {:error, term()}
  def project(packet) when is_map(packet) do
    if GeneratedFleetContract.accepts?(packet) do
      {:ok,
       %{
         subject: value(packet, :subject),
         work_id: value(packet, :work_id),
         evidence: value(packet, :evidence, []),
         provenance: value(packet, :provenance, %{}),
         triage: value(packet, :triage, %{}),
         source_consumer: value(packet, :consumer, "ash_a2a"),
         target_consumer: "xaas",
         projection: "engineer-workflow",
         authority_ceiling: :construct
       }}
    else
      {:error, {:contract_mismatch, GeneratedFleetContract.contract()}}
    end
  end

  def project(_), do: {:error, :invalid_packet}

  defp value(packet, key, default \\ nil) do
    Map.get(packet, key, Map.get(packet, Atom.to_string(key), default))
  end
end
