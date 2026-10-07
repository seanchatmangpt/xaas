defmodule Xaas.Ultracode.RemoteRelayContractShaTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Byte-exact cross-repo pin for the xaas-remote-relay contract (W704).

  zcode-cli carries the same fixture at `test/fixtures/xaas-remote-relay.contract.json`
  and its own suite recomputes the digest (W615). XaaS's
  `remote_relay_test.exs` asserted the contract's structure but never its
  bytes — structural asserts pass on any contract_version-1 mutation that
  keeps the parsed shape, which is exactly the cross-repo drift channel the
  gall-work pin (`test/xaas/zcode_plugin/gall_work_contract_test.exs`)
  already closes for the sibling contract. This court closes the same channel
  for the relay contract: either side changing bytes without a same-wave
  re-pin in BOTH repos fails here and in zcode-cli.
  """

  @relay_contract_path "priv/ultracode/remote-relay.contract.json"
  @zcode_fixture "../../../../zcode-cli/test/fixtures/xaas-remote-relay.contract.json"

  # Digest recomputed this session with `shasum -a 256` over the fixture and
  # confirmed byte-identical to the zcode-cli fixture (76ff551c...).
  @relay_contract_sha256 "76ff551c16cea5afb40b385ecee9ab7462ce1d73bee47655c0e0c63dc0a33f89"

  test "the relay contract fixture is byte-identical to the pinned cross-repo digest" do
    assert File.exists?(@relay_contract_path),
           "the relay contract fixture is missing from priv/ultracode"

    text = File.read!(@relay_contract_path)
    assert :crypto.hash(:sha256, text) |> Base.encode16(case: :lower) == @relay_contract_sha256
  end

  # The cross-repo byte-identity mirror of the gall-work court: when the
  # canonical zcode-cli checkout is present next to this one, the two
  # fixtures must be byte-identical. Compile-time existence check keeps the
  # skip typed (carries its reason) per the typed-skip discipline.
  @zcode_fixture_present File.exists?(Path.expand(@zcode_fixture, __DIR__))

  @tag skip:
         if(@zcode_fixture_present, do: false,
           else: "canonical zcode-cli checkout not present at ../zcode-cli"
         )
  test "the fixture is byte-identical to zcode-cli's test fixture" do
    assert File.read!(@relay_contract_path) ==
             File.read!(Path.expand(@zcode_fixture, __DIR__))
  end

  test "the pinned digest belongs to contract xaas-remote-relay version 1" do
    contract = @relay_contract_path |> File.read!() |> Jason.decode!()

    assert contract["contract"] == "xaas-remote-relay"
    assert contract["contract_version"] == 1
  end
end
