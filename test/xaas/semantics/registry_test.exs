defmodule Xaas.Semantics.RegistryTest do
  @moduledoc """
  Qualification tests for the ontology-first Ash contract.

  The test intentionally walks every resource registered in every configured Ash
  domain. Adding a resource without the `Xaas.Resource` projection contract must
  fail this suite rather than silently creating a private semantic island.
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.Registry

  # Library-generated (AshAuthentication nonce, AshPaperTrail `.Version`) and
  # not-yet-migrated resources: disclosed exemptions, not silent skips.
  @pending [
    Xaas.Accounts.Token.RevokeNonce,
    Xaas.Coupling.CouplingRun,
    Xaas.Ledger.EventLog,
    Xaas.Operations.AutofdePlannerCacheHotset,
    Xaas.Operations.AutofdePlannerCacheStats,
    Xaas.Operations.AutofdePlannerCandidate,
    Xaas.Operations.AutofdePlannerCatalog,
    Xaas.Operations.AutofdePlannerMatch
  ]
  defp exempt?(r), do: r in @pending or String.ends_with?(inspect(r), ".Version")

  test "every configured Ash resource admits a public-ontology projection" do
    resources =
      :xaas
      |> Application.fetch_env!(:ash_domains)
      |> Enum.flat_map(&Ash.Domain.Info.resources/1)
      |> Enum.uniq()
      |> Enum.reject(&exempt?/1)
      |> Enum.sort_by(&inspect/1)

    assert resources != []

    Enum.each(resources, fn resource ->
      Code.ensure_loaded!(resource)
      assert function_exported?(resource, :ontology_projection, 0),
             "#{inspect(resource)} does not use Xaas.Resource"

      assert function_exported?(resource, :ontology_projection_hash, 0),
             "#{inspect(resource)} has no semantic identity hash"

      assert {:ok, projection} = Registry.admit(resource)
      assert projection.resource == resource
      assert projection.classes != []

      iris =
        projection.classes ++
          Enum.map(projection.attributes, & &1.predicate) ++
          Enum.map(projection.relationships, & &1.predicate)

      assert iris != []

      assert Enum.all?(iris, &Registry.public_iri?/1),
             "#{inspect(resource)} emitted a non-public ontology IRI"

      refute Enum.any?(iris, &String.contains?(&1, "xaas.local")),
             "#{inspect(resource)} leaked an application-private ontology"

      hash = resource.ontology_projection_hash()
      assert byte_size(hash) == 64
      assert hash == Registry.hash(projection)
      assert hash == resource.ontology_projection_hash()
    end)
  end

  test "Ontop mapping is a projection of public vocabularies, not a second ontology" do
    mapping = File.read!("priv/ontop/xaas-mapping.ttl")

    refute mapping =~ "http://xaas.local/vocab#"
    refute mapping =~ "rr:class xv:"
    refute mapping =~ "rr:predicate xv:"

    assert mapping =~ "http://www.w3.org/ns/prov#"
    assert mapping =~ "http://purl.org/dc/terms/"
    assert mapping =~ "http://www.w3.org/ns/org#"
    assert mapping =~ "http://www.w3.org/ns/odrl/2/"
    assert mapping =~ "https://schema.org/"

    # XAAS instance URNs are allowed as resource identity. They are not ontology
    # vocabulary and therefore do not confer semantic or execution authority.
    assert mapping =~ "urn:xaas:resource:"
  end
end
