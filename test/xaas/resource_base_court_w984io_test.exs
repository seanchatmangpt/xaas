defmodule Xaas.ResourceBaseCourtW984ioTest do
  @moduledoc """
  W984io unclaimed-family probe: base-macro courts over `Xaas.Resource`
  (`lib/xaas/resource.ex`).

  Census result (read against test/, W984ik consumer census context):

  | injected branch                | prior standing                                  |
  |--------------------------------|-------------------------------------------------|
  | `ontology_projection/0`        | COVERED only via `function_exported?` census    |
  |                                | (registry_test); value never asserted on a      |
  |                                | real domain resource                            |
  | `ontology_projection!/0` ok    | COVERED (actuation_test, receipt hash bindings) |
  | `ontology_projection!/0` raise | UNCOVERED — unreachable for any admitted        |
  |                                | resource (every domain resource admits;         |
  |                                | registry_test enforces it), typed UNCOVERED     |
  | `ontology_projection_hash/0`   | COVERED (registry_test, receipt courts)         |
  | `r2rml_mapping/0` + `_hash/0`  | COVERED on test-tree fixture only               |
  |                                | (ash_r2rml_test GoodResource); never on a       |
  |                                | real domain resource                            |
  | `r2rml_mapping!/0` raise       | UNCOVERED — courted here via the existing       |
  |                                | real `R2RMLRefusalTest.NoPkResource` module     |

  The prompt-hypothesized base validations / timestamp touch / multitenancy
  defaults do NOT exist in the macro: `Xaas.Resource` delegates everything to
  `Ash.Resource` and injects only the six semantic-projection functions.
  Timestamp touch and deny-by-default floors are per-resource Ash surface, so
  they are exercised here only as real-action end-to-end context, never
  restated as macro behavior.

  Chicago discipline: real compiled `Xaas.Resource` modules, real
  `Xaas.Semantics.Registry`/`Xaas.Semantics.R2RML` admission, real Ash
  actions (ETS for `Xaas.Conference.Sponsor`, sandboxed Postgres for
  `Xaas.Marketplace.Provider`). Zero mocks.

  Mutation rationale per test: each assertion names the injected function that
  must survive mutation of `lib/xaas/resource.ex` for the court to stay
  non-vacuous.
  """

  use ExUnit.Case, async: true

  alias Xaas.Conference.Sponsor
  alias Xaas.Marketplace.Provider
  alias Xaas.Semantics.R2RML
  alias Xaas.Semantics.Registry

  @pair [Sponsor, Provider]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  describe "ontology_projection/0 value contract (previously function_exported?-only)" do
    test "non-bang equals Registry.projection and bang for both real resources" do
      for resource <- @pair do
        Code.ensure_loaded!(resource)

        assert function_exported?(resource, :ontology_projection, 0)

        projection = resource.ontology_projection()
        assert {:ok, admitted} = Registry.admit(resource)

        # Mutation rationale: replacing the macro's ontology_projection body
        # with a stub/nil must fail this equality.
        assert projection == admitted
        assert projection == Registry.projection(resource)
        assert projection == resource.ontology_projection!()

        assert projection.resource == resource
        assert projection.classes != []

        iris =
          projection.classes ++
            Enum.map(projection.attributes, & &1.predicate) ++
            Enum.map(projection.relationships, & &1.predicate)

        assert Enum.all?(iris, &Registry.public_iri?/1),
               "#{inspect(resource)} emitted a non-public ontology IRI"
      end
    end

    test "hash identity is deterministic, 64-hex, and resource-distinct" do
      hashes = Enum.map(@pair, & &1.ontology_projection_hash())

      # Mutation rationale: breaking hash normalization in Registry.hash or
      # the macro's hash delegation must flip one of these.
      for {resource, hash} <- Enum.zip(@pair, hashes) do
        assert hash == Registry.hash(resource.ontology_projection())
        assert byte_size(hash) == 64
        assert hash =~ ~r/^[0-9a-f]{64}$/
        assert hash == resource.ontology_projection_hash()
      end

      assert length(Enum.uniq(hashes)) == length(hashes),
             "distinct resources must not collide on projection hash"
    end
  end

  describe "r2rml_mapping contract on real domain resources" do
    test "relational resource maps; non-relational (ETS) resource refuses with a typed refusal" do
      # Mutation rationale: aliasing the macro's r2rml_mapping to a constant or
      # dropping the R2RML delegation must fail these equalities.
      assert {:ok, mapping} = Provider.r2rml_mapping()
      assert {:ok, via_registry} = R2RML.mapping(Provider)
      assert mapping == via_registry
      assert Provider.r2rml_mapping!() == mapping

      hash = Provider.r2rml_mapping_hash()
      assert hash == R2RML.hash(mapping)
      assert byte_size(hash) == 64

      # Real domain finding courted here: the ETS-backed real resource refuses
      # R2RML projection (macro branch exercised through a production resource,
      # not a fixture).
      assert {:error, %AshR2RML.Refusal{code: :REFUSED_INVALID_LOGICAL_TABLE} = refusal} =
               Sponsor.r2rml_mapping()

      assert refusal.subject == Sponsor

      assert_raise ArgumentError, ~r/R2RML mapping refused/, fn ->
        Sponsor.r2rml_mapping!()
      end
    end

    test "a real compiled Xaas.Resource without a primary key refuses non-bang and raises via bang" do
      resource = __MODULE__.NoPkResource
      assert function_exported?(resource, :r2rml_mapping!, 0)

      assert {:error, %AshR2RML.Refusal{code: :REFUSED_NON_UNIQUE_SEMANTIC_IDENTITY} = refusal} =
               resource.r2rml_mapping()

      assert refusal.subject == resource

      # Mutation rationale: deleting the {:error, reason} -> raise arm of the
      # injected r2rml_mapping!/0 must fail this assert_raise.
      assert_raise ArgumentError, ~r/R2RML mapping refused/, fn ->
        resource.r2rml_mapping!()
      end
    end
  end

  describe "real-action end-to-end context" do
    test "Sponsor (ETS, no policies) create touches both timestamps under a real Ash action" do
      slug = "w984io-#{System.unique_integer([:positive])}"

      sponsor =
        Sponsor
        |> Ash.Changeset.for_create(:create, %{
          name: "W984io Probe Sponsor",
          slug: slug,
          tier: :gold,
          url: "https://example.com/w984io"
        })
        |> Ash.create!()

      # Timestamp touch is Ash core, not macro-injected; asserted as real
      # end-to-end context only.
      assert %DateTime{} = sponsor.inserted_at
      assert %DateTime{} = sponsor.updated_at

      assert [%Sponsor{} = found] = Ash.read!(Sponsor, authorize?: false)
      assert found.id == sponsor.id
      assert found.inserted_at == sponsor.inserted_at
    end

    test "Provider (Postgres, deny-by-default floor) create persists with timestamps" do
      org_id = "org-w984io-#{System.unique_integer([:positive])}"
      provider = Xaas.Generator.create_provider!(%{org_id: org_id})

      assert provider.org_id == org_id
      assert %DateTime{} = provider.inserted_at
      assert %DateTime{} = provider.updated_at

      # The persisted row's identity is the resource's projection hash — the
      # same identity actuation receipts carry (context, not a restated floor).
      assert Provider.ontology_projection_hash() == Registry.hash(Registry.projection(Provider))
    end
  end

  defmodule NoPkResource do
    @moduledoc """
    Legitimately degenerate real `Xaas.Resource` fixture: no primary key, so
    the R2RML projection must refuse it. Same shape as the disclosed fixture in
    `r2rml_refusal_test.exs`.
    """

    use Xaas.Resource,
      otp_app: :xaas,
      domain: Xaas.Billing,
      data_layer: AshPostgres.DataLayer

    postgres do
      table("r2rml_w984io_no_pk_resources")
      repo(Xaas.Repo)
    end

    resource do
      require_primary_key?(false)
    end

    attributes do
      attribute :name, :string do
        allow_nil?(false)
        public?(true)
      end
    end
  end
end
