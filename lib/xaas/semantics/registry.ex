defmodule Xaas.Semantics.Registry do
  @moduledoc """
  Canonical public-ontology projection for every `Xaas.Resource`.

  Ash remains the executable application model, but resource identity is no longer
  allowed to terminate at an application-private vocabulary. Every Ash resource is
  projected onto stable, public semantic classes and every attribute/relationship is
  mapped to a public predicate while retaining its exact Ash name for lossless replay.

  The registry intentionally admits only namespaces owned by public standards bodies or
  widely published vocabularies. In particular, an application-local `xaas.local`
  namespace is never considered sufficient semantic standing.

  The default class selection is conservative: when a narrower public class is not
  justified from the resource's name, the resource is a `prov:Entity`. That preserves a
  lawful public-ontology projection without inventing domain semantics. Resources can
  later refine this projection without changing the actuation protocol because receipts
  bind the complete projection hash, not a hand-written type string.
  """

  @rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  @rdfs "http://www.w3.org/2000/01/rdf-schema#"
  @owl "http://www.w3.org/2002/07/owl#"
  @xsd "http://www.w3.org/2001/XMLSchema#"
  @prov "http://www.w3.org/ns/prov#"
  @dct "http://purl.org/dc/terms/"
  @dcat "http://www.w3.org/ns/dcat#"
  @skos "http://www.w3.org/2004/02/skos/core#"
  @odrl "http://www.w3.org/ns/odrl/2/"
  @org "http://www.w3.org/ns/org#"
  @sosa "http://www.w3.org/ns/sosa/"
  @schema "https://schema.org/"
  @foaf "http://xmlns.com/foaf/0.1/"

  @namespaces %{
    rdf: @rdf,
    rdfs: @rdfs,
    owl: @owl,
    xsd: @xsd,
    prov: @prov,
    dcterms: @dct,
    dcat: @dcat,
    skos: @skos,
    odrl: @odrl,
    org: @org,
    sosa: @sosa,
    schema: @schema,
    foaf: @foaf
  }

  @public_namespace_values Map.values(@namespaces)

  @attribute_predicates %{
    id: @dct <> "identifier",
    name: @schema <> "name",
    slug: @skos <> "notation",
    description: @dct <> "description",
    status: @dct <> "type",
    org_id: @org <> "organization",
    user_id: @prov <> "wasAssociatedWith",
    actor_id: @prov <> "wasAssociatedWith",
    actor_description: @dct <> "description",
    requested_by: @prov <> "wasAssociatedWith",
    approved_by: @prov <> "wasAssociatedWith",
    resource_id: @dct <> "identifier",
    resource_type: @dct <> "type",
    action: @odrl <> "action",
    role: @org <> "role",
    email: @schema <> "email",
    url: @schema <> "url",
    endpoint: @schema <> "url",
    amount: @schema <> "value",
    currency: @schema <> "currency",
    region: @schema <> "addressRegion",
    tier: @skos <> "notation",
    metadata: @prov <> "value",
    detail: @dct <> "description",
    subject: @dct <> "subject",
    inserted_at: @dct <> "created",
    created_at: @dct <> "created",
    updated_at: @dct <> "modified",
    occurred_at: @prov <> "generatedAtTime",
    starts_at: @schema <> "startDate",
    start_at: @schema <> "startDate",
    ends_at: @schema <> "endDate",
    end_at: @schema <> "endDate"
  }

  @doc "Returns the public namespaces admitted by the control plane."
  @spec namespaces() :: %{atom() => String.t()}
  def namespaces, do: @namespaces

  @doc "Builds the reversible public-ontology projection for an Ash resource."
  @spec projection(module()) :: map()
  def projection(resource) when is_atom(resource) do
    attributes =
      resource
      |> Ash.Resource.Info.attributes()
      |> Enum.map(fn attribute ->
        %{
          ash_name: attribute.name,
          ash_type: inspect(attribute.type),
          predicate: predicate_for(attribute.name)
        }
      end)
      |> Enum.sort_by(&to_string(&1.ash_name))

    relationships =
      resource
      |> Ash.Resource.Info.relationships()
      |> Enum.map(fn relationship ->
        %{
          ash_name: relationship.name,
          destination: inspect(relationship.destination),
          source_attribute: Map.get(relationship, :source_attribute),
          destination_attribute: Map.get(relationship, :destination_attribute),
          predicate: relationship_predicate(relationship.name)
        }
      end)
      |> Enum.sort_by(&to_string(&1.ash_name))

    %{
      resource: resource,
      resource_name: inspect(resource),
      classes: classes_for(resource),
      attributes: attributes,
      relationships: relationships,
      vocabularies: vocabulary_iris(attributes, relationships)
    }
  end

  @doc "Admits a projection only when every semantic IRI belongs to a public namespace."
  @spec admit(module()) :: {:ok, map()} | {:error, term()}
  def admit(resource) when is_atom(resource) do
    projection = projection(resource)

    iris =
      projection.classes ++
        Enum.map(projection.attributes, & &1.predicate) ++
        Enum.map(projection.relationships, & &1.predicate)

    case Enum.find(iris, &(not public_iri?(&1))) do
      nil -> {:ok, projection}
      iri -> {:error, {:non_public_ontology_iri, iri}}
    end
  rescue
    error -> {:error, {:projection_failed, resource, Exception.message(error)}}
  end

  @doc "Returns a deterministic SHA-256 identity for a complete semantic projection."
  @spec hash(map()) :: String.t()
  def hash(projection) when is_map(projection) do
    projection
    |> canonical_projection()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @doc "True only for IRIs in an admitted public namespace."
  @spec public_iri?(term()) :: boolean()
  def public_iri?(iri) when is_binary(iri) do
    Enum.any?(@public_namespace_values, &String.starts_with?(iri, &1))
  end

  def public_iri?(_), do: false

  defp canonical_projection(projection) do
    %{
      resource: projection.resource_name,
      classes: Enum.sort(projection.classes),
      attributes:
        Enum.map(projection.attributes, fn attribute ->
          {to_string(attribute.ash_name), attribute.ash_type, attribute.predicate}
        end),
      relationships:
        Enum.map(projection.relationships, fn relationship ->
          {to_string(relationship.ash_name), relationship.destination,
           relationship.source_attribute && to_string(relationship.source_attribute),
           relationship.destination_attribute && to_string(relationship.destination_attribute),
           relationship.predicate}
        end)
    }
  end

  defp vocabulary_iris(attributes, relationships) do
    (Enum.map(attributes, &namespace_for!(&1.predicate)) ++
       Enum.map(relationships, &namespace_for!(&1.predicate)))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp namespace_for!(iri) do
    Enum.find_value(@namespaces, fn {_name, namespace} ->
      if String.starts_with?(iri, namespace), do: namespace
    end) || raise ArgumentError, "IRI is not in a public namespace: #{inspect(iri)}"
  end

  defp predicate_for(name), do: Map.get(@attribute_predicates, name, fallback_predicate(name))

  defp fallback_predicate(name) do
    name = to_string(name)

    cond do
      String.ends_with?(name, "_id") -> @dct <> "relation"
      String.ends_with?(name, "_at") -> @prov <> "atTime"
      String.ends_with?(name, "_url") -> @schema <> "url"
      String.ends_with?(name, "_name") -> @schema <> "name"
      true -> @schema <> "additionalProperty"
    end
  end

  defp relationship_predicate(name) do
    case name do
      :org -> @org <> "organization"
      :organization -> @org <> "organization"
      :member -> @org <> "member"
      :members -> @org <> "member"
      :provider -> @dct <> "publisher"
      :user -> @prov <> "wasAssociatedWith"
      _ -> @dct <> "relation"
    end
  end

  defp classes_for(resource) do
    name = inspect(resource)

    cond do
      String.ends_with?(name, ".User") -> [@foaf <> "Person", @prov <> "Agent"]
      String.ends_with?(name, ".Org") -> [@org <> "Organization", @prov <> "Agent"]
      String.contains?(name, "OrgMembership") -> [@org <> "Membership"]
      String.contains?(name, "Approval") -> [@prov <> "Activity", @odrl <> "Agreement"]
      String.ends_with?(name, ".Provider") -> [@schema <> "Organization", @prov <> "Agent"]
      String.contains?(name, "Subscription") -> [@schema <> "Service"]
      String.ends_with?(name, ".Account") -> [@schema <> "BankAccount"]
      String.ends_with?(name, ".Balance") -> [@schema <> "MonetaryAmount"]
      String.ends_with?(name, ".Transfer") -> [@schema <> "MoneyTransfer", @prov <> "Activity"]
      String.contains?(name, "WebhookDelivery") -> [@prov <> "Activity"]
      String.contains?(name, "Webhook") -> [@schema <> "EntryPoint"]
      String.contains?(name, "Incident") -> [@schema <> "Event", @prov <> "Activity"]
      String.contains?(name, "FreezeWindow") -> [@schema <> "Schedule"]
      String.contains?(name, "Catalog") -> [@dcat <> "Catalog"]
      String.contains?(name, "Candidate") -> [@prov <> "Plan"]
      String.contains?(name, "Route") -> [@prov <> "Activity"]
      String.contains?(name, "Receipt") -> [@prov <> "Entity"]
      String.contains?(name, "Audit") -> [@prov <> "Entity"]
      true -> [@prov <> "Entity"]
    end
  end
end
