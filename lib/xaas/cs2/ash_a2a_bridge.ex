defmodule XaaS.CS2.AshA2ABridge do
  alias XaaS.CS2.GeneratedFleetContract, as: Contract
  alias XaaS.CS2.EngineerWorkflow
  @ash_consumer "https://chatman.ai/cs2#ash-a2a"
  @ash_work_id "CS2-WRK-012"

  def ingest(packet) when is_map(packet) do
    with {:ok, bound} <- Contract.admit_envelope(packet),
         :ok <- require_upstream(packet) do
      {:ok, EngineerWorkflow.from_a2a(bound)}
    end
  end
  def ingest(_), do: {:error, :invalid_packet}

  defp require_upstream(packet) do
    consumer = Map.get(packet, :consumer) || Map.get(packet, "consumer")
    work = Map.get(packet, :work_id) || Map.get(packet, "work_id")
    if consumer == @ash_consumer and work == @ash_work_id,
      do: :ok,
      else: {:error, :unexpected_upstream_consumer}
  end
end
