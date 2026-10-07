# Lane W350 — generated-registry drift gate (_CLOSURE_PLAN.md §1 row 17).
#
# Digest form (weaker than in-test regeneration): the named generators for
# these files are external ggen-marketplace packs / ggen_igniter syncs, not
# safely invocable in-test (external toolchain + pack dirs outside the repo).
# A sha256 pin detects any hand-edit or accidental regeneration drift in the
# committed file, but does NOT prove the file matches its ontology source —
# that check remains a CI/regen leg (coordinator work, P2-2).
#
# A legit regeneration that changes content must update @expected_sha256 ONCE
# with a receipt note. Failure message names the regen command per file.
defmodule Xaas.Generated.RegistryDriftGuardTest do
  use ExUnit.Case, async: true

  @regen_commands %{
    "zcode_event_registry.ex" =>
      "mix ggen_igniter.sync --pack-dir priv/packs/xaas_zcode_ocel_pack --template priv/packs/xaas_zcode_ocel_pack/templates/zcode_event_registry.ex.eex --out lib/xaas/generated/zcode_event_registry.ex",
    "sa2a_bridge_contract.ex" => "ggen-marketplace/sa2a-bridge-pack (ggen_igniter renderer)",
    "sa2a_bridge_edges.ex" => "ggen-marketplace/sa2a-bridge-pack (ggen_igniter renderer)",
    "sa2a_mcp_descriptor.ex" => "ggen-marketplace/sa2a-bridge-pack (ggen_igniter renderer)",
    "castle_bridge_contract.ex" => "ggen-marketplace/xaas-castle-bridge-pack",
    "castle_bridge_edges.ex" => "ggen-marketplace/xaas-castle-bridge-pack"
  }

  @expected_sha256 %{
    "zcode_event_registry.ex" =>
      "d185723654af3eca4c8f710752ce78f5e4ce4f123b34041bdc4448993ddef861",
    "sa2a_bridge_contract.ex" =>
      "a3ee8136858ccd6cda4c81fcba6becb39f785c0100670e9fd5759f8609b9f87b",
    "sa2a_bridge_edges.ex" => "821faf64fdca5a089b2255e346458c367dc7b423ca669178713488fbb683df90",
    "sa2a_mcp_descriptor.ex" =>
      "dda0d8d0a6f70ffb2a585a3118f862cfe978563f5c39e5e4a8e41ce4aee52e41",
    "castle_bridge_contract.ex" =>
      "a22927259a6c0ac6304b560b8bf5596a591548c32bafcb4b3a828840c38872b1",
    "castle_bridge_edges.ex" => "e711aed26e58b914183c198ca7b534feb5f4edc4f1737b8102758524e7362e71"
  }

  @tag :registry_drift_guard
  test "every generated registry file matches its pinned sha256" do
    assert MapSet.new(Map.keys(@expected_sha256)) ==
             MapSet.new(Map.keys(@regen_commands))

    for {file, expected} <- @expected_sha256 do
      path = Path.expand("lib/xaas/generated/#{file}", File.cwd!())

      assert File.exists?(path), "missing generated file: #{file}"

      actual =
        path
        |> File.read!()
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)

      assert actual == expected, """
      GENERATED-REGISTRY DRIFT: lib/xaas/generated/#{file}

        expected sha256: #{expected}
        actual   sha256: #{actual}

      If this change is a legitimate regeneration, re-pin @expected_sha256
      with a receipt note. Otherwise restore the file. Regen:
        #{@regen_commands[file]}
      """
    end
  end
end
