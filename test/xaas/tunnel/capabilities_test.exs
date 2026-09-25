defmodule Xaas.Tunnel.CapabilitiesTest do
  use ExUnit.Case, async: true

  alias Xaas.Tunnel.Capabilities

  test "exactly three admitted verbs" do
    assert Capabilities.allowlist() == ~w(fabric.probe run.submit epoch.receipts)
    for verb <- Capabilities.allowlist(), do: assert(Capabilities.admit(verb) == :ok)
  end

  test "actuate is refused by authority ceiling" do
    assert Capabilities.admit("actuate") == {:refused, {:authority_ceiling, "actuate"}}
  end

  test "unknown and non-binary verbs fail closed" do
    assert Capabilities.admit("claim_next") ==
             {:refused, {:capability_not_admitted, "claim_next"}}

    assert Capabilities.admit("") == {:refused, {:capability_not_admitted, ""}}
    assert {:refused, {:capability_not_admitted, _}} = Capabilities.admit(:fabric_probe)
    assert {:refused, {:capability_not_admitted, _}} = Capabilities.admit(nil)
  end

  test "admit_set intersects with the allowlist and types every refusal" do
    assert Capabilities.admit_set(~w(run.submit actuate fabric.probe close_candidate run.submit)) ==
             %{
               admitted: ~w(run.submit fabric.probe),
               refused: [
                 {"actuate", :authority_ceiling},
                 {"close_candidate", :capability_not_admitted}
               ]
             }

    assert Capabilities.admit_set("fabric.probe") == %{admitted: [], refused: []}
    assert Capabilities.admit_set(nil) == %{admitted: [], refused: []}
  end
end
