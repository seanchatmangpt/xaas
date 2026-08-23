defmodule Xaas.Semantics.AshR2RMLTest.GoodResource do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Billing,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "r2rml_good_resources"
    repo Xaas.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :amount, :decimal do
      allow_nil? false
      public? true
    end

    attribute :occurred_at, :utc_datetime do
      allow_nil? false
      public? true
    end
  end
end

defmodule Xaas.Semantics.AshR2RMLTest.UnsupportedResource do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Billing,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "r2rml_unsupported_resources"
    repo Xaas.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :payload, :map do
      allow_nil? false
      public? true
    end
  end
end

defmodule Xaas.Semantics.AshR2RMLTest do
  use ExUnit.Case, async: true

  alias AshR2RML.Mapping
  alias AshR2RML.Mapping.{Bundle, Resource, SubjectMap}
  alias Xaas.Semantics.{R2RML, Registry}

  alias Xaas.Semantics.AshR2RMLTest.{GoodResource, UnsupportedResource}

  test "XAAS public ontology projection compiles into canonical ash_r2rml IR" do
    assert {:ok, %Resource{} = mapping} = R2RML.mapping(GoodResource)

    projection = Registry.projection(GoodResource)

    assert mapping.class_iris == projection.classes
    assert mapping.logical_table.table_name == "r2rml_good_resources"
    assert mapping.metadata.source == :xaas_public_ontology_registry

    assert %SubjectMap{
             strategy: :template,
             term_type: :iri,
             value: subject_template
           } = mapping.subject_map

    assert subject_template ==
             "urn:xaas:resource:Xaas.Semantics.AshR2RMLTest.GoodResource/{id}"

    mapped_attributes =
      mapping.predicate_object_maps
      |> Enum.map(& &1.attribute)
      |> Enum.sort_by(&to_string/1)

    projected_attributes =
      projection.attributes
      |> Enum.map(& &1.ash_name)
      |> Enum.sort_by(&to_string/1)

    assert mapped_attributes == projected_attributes
    assert :ok = Mapping.validate(mapping)
  end

  test "resource-level mapping and hash contract is deterministic" do
    assert {:ok, first} = GoodResource.r2rml_mapping()
    assert {:ok, second} = GoodResource.r2rml_mapping()

    assert first == second
    assert GoodResource.r2rml_mapping!() == first

    hash = GoodResource.r2rml_mapping_hash()
    assert hash == R2RML.hash(first)
    assert byte_size(hash) == 64
    assert hash =~ ~r/^[0-9a-f]{64}$/
  end

  test "bundle and R2RML rendering preserve one normalized admitted subject" do
    assert {:ok, %Bundle{resources: [mapping]} = bundle} = R2RML.bundle(GoodResource)
    assert mapping.ash_resource == GoodResource
    assert :ok = Mapping.validate(bundle)

    assert {:ok, turtle} = R2RML.render(GoodResource)
    assert turtle =~ "TriplesMap"
    assert turtle =~ "r2rml_good_resources"
    assert turtle =~ "urn:xaas:resource:Xaas.Semantics.AshR2RMLTest.GoodResource/{id}"

    for class <- mapping.class_iris do
      assert turtle =~ class
    end
  end

  test "unsupported Ash datatype is refused instead of silently stringified" do
    assert {:error, %AshR2RML.Refusal{code: :UNSUPPORTED_ASH_TYPE}} =
             R2RML.mapping(UnsupportedResource)
  end

  test "audit preserves admitted and refused standing independently" do
    audit = R2RML.audit([UnsupportedResource, GoodResource])

    assert [%{resource: GoodResource, mapping_hash: hash, mapping_identity: identity}] =
             audit.admitted

    assert byte_size(hash) == 64
    assert String.starts_with?(identity, "urn:ash-r2ml:triples-map:")

    assert [
             %{
               resource: UnsupportedResource,
               reason: %AshR2RML.Refusal{code: :UNSUPPORTED_ASH_TYPE}
             }
           ] = audit.refused
  end
end
