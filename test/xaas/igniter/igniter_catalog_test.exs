defmodule Xaas.Igniter.CatalogTest do
  @moduledoc """
  Real Chicago-style courts over `Xaas.Igniter.Catalog`: the courts ingest the
  REAL ggen_igniter refusals schema at its canonical path (no mocks, no
  fixture silhouettes — the real schema file is the fixture).
  """
  use ExUnit.Case, async: false

  alias Xaas.Igniter.Catalog
  alias Xaas.Igniter.PackManifest
  alias Xaas.Igniter.RefusalCode

  @schema_path Catalog.default_schema_path()

  setup do
    wipe()
    :ok
  end

  defp wipe do
    RefusalCode |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
    PackManifest |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
  end

  defp real_schema, do: @schema_path |> File.read!() |> Jason.decode!()

  defp pack_manifest_fixture do
    %{
      "packs" => [
        %{
          "pack_name" => "semantic-jira-pack",
          "version" => "26.10.5",
          "profile" => "project",
          "gate_count" => 12,
          "verify_count" => 9,
          "misfiled_count" => 2
        },
        %{
          "pack_name" => "receipted-extension-pack",
          "version" => "26.10.5",
          "profile" => "projection",
          "gate_count" => 4,
          "verify_count" => 7,
          "misfiled_count" => 0
        }
      ]
    }
  end

  # 138 as of ggen_igniter 7dbcdb3 (SPARQL_EXISTS_UNSUPPORTED was the wave-added refusal code).
  @refusal_count 138

  @tag :igniter_catalog
  test "ingesting the REAL refusals schema projects exactly 138 codes" do
    assert {:ok, @refusal_count} = Catalog.ingest(@schema_path)
    assert @refusal_count = Catalog.list_refusals() |> length()
  end

  @tag :igniter_catalog
  test "re-ingest is idempotent (upsert on code)" do
    assert {:ok, @refusal_count} = Catalog.ingest(@schema_path)
    assert {:ok, @refusal_count} = Catalog.ingest(@schema_path)
    assert @refusal_count = Catalog.list_refusals() |> length()
  end

  @tag :igniter_catalog
  test "count_by_family covers every code exactly once" do
    {:ok, @refusal_count} = Catalog.ingest(@schema_path)

    families = Catalog.count_by_family()
    assert @refusal_count = families |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    # real family names from the schema itself
    real_families =
      real_schema()["refusals"] |> Enum.map(& &1["family"]) |> Enum.uniq() |> Enum.sort()

    assert real_families == Enum.map(families, &elem(&1, 0))
  end

  @tag :igniter_catalog
  test "retryable filter splits the real corpus" do
    {:ok, @refusal_count} = Catalog.ingest(@schema_path)

    expected_retryable =
      real_schema()["refusals"] |> Enum.count(& &1["retryable"])

    assert expected_retryable == Catalog.refusals_by_retryable(true) |> length()
    assert @refusal_count - expected_retryable == Catalog.refusals_by_retryable(false) |> length()
  end

  @tag :igniter_catalog
  test "owner filter returns the owner's real codes" do
    {:ok, @refusal_count} = Catalog.ingest(@schema_path)

    owner =
      real_schema()["refusals"]
      |> Enum.find(& &1["owner"])
      |> Map.get("owner")

    codes = Catalog.refusals_by_owner(owner)
    assert codes != []
    assert Enum.all?(codes, &(&1.owner == owner))

    expected_count =
      real_schema()["refusals"] |> Enum.count(&(&1["owner"] == owner))

    assert expected_count == length(codes)
  end

  @tag :igniter_catalog
  test "ingested fields round-trip from the real schema" do
    {:ok, @refusal_count} = Catalog.ingest(@schema_path)

    entry = real_schema()["refusals"] |> Enum.find(& &1["broken_term"])
    code = Catalog.refusals_by_owner(entry["owner"]) |> Enum.find(&(&1.code == entry["code"]))

    assert %RefusalCode{} = code
    assert code.family == entry["family"]
    assert code.retryable == entry["retryable"]
    assert code.broken_term == entry["broken_term"]
    assert code.fix_hint == entry["fix_hint"]
  end

  @tag :igniter_catalog
  test "ingest refuses malformed input with a typed error" do
    assert {:error, %Catalog.Error{reason: :invalid_json}} = Catalog.ingest("{not json")
    assert {:error, %Catalog.Error{reason: :invalid_schema}} = Catalog.ingest(%{"nope" => 1})

    bad = %{"$schema" => "x", "refusals" => [%{"code" => "X", "retryable" => true}]}
    assert {:error, %Catalog.Error{reason: :invalid_refusal}} = Catalog.ingest(bad)
  end

  @tag :igniter_catalog
  test "ingest_packs loads the manifest inventory with gate/verify counts" do
    assert {:ok, 2} = Catalog.ingest_packs(pack_manifest_fixture())

    packs = Catalog.list_packs()
    assert 2 = length(packs)

    sjp = Enum.find(packs, &(&1.pack_name == "semantic-jira-pack"))
    assert %PackManifest{} = sjp
    assert sjp.gate_count == 12
    assert sjp.verify_count == 9
    assert sjp.misfiled_count == 2
    assert sjp.profile == "project"
    assert sjp.version == "26.10.5"
  end

  @tag :igniter_catalog
  test "ingest_packs accepts a bare list, a path, and is idempotent" do
    bare = pack_manifest_fixture()["packs"]
    assert {:ok, 2} = Catalog.ingest_packs(bare)
    assert {:ok, 2} = Catalog.ingest_packs(Jason.encode!(pack_manifest_fixture()))
    assert 2 = Catalog.list_packs() |> length()
  end

  @tag :igniter_catalog
  test "ingest_packs refuses malformed manifests with a typed error" do
    assert {:error, %Catalog.Error{reason: :invalid_manifest}} = Catalog.ingest_packs(%{"x" => 1})

    assert {:error, %Catalog.Error{reason: :invalid_json}} =
             Catalog.ingest_packs("{not json")
  end
end
