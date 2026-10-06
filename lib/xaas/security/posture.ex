defmodule Xaas.Security.Posture do
  @moduledoc """
  Aggregate security posture for one repo scan: severity counts,
  disposition count, and the green flag (green only when every finding
  carries a non-pending disposition). ETS-backed.
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Security,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:repo, :string, allow_nil?: false, public?: true)
    attribute(:scan_date, :utc_datetime, allow_nil?: true, public?: true)
    attribute(:total_findings, :integer, allow_nil?: false, public?: true)
    attribute(:critical_count, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:high_count, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:medium_count, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:low_count, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:info_count, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:dispositioned_count, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:green, :boolean, allow_nil?: false, default: false, public?: true)
    create_timestamp(:inserted_at)
  end

  actions do
    defaults([:read])

    create :register do
      accept([
        :repo,
        :scan_date,
        :total_findings,
        :critical_count,
        :high_count,
        :medium_count,
        :low_count,
        :info_count,
        :dispositioned_count,
        :green
      ])
    end
  end
end
