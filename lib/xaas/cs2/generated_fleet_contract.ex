defmodule XaaS.CS2.GeneratedFleetContract do
  @moduledoc "Generated-contract consumer surface for RFC-CS2-001."
  @schema "https://chatman.ai/cs2/fleet-contract/v1"
  @subject "https://chatman.ai/cs2#RFC-CS2-001"
  @authority_ceiling "CONSTRUCT"
  @consumer "https://chatman.ai/cs2#xaas"
  @work_id "CS2-WRK-013"
  @contract %{schema: @schema, subject: @subject, authority_ceiling: @authority_ceiling,
    consumer: @consumer, work_id: @work_id, target_repository: "seanchatmangpt/xaas",
    target_path: "lib/xaas/cs2/generated_fleet_contract.ex", artifact_kind: "ElixirModule",
    contract_version: "v1"}

  def contract, do: @contract
  def subject, do: @subject
  def authority_ceiling, do: @authority_ceiling
  def consumer, do: @consumer
  def work_id, do: @work_id

  def admit_envelope(packet) when is_map(packet) do
    subject = Map.get(packet, :subject) || Map.get(packet, "subject")
    ceiling = Map.get(packet, :authority_ceiling) || Map.get(packet, "authority_ceiling")
    if subject == @subject and ceiling == @authority_ceiling,
      do: {:ok, Map.merge(@contract, %{upstream: packet})},
      else: {:error, :fleet_contract_mismatch}
  end
end
