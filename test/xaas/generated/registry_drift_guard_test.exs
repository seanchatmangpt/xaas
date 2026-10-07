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
#
# W852 extension (backlog item 1 of w849-generated-surface-census.md): the
# four PROVENANCE-ONLY surfaces are now pinned too. Each pin below is
# HAND-EDIT DETECTION ONLY — it proves the committed bytes are unchanged from
# the pinned state, not that the file conforms to its ontology source. Regen
# conformance remains the separate P2-2 CI leg. Keys are repo-relative paths
# (the new surfaces live outside lib/xaas/generated/).
defmodule Xaas.Generated.RegistryDriftGuardTest do
  use ExUnit.Case, async: true

  # Keys: repo-relative paths (pre-W852 entries kept under lib/xaas/generated/).
  @regen_commands %{
    "lib/xaas/generated/zcode_event_registry.ex" =>
      "mix ggen_igniter.sync --pack-dir priv/packs/xaas_zcode_ocel_pack --template priv/packs/xaas_zcode_ocel_pack/templates/zcode_event_registry.ex.eex --out lib/xaas/generated/zcode_event_registry.ex",
    "lib/xaas/generated/sa2a_bridge_contract.ex" =>
      "ggen-marketplace/sa2a-bridge-pack (ggen_igniter renderer)",
    "lib/xaas/generated/sa2a_bridge_edges.ex" =>
      "ggen-marketplace/sa2a-bridge-pack (ggen_igniter renderer)",
    "lib/xaas/generated/sa2a_mcp_descriptor.ex" =>
      "ggen-marketplace/sa2a-bridge-pack (ggen_igniter renderer)",
    "lib/xaas/generated/castle_bridge_contract.ex" =>
      "ggen-marketplace/xaas-castle-bridge-pack",
    "lib/xaas/generated/castle_bridge_edges.ex" =>
      "ggen-marketplace/xaas-castle-bridge-pack",
    # --- W852: provenance-only surfaces, hand-edit detection pins ---
    "lib/xaas_web/mcp_scope.ex" =>
      "ggen_igniter from priv/ggen_igniter/mcp_a2a/xaas-surface.ttl (moduledoc provenance; regen command not in pack-dir form — see W849 backlog item 3)",
    "lib/mix/tasks/xaas.library.manufacture.ex" =>
      "mix ggen_igniter.sync --pack-dir priv/packs/xaas_library_pack",
    "lib/xaas/generated/capital_census/facts.ex" =>
      "mix ggen_igniter.sync --pack-dir priv/ggen/ultracode-self-digest-pack --template templates/facts.ex.eex --yes",
    "lib/xaas/telemetry/ocel_envelope.ex" =>
      "mix ggen_igniter.sync --pack-dir priv/packs/xaas_telemetry_pack --template priv/packs/xaas_telemetry_pack/templates/ocel_envelope.ex.eex --out lib/xaas/telemetry/ocel_envelope.ex"
  }

  # Each sha256 is a hand-edit detection pin over the committed bytes at
  # HEAD a0723bf6 (W852). It does NOT certify ontology conformance.
  @expected_sha256 %{
    "lib/xaas/generated/zcode_event_registry.ex" =>
      "d185723654af3eca4c8f710752ce78f5e4ce4f123b34041bdc4448993ddef861",
    "lib/xaas/generated/sa2a_bridge_contract.ex" =>
      "a3ee8136858ccd6cda4c81fcba6becb39f785c0100670e9fd5759f8609b9f87b",
    "lib/xaas/generated/sa2a_bridge_edges.ex" =>
      "821faf64fdca5a089b2255e346458c367dc7b423ca669178713488fbb683df90",
    "lib/xaas/generated/sa2a_mcp_descriptor.ex" =>
      "dda0d8d0a6f70ffb2a585a3118f862cfe978563f5c39e5e4a8e41ce4aee52e41",
    "lib/xaas/generated/castle_bridge_contract.ex" =>
      "a22927259a6c0ac6304b560b8bf5596a591548c32bafcb4b3a828840c38872b1",
    "lib/xaas/generated/castle_bridge_edges.ex" =>
      "e711aed26e58b914183c198ca7b534feb5f4edc4f1737b8102758524e7362e71",
    # --- W852: provenance-only surfaces, hand-edit detection pins ---
    "lib/xaas_web/mcp_scope.ex" =>
      "51d9d7cbf83d5aa7ef91f727e3a1d8283ed8e51047fe7867637ee85ca99b3780",
    "lib/mix/tasks/xaas.library.manufacture.ex" =>
      "5796cae051757de949bc543f20564809f0e453dd4916eeac7e94beb71c56eb21",
    "lib/xaas/generated/capital_census/facts.ex" =>
      "be12c29a29b2e32335de0a46757574f6575e4614825c1936e1e200ff928070c4",
    "lib/xaas/telemetry/ocel_envelope.ex" =>
      "16757701865686d1087879c4f4745e83e3c0f9a3364bce03e052f8762a181e77"
  }

  @tag :registry_drift_guard
  test "every generated registry file matches its pinned sha256" do
    assert MapSet.new(Map.keys(@expected_sha256)) ==
             MapSet.new(Map.keys(@regen_commands))

    for {rel_path, expected} <- @expected_sha256 do
      path = Path.expand(rel_path, File.cwd!())

      assert File.exists?(path), "missing generated file: #{rel_path}"

      actual =
        path
        |> File.read!()
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)

      assert actual == expected, """
      GENERATED-REGISTRY DRIFT: #{rel_path}

        expected sha256: #{expected}
        actual   sha256: #{actual}

      This pin is hand-edit detection only — it does not prove ontology-source
      conformance (that is the separate CI/regen leg, P2-2). If this change is
      a legitimate regeneration, re-pin @expected_sha256 with a receipt note.
      Otherwise restore the file. Regen:
        #{@regen_commands[rel_path]}
      """
    end
  end
end
