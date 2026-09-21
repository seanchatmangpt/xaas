defmodule Xaas.Semantics.R2RML do
  @moduledoc """
  Deterministic adapter from XAAS's admitted public-ontology projection into
  `ash_r2rml`'s canonical mapping IR.

  XAAS keeps `Xaas.Semantics.Registry` as the admission boundary for public
  classes and predicates. `ash_r2rml` owns the relational/RDF correspondence:
  table and column introspection, datatype admission, normalized mapping IR,
  R2RML validation, serialization, dependency closure, and read-only SPARQL
  observation planning.

  This module is CONSTRUCT/OBSERVE-only. Rendering R2RML or querying a semantic
  projection never grants actuation authority and never mutates PostgreSQL or an
  external RDF/OBDA system.
  """

  alias AshR2RML.Datatype.Registry, as: DatatypeRegistry
  alias AshR2RML.Introspection
  alias AshR2RML.Mapping

  alias AshR2RML.Mapping.{
    Bundle,
    ObjectMap,
    PredicateObjectMap,
    ReferenceObjectMap,
    Resource,
    SubjectMap
  }

  alias AshR2RML.Refusal
  alias Xaas.Semantics.Registry, as: OntologyRegistry

  @subject_prefix "urn:xaas:resource:"

  @doc "Compile one Ash resource into ash_r2rml's canonical mapping IR."
  @spec mapping(module()) :: {:ok, Resource.t()} | {:error, Refusal.t() | [Refusal.t()] | term()}
  def mapping(resource) when is_atom(resource) do
    with {:ok, projection} <- OntologyRegistry.admit(resource),
         {:ok, logical_table} <- Introspection.logical_table(resource),
         {:ok, subject_map} <- subject_map(resource),
         {:ok, predicate_object_maps} <- predicate_object_maps(resource, projection.attributes),
         {:ok, reference_object_maps} <- reference_object_maps(resource, projection.relationships) do
      attribute_columns =
        resource
        |> Ash.Resource.Info.attributes()
        |> Map.new(fn attribute ->
          {attribute.name, to_string(attribute.source || attribute.name)}
        end)

      mapping =
        %Resource{
          ash_resource: resource,
          class_iris: projection.classes,
          logical_table: logical_table,
          subject_map: subject_map,
          predicate_object_maps: predicate_object_maps,
          reference_object_maps: reference_object_maps,
          identities: Introspection.identities(resource),
          metadata: %{
            attribute_columns: attribute_columns,
            data_layer: Ash.Resource.Info.data_layer(resource),
            source: :xaas_public_ontology_registry
          }
        }
        |> Mapping.normalize()

      case Mapping.validate(mapping) do
        :ok -> {:ok, mapping}
        {:error, refusals} -> {:error, refusals}
      end
    end
  rescue
    error ->
      {:error,
       Refusal.new(
         :REFUSED_UNPROVEN_EQUIVALENCE,
         resource,
         "XAAS to ash_r2rml projection raised",
         %{exception: Exception.message(error)}
       )}
  end

  @doc "Build and validate a dependency-closed mapping bundle."
  @spec bundle(module() | [module()]) :: {:ok, Bundle.t()} | {:error, term()}
  def bundle(resources) do
    resources
    |> List.wrap()
    |> do_bundle(MapSet.new(), [])
  end

  @doc "Render standards-valid R2RML Turtle for a dependency-closed resource set."
  @spec render(module() | [module()]) :: {:ok, String.t()} | {:error, term()}
  def render(resources) do
    with {:ok, bundle} <- bundle(resources),
         :ok <- Mapping.validate(bundle),
         {:ok, turtle} <- AshR2RML.R2RML.render(bundle) do
      {:ok, turtle}
    end
  end

  @doc "Explore all lawful read-only SPARQL observation strategies without selecting among them implicitly."
  @spec explore_sparql(String.t() | AshR2RML.SPARQL.Query.t(), keyword()) ::
          {:ok, AshR2RML.SPARQL.Plan.t()} | {:error, Refusal.t()}
  def explore_sparql(query, opts \\ []) do
    AshR2RML.SPARQL.explore(query, opts)
  end

  @doc "Execute a selected or uniquely lawful read-only SPARQL observation plan."
  @spec observe_sparql(String.t() | AshR2RML.SPARQL.Query.t(), keyword()) ::
          {:ok, AshR2RML.SPARQL.Observation.t()} | {:error, term()}
  def observe_sparql(query, opts \\ []) do
    with {:ok, plan} <- explore_sparql(query, opts) do
      AshR2RML.SPARQL.execute(plan)
    end
  end

  @doc "Return a deterministic SHA-256 identity for a normalized mapping or bundle."
  @spec hash(Resource.t() | Bundle.t()) :: String.t()
  def hash(%Resource{} = mapping), do: mapping |> Mapping.normalize() |> digest()
  def hash(%Bundle{} = bundle), do: bundle |> Mapping.normalize() |> digest()

  @doc "Audit resources independently so one refusal does not hide other standing."
  @spec audit([module()]) :: %{admitted: [map()], refused: [map()]}
  def audit(resources) when is_list(resources) do
    resources
    |> Enum.sort_by(&inspect/1)
    |> Enum.reduce(%{admitted: [], refused: []}, fn resource, acc ->
      case mapping(resource) do
        {:ok, mapping} ->
          admitted = %{
            resource: resource,
            mapping_hash: hash(mapping),
            mapping_identity: Mapping.mapping_identity(mapping)
          }

          %{acc | admitted: [admitted | acc.admitted]}

        {:error, reason} ->
          %{acc | refused: [%{resource: resource, reason: reason} | acc.refused]}
      end
    end)
    |> then(fn result ->
      %{
        admitted: Enum.reverse(result.admitted),
        refused: Enum.reverse(result.refused)
      }
    end)
  end

  defp do_bundle([], _seen, mappings) do
    bundle = %Bundle{resources: Enum.reverse(mappings)} |> Mapping.normalize()

    case Mapping.validate(bundle) do
      :ok -> {:ok, bundle}
      {:error, refusals} -> {:error, refusals}
    end
  end

  defp do_bundle([resource | rest], seen, mappings) do
    if MapSet.member?(seen, resource) do
      do_bundle(rest, seen, mappings)
    else
      case mapping(resource) do
        {:ok, mapping} ->
          dependencies = Enum.map(mapping.reference_object_maps, & &1.parent_resource)

          do_bundle(
            rest ++ dependencies,
            MapSet.put(seen, resource),
            [mapping | mappings]
          )

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp subject_map(resource) do
    primary_key = List.wrap(Ash.Resource.Info.primary_key(resource))

    if primary_key == [] do
      {:error,
       Refusal.new(
         :REFUSED_NON_UNIQUE_SEMANTIC_IDENTITY,
         resource,
         "R2RML projection requires an admitted Ash primary key"
       )}
    else
      with {:ok, columns} <- map_ok(primary_key, &Introspection.column(resource, &1)) do
        module_id = resource |> inspect() |> String.trim_leading("Elixir.")
        fields = Enum.map_join(columns, "/", &"{#{&1}}")

        {:ok,
         %SubjectMap{
           strategy: :template,
           value: @subject_prefix <> module_id <> "/" <> fields,
           term_type: :iri
         }}
      end
    end
  end

  defp predicate_object_maps(resource, projected_attributes) do
    map_ok(projected_attributes, fn projected ->
      attribute = Ash.Resource.Info.attribute(resource, projected.ash_name)

      cond do
        is_nil(attribute) ->
          {:error,
           Refusal.new(
             :REFUSED_UNKNOWN_ATTRIBUTE,
             {resource, projected.ash_name},
             "public ontology projection references an unknown Ash attribute"
           )}

        true ->
          with {:ok, column} <- Introspection.column(resource, projected.ash_name),
               {:ok, datatype} <- DatatypeRegistry.resolve(attribute.type) do
            {:ok,
             %PredicateObjectMap{
               attribute: projected.ash_name,
               predicate_iri: projected.predicate,
               object_map: %ObjectMap{
                 strategy: :column,
                 value: column,
                 datatype: datatype,
                 term_type: :literal
               }
             }}
          end
      end
    end)
  end

  defp reference_object_maps(resource, projected_relationships) do
    map_ok(projected_relationships, fn projected ->
      with {:ok, metadata} <- Introspection.relationship(resource, projected.ash_name) do
        {:ok,
         %ReferenceObjectMap{
           relationship: projected.ash_name,
           predicate_iri: projected.predicate,
           parent_resource: metadata.destination,
           joins: Map.get(metadata, :joins, []),
           metadata: Map.put(metadata, :semantic_source, :xaas_public_ontology_registry)
         }}
      end
    end)
  end

  defp map_ok(values, fun) do
    values
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, acc} ->
      case fun.(value) do
        {:ok, mapped} -> {:cont, {:ok, [mapped | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp digest(value) do
    value
    |> canonical_term()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical_term(%_{} = struct), do: struct |> Map.from_struct() |> canonical_term()

  defp canonical_term(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {key, canonical_term(value)} end)
    |> Enum.sort_by(fn {key, _value} -> inspect(key) end)
  end

  defp canonical_term(list) when is_list(list), do: Enum.map(list, &canonical_term/1)
  defp canonical_term(other), do: other
end
