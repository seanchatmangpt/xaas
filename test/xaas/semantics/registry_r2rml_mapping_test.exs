defmodule Xaas.Semantics.RegistryR2rmlMappingTest do
  @moduledoc """
  Chicago-style qualification of `Xaas.Semantics.Registry.r2rml_mapping/1`'s real
  delegation into the published `ash_r2rml` library.

  Modeled on `ash_r2rml`'s own `ash_r2rml_resource_test.exs` pattern: assert on the
  actual shape of the returned `AshR2RML.Mapping.Resource` struct (logical table,
  subject map, predicate/object maps) rather than only on pass/fail admission --
  the admission-only pattern (`Xaas.ActuationTest`'s `admit/1` calls) leaves the
  mapping's actual structural content unverified.
  """

  use ExUnit.Case, async: true

  alias AshR2RML.Mapping.{LogicalTable, PredicateObjectMap, SubjectMap}
  alias Xaas.Marketplace.Provider
  alias Xaas.Semantics.Registry

  test "Provider's real R2RML mapping resolves a real logical table bound to its Postgres table" do
    assert {:ok, mapping} = Registry.r2rml_mapping(Provider)

    assert %LogicalTable{table_name: "marketplace_providers"} = mapping.logical_table
    assert mapping.ash_resource == Provider
  end

  test "Provider's real R2RML mapping has a template subject map keyed on the real primary key" do
    assert {:ok, mapping} = Registry.r2rml_mapping(Provider)

    assert %SubjectMap{strategy: :template, value: "{id}", term_type: :iri} = mapping.subject_map
  end

  test "Provider's real R2RML mapping has one predicate-object map per real Ash attribute, each column-backed" do
    assert {:ok, mapping} = Registry.r2rml_mapping(Provider)

    real_attribute_names =
      Provider
      |> Ash.Resource.Info.attributes()
      |> Enum.map(& &1.name)
      |> Enum.sort()

    mapped_attribute_names =
      mapping.predicate_object_maps
      |> Enum.map(& &1.attribute)
      |> Enum.sort()

    assert mapped_attribute_names == real_attribute_names

    name_map = %PredicateObjectMap{
      attribute: :name,
      predicate_iri: "https://schema.org/name",
      object_map: %AshR2RML.Mapping.ObjectMap{strategy: :column, value: "name"}
    }

    assert name_map in mapping.predicate_object_maps
  end

  test "the real mapping's class IRIs match the registry's own projection classes" do
    assert {:ok, mapping} = Registry.r2rml_mapping(Provider)
    projection = Provider.ontology_projection!()

    assert Enum.sort(mapping.class_iris) == Enum.sort(projection.classes)
  end

  test "AshR2RML.Mapping.validate/1 accepts the real normalized mapping" do
    assert {:ok, mapping} = Registry.r2rml_mapping(Provider)
    assert :ok = AshR2RML.Mapping.validate(mapping)
  end
end
