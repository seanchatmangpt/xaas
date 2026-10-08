defmodule Xaas.Marketplace.PackCatalogDepthTest do
  @moduledoc """
  W984bo depth batch -- marketplace family, uncourted remainder.

  Covered elsewhere (excluded from this court's scope):
    * provider pre-approve lifecycle -- `provider_preapprove_lifecycle_test.exs`
      (W980i)
    * provider org read/create policy -- `provider_test.exs` (W733)
    * provider status-change approval guard -- `approval_provider_status_change_*`
      (W984u)
    * pack create/read round-trip + create refusals -- `pack_test.exs`
    * catalog ingest happy path / typed errors / idempotence --
      `catalog_test.exs`

  This file courts the uncourted remainder:
    1. the `update` branch of `Catalog.upsert_pack!/1` -- re-ingesting a
       catalog whose pack fields changed must really mutate the stored
       projection (not silently create a second row and not leave stale
       fields behind);
    2. readiness normalization variants (binary passthrough, mixed-flag map
       ordering); malformed readiness (nil/integer) is refused typed by
       validate_packs/1 since the W984ln repair -- see
       `catalog_court_w984kt_test.exs` leg 4;
    3. the `unique_name` identity on Pack via the real ETS pre-check;
    4. `Pack` destroy + `Catalog.get_pack!/1` raising on an absent name;
    5. `Catalog.search/1` matching on description substring
       case-insensitively when the name does not contain the term.

  Mutation rationale (W984bo): revert
  `upsert_pack!/1` in `lib/xaas/marketplace/catalog.ex` from
  `Ash.get -> for_update(:update)` to create-only (the pre-upsert
  implementation): courts 1 fails (stale `version`/`deprecated` after
  re-ingest, or an `InvalidAttribute` unique-name refusal on the second
  ingest). Delete the `identity(:unique_name, [:name])` block from
  `lib/xaas/marketplace/pack.ex`: court 3 fails (duplicate-name create
  succeeds). Change `pack_attrs/1` readiness to a constant: court 2 fails.
  Break `search/1` to drop the description clause: court 5 fails.
  """
  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Marketplace.Catalog
  alias Xaas.Marketplace.Pack

  setup do
    wipe()
    :ok
  end

  defp wipe do
    Pack |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
  end

  @digest "sha256:" <> String.duplicate("9f", 32)

  defp catalog_map(name, overrides \\ %{}) do
    %{
      "schema" => Catalog.catalog_schema_url(),
      "packs" => [
        Map.merge(
          %{
            "name" => name,
            "version" => "1.0.0",
            "digest" => @digest,
            "download_url" => "https://example.com/#{name}.tar.gz",
            "description" => "depth court pack #{name}",
            # W984bo finding, repaired (W984ln): a readiness that is neither a
            # map nor a binary (nil from an omitted key, integer, list, ...)
            # used to fall through readiness_string/1 to "" and raise a raw
            # Ash.Error.Invalid out of the upsert. validate_packs/1 now refuses
            # it typed BEFORE any upsert:
            # {:error, %Catalog.Error{reason: :invalid_pack,
            #  detail: {i, [:invalid_readiness], readiness}}}.
            # See docs/sjira/v26.10.6/plans/w984ln-repair.md.
            "readiness" => %{"gates" => true}
          },
          overrides
        )
      ]
    }
  end

  # -- court 1: the update branch of the upsert ------------------------------

  test "re-ingesting a changed catalog mutates the stored pack in place" do
    assert {:ok, 1} = Catalog.ingest(catalog_map("depth-pack"))

    changed =
      catalog_map("depth-pack", %{
        "version" => "2.0.0",
        "digest" => "sha256:" <> String.duplicate("7c", 32),
        "description" => "depth court pack, revised",
        "deprecated" => true
      })

    assert {:ok, 1} = Catalog.ingest(changed)

    names = Catalog.list_packs() |> Enum.map(& &1.name)
    assert names == ["depth-pack"], "upsert must not fork a second row"

    pack = Catalog.get_pack!("depth-pack")
    assert pack.version == "2.0.0"
    assert pack.digest == "sha256:" <> String.duplicate("7c", 32)
    assert pack.description == "depth court pack, revised"
    assert pack.deprecated == true
  end

  # -- court 2: readiness normalization variants ------------------------------

  test "readiness normalization: binary passthrough, false flags dropped, flag ordering" do
    assert {:ok, 2} =
             Catalog.ingest(%{
               "schema" => Catalog.catalog_schema_url(),
               "packs" => [
                 # binary passthrough of a pre-normalized readiness string
                 %{
                   "name" => "r-bin",
                   "version" => "1.0.0",
                   "digest" => @digest,
                   "download_url" => "https://example.com/r-bin.tar.gz",
                   "description" => "binary readiness",
                   "readiness" => "gates+witnesses"
                 },
                 # map form: false flags dropped, flags projected in the
                 # canonical @ready_flags order regardless of JSON key order
                 %{
                   "name" => "r-map",
                   "version" => "1.0.0",
                   "digest" => "sha256:" <> String.duplicate("9f", 32),
                   "download_url" => "https://example.com/r-map.tar.gz",
                   "description" => "map readiness",
                   "readiness" => %{"witnesses" => true, "gates" => true, "readme" => false}
                 }
               ]
             })

    assert Catalog.get_pack!("r-bin").readiness == "gates+witnesses"
    # canonical order gates<readme<verify<witnesses regardless of JSON key order
    assert Catalog.get_pack!("r-map").readiness == "gates+witnesses"
  end

  # -- court 3: unique_name identity ------------------------------------------

  test "duplicate pack name is refused by the real unique_name identity" do
    create_pack!("dup-pack")

    assert_raise Ash.Error.Invalid, ~r/has already been taken/, fn ->
      create_pack!("dup-pack")
    end

    names =
      Pack
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.name)

    assert names == ["dup-pack"], "identity must keep exactly one row"
  end

  # -- court 4: destroy + get_pack! on absent name ----------------------------

  test "destroy removes the row and get_pack! raises on the absent name" do
    pack = create_pack!("doomed-pack")
    assert :ok = Ash.destroy!(pack, authorize?: false)
    assert Catalog.list_packs() == []

    assert_raise Ash.Error.Invalid, fn ->
      Catalog.get_pack!("doomed-pack")
    end

    # the row is really gone from the store, not just hidden from get_pack!
    assert Pack
           |> Ash.Query.filter(name == "doomed-pack")
           |> Ash.read!(authorize?: false) == []
  end

  # -- court 5: description-only search ----------------------------------------

  test "search/1 matches description substring case-insensitively when name lacks the term" do
    create_pack!("totally-unrelated-name", %{
      description: "Kubernetes Operators for GRAIL Deployment"
    })
    create_pack!("another-pack", %{description: "plain pack"})

    hits = Catalog.search("grail") |> Enum.map(& &1.name)

    assert hits == ["totally-unrelated-name"]
  end

  # -- helpers ------------------------------------------------------------------

  defp create_pack!(name, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          name: name,
          version: "1.0.0",
          digest: @digest,
          download_url: "https://example.com/#{name}.tar.gz",
          lifecycle_tier: "thin",
          readiness: "gates",
          description: "depth court pack #{name}"
        },
        overrides
      )

    Pack
    |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
    |> Ash.create!(authorize?: false)
  end
end
