defmodule Xaas.Igniter.PackManifest do
  @moduledoc """
  One entry of the ggen_igniter pack manifest inventory: one pack with its
  profile and the counts its court surface carries (gates, verify actions,
  misfiled codes flagged by the refusals registry audit).
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Igniter,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    attribute :pack_name, :string do
      allow_nil?(false)
      public?(true)
      primary_key?(true)
      writable?(true)
    end

    attribute(:version, :string, allow_nil?: false, public?: true)
    attribute(:profile, :string, public?: true)
    attribute(:gate_count, :integer, allow_nil?: false, public?: true, default: 0)
    attribute(:verify_count, :integer, allow_nil?: false, public?: true, default: 0)
    attribute(:misfiled_count, :integer, allow_nil?: false, public?: true, default: 0)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_pack_name, [:pack_name], pre_check_with: Ash.DataLayer.Ets)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:pack_name, :version, :profile, :gate_count, :verify_count, :misfiled_count])
    end

    update :update do
      accept([:version, :profile, :gate_count, :verify_count, :misfiled_count])
      require_atomic?(false)
    end
  end
end
