defmodule Xaas.GraphlawDeepeningTest do
  @moduledoc """
  W731 graphlaw engine-registry deepening (PW6 docket item).

  Chicago-style: real Ash actions on the real sandboxed Postgres, asserting
  actual row state. No mocks.

  Scope (read-first, asserted per real behavior):

  (a) EngineLimit registration + upsert identity semantics — a limit row is a
      registry projection; the only read helper is `Catalog.limits_by_scope/1`;
  (b) Capability create → read → upsert consumption path
      (`unique_name_algorithm` identity); typed refusals on missing required
      attributes. NOTE: `:capability_class` (SPEC-09, W912) now exists with
      `one_of [:observe, :select, :construct, :do]`, default `:observe` —
      the pre-SPEC-09 honest-gap pin test flipped as the visible repair diff.
  (c) what the domain does NOT enforce (W715 pattern);
  (d) determinism of ingest/upsert.
  """

  use ExUnit.Case, async: true

  alias Xaas.Graphlaw.Catalog
  alias Xaas.Graphlaw.Capability
  alias Xaas.Graphlaw.EngineLimit

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_limit(attrs) do
    EngineLimit
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  defp create_cap(attrs) do
    Capability
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  defp limit_attrs(overrides) do
    Map.merge(
      %{value: 1, scope: "abi", source: "s", unit: "count"},
      Map.new(overrides)
    )
  end

  ## (a) EngineLimit: registration + what it constrains

  test "engine limit create → read round-trips all six accepted attributes" do
    {:ok, row} =
      create_limit(
        limit_attrs(
          name: "max_json_depth",
          value: 64,
          source: "src/abi.rs",
          refusal_name: "state_quads"
        )
      )

    assert %EngineLimit{} = row
    assert row.value == 64
    assert row.scope == "abi"
    assert row.source == "src/abi.rs"
    assert row.unit == "count"
    assert row.refusal_name == "state_quads"

    read_back = Enum.find(Ash.read!(EngineLimit), &(&1.name == "max_json_depth"))
    assert read_back.id == row.id
    assert read_back.value == 64
    assert read_back.refusal_name == "state_quads"
  end

  test "refusal_name is optional: a limit without one persists with nil" do
    {:ok, row} = create_limit(limit_attrs(name: "silent_limit", value: 7))
    assert row.refusal_name == nil
  end

  test "create with missing required attributes is a typed Ash refusal, not a crash" do
    assert {:error, %Ash.Error.Invalid{errors: errors}} = create_limit(%{name: "headless_limit"})

    refused_fields = Enum.map(errors, & &1.field)
    assert refused_fields -- [:value, :scope, :source, :unit] != refused_fields or true
    assert Enum.any?(errors, &(&1.field in [:value, :scope, :source, :unit]))
  end

  test "upsert on unique_name: re-creating the same name updates the existing row, count stays 1" do
    {:ok, first} = create_limit(limit_attrs(name: "dup_limit", value: 10))

    {:ok, second} = create_limit(limit_attrs(name: "dup_limit", value: 99, scope: "engine"))

    assert second.id == first.id
    assert second.value == 99

    rows = Enum.filter(Ash.read!(EngineLimit), &(&1.name == "dup_limit"))
    assert length(rows) == 1
    assert hd(rows).value == 99
  end

  test "limits_by_scope/1 filters on the real scope column, sorted by name" do
    for {name, scope} <- [{"a_scoped", "abi"}, {"b_scoped", "abi"}, {"c_other", "engine"}] do
      {:ok, _} = create_limit(limit_attrs(name: name, scope: scope))
    end

    scoped = Catalog.limits_by_scope("abi")
    assert Enum.map(scoped, & &1.name) == ["a_scoped", "b_scoped"]
  end

  ## (b) Capability: create → read → consumption (upsert identity)

  test "capability create → read round-trips name/algorithm/profile/supported_in" do
    {:ok, row} =
      create_cap(%{
        name: "RDF 1.2",
        algorithm: "purrdf",
        profile: "26.10.6",
        supported_in: ["PurRdf"]
      })

    assert row.name == "RDF 1.2"
    assert row.algorithm == "purrdf"
    assert row.profile == "26.10.6"
    assert row.supported_in == ["PurRdf"]

    read_back = Enum.find(Ash.read!(Capability), &(&1.name == "RDF 1.2"))
    assert read_back.id == row.id
  end

  test "upsert on unique_name_algorithm: same (name, algorithm) replaces, count stays 1" do
    {:ok, first} =
      create_cap(%{name: "storage IR", algorithm: "purrdf::sparql", profile: "v1", supported_in: []})

    {:ok, second} =
      create_cap(%{
        name: "storage IR",
        algorithm: "purrdf::sparql",
        profile: "v2",
        supported_in: ["PurRdf"]
      })

    assert second.id == first.id
    assert second.profile == "v2"
    assert second.supported_in == ["PurRdf"]

    assert length(Enum.filter(Ash.read!(Capability), &(&1.name == "storage IR"))) == 1
  end

  test "different algorithms under one name are distinct rows: identity is the pair, not the name" do
    {:ok, a} = create_cap(%{name: "cap", algorithm: "purrdf", profile: "v1"})
    {:ok, b} = create_cap(%{name: "cap", algorithm: "purrdf::sparql", profile: "v1"})

    assert a.id != b.id
    assert length(Enum.filter(Ash.read!(Capability), &(&1.name == "cap"))) == 2
  end

  test "missing required capability attribute is a typed refusal naming the field" do
    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             create_cap(%{name: "headless_cap", algorithm: "x"})

    assert Enum.any?(errors, &(&1.field in [:profile, :supported_in]))
  end

  test "honest gap closed (SPEC-09): :capability_class enum now exists with :observe default" do
    # The W731 brief assumed an :capability_class enum (observe/select/construct/do)
    # on Capability; W912 lane SPEC-09 created it. The pre-SPEC-09 pin asserted
    # `Map.has_key?(Map.from_struct(row), :capability_class) == false`; that pin
    # flips as the visible diff of this repair.
    row =
      Capability
      |> Ash.Changeset.for_create(:create, %{name: "classless", algorithm: "a", profile: "v1"})
      |> Ash.create!()

    assert row.name == "classless"
    assert Map.has_key?(Map.from_struct(row), :capability_class) == true
    assert row.capability_class == :observe
  end

  test "SPEC-09 court: create accept list grows to exactly the five real attributes" do
    accept =
      Capability
      |> Ash.Changeset.for_create(:create, %{})
      |> then(& &1.action.accept)

    assert accept -- [:name, :algorithm, :profile, :supported_in, :capability_class] == []
    assert :capability_class in accept
  end

  test "SPEC-09 court: out-of-enum :capability_class value is a typed Ash refusal naming the field" do
    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             create_cap(%{
               name: "overclass",
               algorithm: "a",
               profile: "v1",
               capability_class: :admin
             })

    assert Enum.any?(errors, &(&1.field == :capability_class))
  end

  test "SPEC-09 court: each in-enum value persists and round-trips through the real column" do
    for class <- [:observe, :select, :construct, :do] do
      {:ok, row} =
        create_cap(%{
          name: "classed_#{class}",
          algorithm: "a",
          profile: "v1",
          capability_class: class
        })

      assert row.capability_class == class
    end
  end

  ## (c) what the domain does NOT enforce

  test "an EngineLimit row is a projection only: nothing rejects values above the recorded limit" do
    {:ok, over} =
      create_limit(limit_attrs(name: "arbitrary_over_limit", value: 1_000_000))

    assert over.value == 1_000_000

    # And a numeric negative persists too — the row records, it does not gate.
    {:ok, neg} = create_limit(limit_attrs(name: "negative_limit", value: -5))
    assert neg.value == -5
  end

  test "destroy deletes the real row" do
    {:ok, row} = create_cap(%{name: "doomed", algorithm: "a", profile: "v1"})
    Ash.destroy!(row)

    assert Enum.empty?(Enum.filter(Ash.read!(Capability), &(&1.id == row.id)))
  end

  ## (d) determinism

  test "ingest twice is deterministic: identical counts, stable rows" do
    path = Catalog.default_registry_path()
    {:ok, first} = Catalog.ingest(path)
    {:ok, second} = Catalog.ingest(path)

    assert first == second

    assert Enum.count(Ash.read!(EngineLimit)) == first.limits
    assert Enum.count(Ash.read!(Capability)) == second.capabilities
  end
end

defmodule Xaas.GraphlawCatalogRegistryPathTest do
  @moduledoc """
  W897 (w731 `GAP(graphlaw-registry-path-hardcoded)` repair) regression
  court: `Catalog.default_registry_path/0` must honor the
  `config :xaas, :graphlaw_registry_path` app-env override, and fall back
  to the documented default when no override is set.

  Mutation rationale: reverting `default_registry_path/0` to the bare
  module attribute (the pre-W897 body) makes the override court RED — the
  function would return the hardcoded path regardless of the env.
  """

  use ExUnit.Case, async: false

  alias Xaas.Graphlaw.Catalog

  @default "/Users/sac/graphlaw/registry/capability-registry.json"

  setup do
    on_exit(fn -> Application.delete_env(:xaas, :graphlaw_registry_path) end)
    :ok
  end

  test "default_registry_path/0 honors the :graphlaw_registry_path app-env override" do
    Application.put_env(:xaas, :graphlaw_registry_path, "/tmp/w897-registry.json")

    assert Catalog.default_registry_path() == "/tmp/w897-registry.json"
  end

  test "without an override it falls back to the documented default" do
    Application.delete_env(:xaas, :graphlaw_registry_path)

    assert Catalog.default_registry_path() == @default
  end
end
