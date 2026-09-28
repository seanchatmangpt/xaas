defmodule Xaas.CS2.GeneratedFleetContract do
  @moduledoc """
  Canonical consumer projection for RFC-CS2-001.

  This module is intentionally data-only: it binds XaaS to the generated
  fleet contract without granting execution authority.
  """

  @subject "RFC-CS2-001"
  @campaign "CS2-CHICAGO"
  @producer "seanchatmangpt/ggen"
  @pack "cs2-fleet-contract"
  @upstream_consumer "ash_a2a"
  @work_id "CS2-WRK-013"

  @spec contract() :: map()
  def contract do
    %{
      subject: @subject,
      campaign: @campaign,
      producer: @producer,
      pack: @pack,
      consumer: "xaas",
      upstream_consumer: @upstream_consumer,
      work_id: @work_id,
      authority_ceiling: :construct,
      requires_exact_subject: true,
      requires_provenance: true,
      requires_receipt_replay: true
    }
  end

  @spec accepts?(map()) :: boolean()
  def accepts?(packet) when is_map(packet) do
    packet_subject = Map.get(packet, :subject) || Map.get(packet, "subject")
    packet_work = Map.get(packet, :work_id) || Map.get(packet, "work_id")
    packet_subject == @subject and packet_work in [@work_id, "CS2-WRK-012"]
  end

  def accepts?(_), do: false
end
