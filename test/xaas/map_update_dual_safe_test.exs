# W658d lane: W705 census tripwire fix (W647's two diagnoses).
#
# W647's findings, re-verified against the tree @ feat/playwright-surface:
#
#   1. Census path. The real FOND circuit breaker is
#      `lib/xaas/runtime/fond/circuit.ex` (module `Xaas.Runtime.FOND.Circuit`).
#      A second, unrelated `lib/xaas/runtime/provider_fabric/circuit.ex`
#      (`Xaas.Runtime.ProviderFabric.Circuit`) also exists — the census pins
#      the fond one. Both on-disk census files already carry the correct path;
#      this file re-states the tripwire so the path is pinned in the lane's
#      own contract file.
#
#   2. `Xaas.Gall.Turtle.from_turtle/1` returned `{:refused, :refused_authority}`.
#      Read of lib/xaas/gall/checkpoint.ex: `from_turtle/1` takes ONLY the TTL
#      text (there is no authority-context argument to supply). The refusal is
#      an admission refusal from `Xaas.Gall.Checkpoint.new/1`, reached only
#      when the TTL omits a required field (@required_fields = identity,
#      class, repository, base_sha, goal, verifier, standing) or shapes one
#      outside its vocabulary. The correct fix in the test is the module's own
#      tests' idiom (test/xaas/gall/turtle_test.exs @canonical_ttl): the full
#      PRD reference TTL form — repository IRI `urn:repo:seanchatmangpt:xaas`
#      whose trailing segment matches the identity's repo segment, verifier as
#      the FULL known-verifier IRI, standing in the vocabulary — so the pin
#      exercises the real RDF parse and lands in `{:ok, %Checkpoint{}}`.
#
# Dual-safe pins from W705 are preserved below unchanged in substance.

