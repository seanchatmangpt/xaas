defmodule Xaas.Graphlaw.CatalogTest do
  use ExUnit.Case, async: true

  alias Xaas.Graphlaw.Catalog
  alias Xaas.Graphlaw.Capability
  alias Xaas.Graphlaw.EngineLimit

  @registry_path Catalog.default_registry_path()

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    {:ok, counts} = Catalog.ingest(@registry_path)
    {:ok, counts: counts}
  end

  defp registry, do: @registry_path |> File.read!() |> Jason.decode!()

  test "ingest loads the real registry: 15 limits and 8 capabilities", %{counts: counts} do
    reg = registry()

    assert counts.limits == map_size(reg["limits"])
    assert counts.limits == 15
    assert counts.capabilities == length(reg["authorities"])
    assert counts.capabilities == 8
  end

  test "every limit is created with the registry's exact value and metadata" do
    reg = registry()

    stored =
      EngineLimit
      |> Ash.read!()
      |> Map.new(&{&1.name, &1})

    assert map_size(stored) == map_size(reg["limits"])

    Enum.each(reg["limits"], fn {name, value} ->
      row = Map.fetch!(stored, name)
      meta = reg["limit_meta"][name] || %{}

      assert row.value == value
      assert row.scope == Map.get(meta, "scope", "unknown")
      assert row.source == Map.get(meta, "source", "unknown")
      assert row.unit == Map.get(meta, "unit", "count")
    end)
  end

  test "refusal_name is present-or-null exactly matching the source registry" do
    reg = registry()

    stored =
      EngineLimit
      |> Ash.read!()
      |> Map.new(&{&1.name, &1})

    Enum.each(reg["limits"], fn {name, _value} ->
      row = Map.fetch!(stored, name)
      expected = get_in(reg, ["limit_meta", name, "refusal_name"])
      assert row.refusal_name == expected

      # both classes are witnessed in the real source
      if Map.has_key?(reg["limit_meta"][name] || %{}, "refusal_name") do
        assert is_binary(row.refusal_name) and row.refusal_name != ""
      else
        assert is_nil(row.refusal_name)
      end
    end)

    named = Enum.count(stored, fn {_n, row} -> not is_nil(row.refusal_name) end)
    source_named = Enum.count(reg["limit_meta"], fn {_n, m} -> Map.has_key?(m, "refusal_name") end)
    assert named == source_named
    assert named > 0
  end

  test "limits_by_scope/1 returns only that scope" do
    reg = registry()

    scopes =
      reg["limit_meta"]
      |> Map.values()
      |> MapSet.new(& &1["scope"])

    Enum.each(scopes, fn scope ->
      expected =
        reg["limit_meta"]
        |> Enum.filter(fn {_n, m} -> m["scope"] == scope end)
        |> MapSet.new(fn {n, _m} -> n end)
      got = MapSet.new(Catalog.limits_by_scope(scope), & &1.name)
      assert got == expected
    end)

    # a concrete spot check on the real source
    abi = Catalog.limits_by_scope("abi") |> Enum.map(& &1.name)
    assert "max_json_depth" in abi
    assert "n3_max_iterations" not in abi

    assert Catalog.limits_by_scope("no-such-scope") == []
  end

  test "capabilities carry authority, profile, and supported engines" do
    reg = registry()
    engines = reg["engines"]

    stored =
      Capability
      |> Ash.read!()
      |> Map.new(&{&1.name, &1})

    Enum.each(reg["authorities"], fn %{"capability" => cap, "authority" => alg} ->
      row = Map.fetch!(stored, cap)
      assert row.algorithm == alg
      assert row.profile == reg["graphlaw_version"]

      base = alg |> String.split("::") |> List.first() |> String.downcase()
      expected = Enum.filter(engines, &(String.downcase(&1) == base))
      assert row.supported_in == expected
      assert row.supported_in != []
    end)

    assert stored["SHACL"].supported_in == ["PurRdf"]
    assert stored["Notation3"].supported_in == ["Eyeron"]
  end

  test "ingest is idempotent (upsert, no duplicates)" do
    {:ok, counts} = Catalog.ingest(@registry_path)

    assert counts == %{limits: 15, capabilities: 8}
    assert length(Ash.read!(EngineLimit)) == 15
    assert length(Ash.read!(Capability)) == 8
  end
end
