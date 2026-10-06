defmodule Xaas.Marketplace.CatalogTest do
  @moduledoc """
  Real Chicago-style courts over `Xaas.Marketplace.Catalog`: the courts ingest
  the REAL ggen-marketplace catalog JSON, generated on the fly by
  `python3 scripts/marketplace.py catalog` in /Users/sac/ggen-marketplace into
  a unique tmp file. No mocks, no fixture silhouettes — the real generator
  output is the fixture.
  """
  use ExUnit.Case, async: false

  alias Xaas.Marketplace.Catalog
  alias Xaas.Marketplace.Pack

  @marketplace_root "/Users/sac/ggen-marketplace"

  setup do
    wipe()

    on_exit(fn ->
      File.rm(gen_file())
    end)

    :ok
  end

  defp wipe do
    Pack |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
  end

  defp gen_file, do: System.tmp_dir() |> Path.join("xl1-catalog-#{node_suffix()}.json")

  defp node_suffix do
    # unique per test run so concurrent lanes never collide
    :persistent_term.get({__MODULE__, :suffix}, nil) || gen_suffix()
  end

  defp gen_suffix do
    suffix = :erlang.unique_integer([:positive]) |> Integer.to_string()
    :persistent_term.put({__MODULE__, :suffix}, suffix)
    suffix
  end

  defp generate_real_catalog! do
    {output, 0} =
      System.cmd("python3", ["scripts/marketplace.py", "catalog"],
        cd: @marketplace_root,
        stderr_to_stdout: true
      )

    file = gen_file()
    File.write!(file, output)
    file
  end

  @tag :real_marketplace_catalog
  test "ingesting the REAL marketplace catalog ingests exactly its packs" do
    file = generate_real_catalog!()
    expected_count = file |> File.read!() |> Jason.decode!() |> length_of_packs()

    assert {:ok, ^expected_count} = Catalog.ingest(file)
    assert length(Catalog.list_packs()) == expected_count
  end

  @tag :real_marketplace_catalog
  test "get_pack! by name returns exactly the right real pack" do
    Catalog.ingest(generate_real_catalog!())

    pack = Catalog.get_pack!("aaif-vanilla-pack")

    assert pack.version == "0.3.0"
    assert String.starts_with?(pack.digest, "sha256:")
    assert pack.lifecycle_tier == "thin"
    assert pack.readiness == "gates"
    assert pack.pack_class == nil
    assert String.contains?(pack.description, "Agentic AI Foundation")
  end

  @tag :real_marketplace_catalog
  test "search/1 for 'aaif' finds aaif-vanilla-pack" do
    Catalog.ingest(generate_real_catalog!())

    names = Catalog.search("aaif") |> Enum.map(& &1.name)

    assert "aaif-vanilla-pack" in names
    assert Enum.all?(names, &String.contains?(String.downcase(&1), "aaif"))
  end

  @tag :real_marketplace_catalog
  test "double ingest is idempotent: no duplicate packs" do
    file = generate_real_catalog!()
    expected = file |> File.read!() |> Jason.decode!() |> length_of_packs()

    assert {:ok, ^expected} = Catalog.ingest(file)
    assert {:ok, ^expected} = Catalog.ingest(file)

    names = Catalog.list_packs() |> Enum.map(& &1.name)
    assert length(names) == expected
    assert length(Enum.uniq(names)) == length(names)
  end

  test "invalid JSON produces the typed error, not an exception" do
    assert {:error, %Catalog.Error{reason: :invalid_json}} = Catalog.ingest("{not json")
  end

  test "wrong schema URL produces :invalid_catalog" do
    assert {:error, %Catalog.Error{reason: :invalid_catalog}} =
             Catalog.ingest(%{"schema" => "https://example.com/other", "packs" => []})
  end

  test "a pack missing required fields produces :invalid_pack and ingests nothing" do
    bad = %{
      "schema" => Catalog.catalog_schema_url(),
      "packs" => [%{"name" => "half-pack", "version" => "1.0.0"}]
    }

    assert {:error, %Catalog.Error{reason: :invalid_pack}} = Catalog.ingest(bad)
    assert Catalog.list_packs() == []
  end

  test "ingesting a decoded map works the same as a path" do
    map = %{
      "schema" => Catalog.catalog_schema_url(),
      "packs" => [
        %{
          "name" => "mini-pack",
          "version" => "1.0.0",
          "digest" => "sha256:" <> String.duplicate("00", 32),
          "download_url" => "https://example.com/mini.tar.gz",
          "description" => "A minimal hand-built pack",
          "tier" => "thin",
          "readiness" => %{"gates" => true, "readme" => true},
          "pack_class" => nil,
          "deprecated" => true
        }
      ]
    }

    assert {:ok, 1} = Catalog.ingest(map)

    pack = Catalog.get_pack!("mini-pack")
    assert pack.lifecycle_tier == "thin"
    assert pack.readiness == "gates+readme"
    assert pack.deprecated == true
  end

  defp length_of_packs(%{"packs" => packs}), do: Enum.count(packs)
end