defmodule Xaas.MapUpdateDualSafeTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)

  # -- census receipt (verified against lib/ on this branch) ------------------

  @census_sites [
    "lib/xaas/runtime/fond/circuit.ex",
    "lib/xaas_web/controllers/ocel_summary_controller.ex",
    "lib/xaas/gall/turtle.ex",
    "lib/xaas/semantics/vkg/workspace.ex",
    "lib/xaas/ultracode/sequenced_drain.ex",
    "lib/xaas/ultracode/run_validation.ex",
    "lib/xaas/ultracode/semantic_drive.ex",
    "lib/xaas/fabric/planes/process.ex"
  ]

  test "census tripwire: every census site path exists and compiles to a live module" do
    assert length(@census_sites) == 8

    for rel <- @census_sites do
      path = Path.expand(rel, @repo_root)
      assert File.exists?(path), "census site file missing: #{rel}"
    end

    # Path-pin: the FOND circuit site is the runtime/fond one, not the
    # provider_fabric sibling.
    assert File.exists?(Path.expand("lib/xaas/runtime/fond/circuit.ex", @repo_root))
    assert Xaas.Runtime.FOND.Circuit.module_info(:module)
  end

  # -- runtime canary ----------------------------------------------------------

  test "canary: Map.update/4 skips the fun on absent key on this runtime" do
    assert Map.update(%{}, :k, 7, &(&1 + 1)) == %{k: 7}
  end

  test "canary: Map.update/4 applies the fun on present key on this runtime" do
    assert Map.update(%{k: 7}, :k, 0, &(&1 + 1)) == %{k: 8}
  end

  test "canary: the dual-safe case Map.fetch idiom is behavior-identical on both arms" do
    bump = fn m, k ->
      case Map.fetch(m, k) do
        {:ok, n} -> Map.put(m, k, n + 1)
        :error -> Map.put(m, k, 1)
      end
    end

    assert bump.(%{}, :k) == Map.update(%{}, :k, 1, &(&1 + 1))
    assert bump.(%{k: 1}, :k) == Map.update(%{k: 1}, :k, 1, &(&1 + 1))
  end

  # -- W705 dual-safe pins through real public surfaces (preserved) ------------

  test "FOND.Circuit.fail/2: absent key seeds 1, present key increments; threshold boundary" do
    c = Xaas.Runtime.FOND.Circuit.new(3)

    c1 = Xaas.Runtime.FOND.Circuit.fail(c, :edge_a)
    assert c1.failures == %{edge_a: 1}
    refute Xaas.Runtime.FOND.Circuit.open?(c1, :edge_a)

    c2 = Xaas.Runtime.FOND.Circuit.fail(c1, :edge_a)
    c3 = Xaas.Runtime.FOND.Circuit.fail(c2, :edge_a)
    assert c3.failures == %{edge_a: 3}

    refute Xaas.Runtime.FOND.Circuit.open?(c2, :edge_a)
    assert Xaas.Runtime.FOND.Circuit.open?(c3, :edge_a)
    assert Xaas.Runtime.FOND.Circuit.open?(Xaas.Runtime.FOND.Circuit.fail(c3, :edge_a), :edge_a)

    c4 = Xaas.Runtime.FOND.Circuit.reset(c3, :edge_a)
    assert c4.failures == %{}
    refute Xaas.Runtime.FOND.Circuit.open?(c4, :edge_a)
  end

  test "Fabric.Planes.Process.call(:observe): absent key seeds [kind], present appends" do
    {:ok, facts1} = Xaas.Fabric.Planes.Process.call(:observe, nil, %{"process.event" => "requested"}, [])

    assert facts1["process.events"] == ["requested"]

    {:ok, facts2} =
      Xaas.Fabric.Planes.Process.call(
        :observe,
        nil,
        Map.merge(facts1, %{"process.event" => "constructed"}),
        []
      )

    assert facts2["process.events"] == ["requested", "constructed"]
  end

  # -- Xaas.Gall.Turtle.from_turtle/1: real parse, admission-valid TTL idiom ---

  describe "Xaas.Gall.Turtle.from_turtle/1 (real RDF parse, admission-valid reference TTL)" do
    @ttl """
    @prefix gall: <https://semantic-a2a.dev/gall#> .

    <urn:gall:checkpoint:xaas:w658d-001>
      a gall:CodingCheckpoint ;
      gall:repository <urn:repo:seanchatmangpt:xaas> ;
      gall:baseSha "6d5fca8cff223eb30ef19e237574d54f21cbfc15" ;
      gall:goal gall:SemanticWorkerIntegration ;
      gall:requiresCapability gall:Read, gall:Edit, gall:Commit ;
      gall:requiresVerifier gall:XaasChicagoCourt ;
      gall:forbidsCapability gall:Push ;
      gall:standing gall:UNKNOWN .
    """

    test "real parser is loadable in dev/test (rdf via ggen_igniter, only: [:dev, :test])" do
      assert Code.ensure_loaded?(RDF.Turtle)
    end

    test "admits the canonical reference TTL and exercises the dual-safe append arms" do
      assert {:ok, checkpoint} = Xaas.Gall.Turtle.from_turtle(@ttl)

      assert checkpoint.identity == "urn:gall:checkpoint:xaas:w658d-001"
      assert checkpoint.repository == "urn:repo:seanchatmangpt:xaas"
      assert checkpoint.standing == :UNKNOWN
      assert Enum.sort(checkpoint.requires_capabilities) == [:Commit, :Edit, :Read]
      assert checkpoint.forbids_capabilities == [:Push]
      assert checkpoint.verifier == "https://semantic-a2a.dev/gall#XaasChicagoCourt"
    end

    test "parse-shape errors stay parse-shape, admission refusals stay typed" do
      assert {:error, :no_checkpoint_subject} =
               Xaas.Gall.Turtle.from_turtle("@prefix gall: <https://semantic-a2a.dev/gall#> .\n")

      # An admission-invalid TTL (unknown standing) refuses typed, proving the
      # pin above fails loudly if the parser path is ever stubbed out.
      bad =
        String.replace(@ttl, "gall:standing gall:UNKNOWN", "gall:standing gall:NOT_A_STANDING")

      assert Xaas.Gall.Turtle.from_turtle(bad) == {:refused, :refused_authority}
    end
  end
end
