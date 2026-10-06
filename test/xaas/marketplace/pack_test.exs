defmodule Xaas.Marketplace.PackTest do
  @moduledoc """
  Real Chicago-style courts over the `Xaas.Marketplace.Pack` resource: real
  `Ash.DataLayer.Ets` storage, real `Ash.Changeset.for_create` + `Ash.create!`,
  real PK reads. No mocks. The private ETS table is wiped between tests via
  real `Ash.bulk_destroy!` so tests stay order-independent.
  """
  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Marketplace.Pack

  setup do
    wipe()
    :ok
  end

  defp wipe do
    Pack
    |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
  end

  defp create!(attrs) do
    Pack
    |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  @create_attrs %{
    name: "aaif-vanilla-pack",
    version: "0.3.0",
    digest: "sha256:" <> String.duplicate("ab", 32),
    download_url: "https://example.com/pack.tar.gz",
    lifecycle_tier: "thin",
    readiness: "gates",
    description: "AAIF standards suite pack"
  }

  test "create + real PK read round-trips every v2 catalog field" do
    pack = create!(@create_attrs)

    assert pack.version == "0.3.0"
    assert pack.lifecycle_tier == "thin"
    assert pack.readiness == "gates"
    assert pack.pack_class == nil
    assert pack.ontology_fingerprint == nil
    assert pack.deprecated == false

    reread = Ash.get!(Pack, pack.name, authorize?: false)
    assert reread.digest == @create_attrs.digest
    assert reread.download_url == @create_attrs.download_url
    assert reread.description == "AAIF standards suite pack"
  end

  test "nullable v2 fields really round-trip when present" do
    pack =
      create!(
        Map.merge(@create_attrs, %{
          pack_class: "CapabilityPack",
          ontology_fingerprint: String.duplicate("cd", 32)
        })
      )

    reread = Ash.get!(Pack, pack.name, authorize?: false)
    assert reread.pack_class == "CapabilityPack"
    assert reread.ontology_fingerprint == String.duplicate("cd", 32)
  end

  test "name is mandatory" do
    assert {:error, %Ash.Error.Invalid{}} =
             Pack
             |> Ash.Changeset.for_create(:create, Map.delete(@create_attrs, :name),
               authorize?: false
             )
             |> Ash.create(authorize?: false)
  end

  test "missing description / digest / download_url are refused" do
    for dropped <- [:description, :digest, :download_url] do
      assert {:error, %Ash.Error.Invalid{}} =
               Pack
               |> Ash.Changeset.for_create(:create, Map.delete(@create_attrs, dropped),
                 authorize?: false
               )
               |> Ash.create(authorize?: false)
    end
  end

  test "deprecated defaults to false and can be set true" do
    assert create!(@create_attrs).deprecated == false

    assert create!(Map.merge(@create_attrs, %{name: "old-pack", deprecated: true})).deprecated ==
             true
  end
end
