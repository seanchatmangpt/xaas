defmodule Xaas.Semantics.OntopMappingTest do
  @moduledoc """
  Chicago-style qualification of `Xaas.Semantics.OntopMapping` -- the real generation
  path from every admitted `Xaas.Resource`'s R2RML mapping to real W3C R2RML Turtle
  via `AshR2RML.R2RML.render/1`.

  Modeled on `ash_r2rml`'s `w3c_compliance_test.exs` (exact rendered-Turtle substring
  assertions against real spec literals) and `parity_and_ggen_test.exs` (differential
  comparison of two independently-produced artifacts describing the same resource).
  No mocking: this exercises the real renderer over the real, compiled `Xaas.*`
  resource modules.
  """

  use ExUnit.Case, async: true

  alias Xaas.Marketplace.Provider

  test "every currently-mappable Xaas.Resource is included with zero failures" do
    {bundle, failures} = Xaas.Semantics.OntopMapping.bundle()

    assert failures == []
    assert length(bundle.resources) == length(Xaas.Semantics.OntopMapping.resources())
    assert length(bundle.resources) > 60
  end

  test "render/0 produces real W3C R2RML Turtle containing Provider's real triples map" do
    assert {:ok, turtle, []} = Xaas.Semantics.OntopMapping.render()

    assert turtle =~ "@prefix rr: <http://www.w3.org/ns/r2rml#> ."
    assert turtle =~ "rr:tableName \"marketplace_providers\""
    assert turtle =~ "rr:template \"{id}\""
    assert turtle =~ "rr:predicate <https://schema.org/name>"
    assert turtle =~ "rr:class <https://schema.org/Organization>"
  end

  test "render/0 is deterministic across two independent calls" do
    assert {:ok, turtle_a, []} = Xaas.Semantics.OntopMapping.render()
    assert {:ok, turtle_b, []} = Xaas.Semantics.OntopMapping.render()

    assert turtle_a == turtle_b
  end

  test "write!/0 writes a real file whose content matches render/0's real output" do
    assert {:ok, path} = Xaas.Semantics.OntopMapping.write!()
    assert {:ok, expected_turtle, []} = Xaas.Semantics.OntopMapping.render()

    assert File.read!(path) == expected_turtle
  end

  test "the generated mapping's Provider triples map matches Xaas.Semantics.Registry.r2rml_mapping/1's own admitted mapping" do
    assert {:ok, registry_mapping} = Xaas.Semantics.Registry.r2rml_mapping(Provider)
    {bundle, []} = Xaas.Semantics.OntopMapping.bundle()

    bundled_mapping = Enum.find(bundle.resources, &(&1.ash_resource == Provider))

    refute is_nil(bundled_mapping)
    assert bundled_mapping.logical_table == registry_mapping.logical_table
    assert bundled_mapping.subject_map == registry_mapping.subject_map
    assert Enum.sort(bundled_mapping.predicate_object_maps) == Enum.sort(registry_mapping.predicate_object_maps)
  end
end
