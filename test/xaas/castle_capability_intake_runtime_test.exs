defmodule Xaas.Castle.CapabilityIntakeRuntimeTest do
  use ExUnit.Case, async: true

  alias Xaas.Castle.CapabilityIntake

  test "registry exposes exact donors without consequence authority" do
    assert CapabilityIntake.projection_source() ==
             "seanchatmangpt/ggen-ecosystem@50fdfa20c84205a80c6eb94e916cffbedc4b816e"

    assert CapabilityIntake.owner_capability() == "RUNTIME_EXISTENCE"
    assert CapabilityIntake.authority_ceiling() == :construct
    assert length(CapabilityIntake.donors()) == 4

    assert {:ok, donor} = CapabilityIntake.fetch("seanchatmangpt/dteam")
    assert donor.sha == "5c00d757ebc614e1db1dd0d564dd0c34896d57a0"
    refute CapabilityIntake.consequence_authority?(donor.repository)

    assert {:error, :unknown_castle_capability_donor} =
             CapabilityIntake.fetch("seanchatmangpt/unknown")

    contract = Xaas.Castle.contract_identity()
    assert contract.capability_projection_source == CapabilityIntake.projection_source()
    assert contract.xaas_runtime_capability == "RUNTIME_EXISTENCE"
    assert contract.capability_authority_ceiling == :construct
  end
end
