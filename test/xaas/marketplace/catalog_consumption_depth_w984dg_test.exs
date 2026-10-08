defmodule Xaas.Marketplace.CatalogConsumptionDepthW984dgTest do
  @moduledoc """
  Lane W984dg — Marketplace Catalog consumption depth court (coverage burn-down,
  v26.10.6 campaign). Real Chicago-style courts over `Xaas.Marketplace.Catalog`
  branches the existing `catalog_test.exs` does not execute:

    * the upsert UPDATE branch (same name, new fields — no duplicate row),
    * the `lifecycle_tier` / `tier` / `"unclassified"` fallback chain,
    * binary (non-map) `readiness` passthrough,
    * description-based, case-insensitive `search/1` (name-only mutant killed),
    * typed refusals at the real boundary: nonexistent path treated as raw
      JSON (`:invalid_json`), and `get_pack!/1` raising on an absent name.

  No mocks — real Postgres rows via the sandbox, real typed errors. Each test
  names the mutation it kills.
  """

  use ExUnit.Case, async: false

  alias Xaas.Marketplace.Catalog
  alias Xaas.Marketplace.Pack

  setup do
    Pack |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
    :ok
  end

  defp pack(name, overrides \\ %{}) do
    Map.merge(
      %{
        "name" => name,
        "version" => "1.0.0",
        "digest" => "sha256:" <> String.duplicate("ab", 32),
        "download_url" => "https://example.com/#{name}.tar.gz",
        "description" => "hand-built depth-court pack",
        # KNOWN DEFECT (W984bo finding, reproduced by this lane): omitting
        # "readiness" entirely makes Catalog.ingest raise a raw
        # Ash.Error.Invalid ("attribute readiness is required") instead of a
        # typed {:error, %Catalog.Error{}}. Supplied on every pack so the
        # courts below exercise their intended branches.
        "readiness" => %{"gates" => true}
      },
      overrides
    )
  end

  defp catalog(packs),
    do: %{"schema" => Catalog.catalog_schema_url(), "packs" => packs}

  test "upsert UPDATE branch: re-ingesting a pack under the same name updates fields in place (kills always-create duplicate mutant)" do
    assert {:ok, _} =
      Catalog.ingest(catalog([pack("mutant-bait", %{"version" => "1.0.0", "tier" => "thin"})]))

    assert {:ok, _} =
      Catalog.ingest(
        catalog([
          pack("mutant-bait", %{
            "version" => "2.0.0",
            "digest" => "sha256:" <> String.duplicate("cd", 32),
            "description" => "updated description v2",
            "deprecated" => true
          })
        ])
      )

    names = Catalog.list_packs() |> Enum.map(& &1.name)
    assert names == ["mutant-bait"], "expected in-place update, got rows: #{inspect(names)}"

    updated = Catalog.get_pack!("mutant-bait")
    assert updated.version == "2.0.0"
    assert updated.digest == "sha256:" <> String.duplicate("cd", 32)
    assert updated.description == "updated description v2"
    assert updated.deprecated == true
  end

  test "lifecycle_tier fallback chain: lifecycle_tier beats tier; absent both yields unclassified (kills swapped/removed fallback mutant)" do
    assert {:ok, _} =
      Catalog.ingest(
        catalog([
          pack("tier-both", %{"lifecycle_tier" => "thin", "tier" => "core"}),
          pack("tier-neither")
        ])
      )

    assert Catalog.get_pack!("tier-both").lifecycle_tier == "thin"

    assert Catalog.get_pack!("tier-neither").lifecycle_tier == "unclassified"
  end

  test "binary readiness passthrough: a string readiness is stored verbatim, not flag-joined (kills forced-map-readiness mutant)" do
    assert {:ok, _} =
      Catalog.ingest(
        catalog([pack("readiness-str", %{"readiness" => "gates+readme+witnesses"})])
      )

    assert Catalog.get_pack!("readiness-str").readiness == "gates+readme+witnesses"
  end

  test "search/1 matches description case-insensitively, not just name (kills name-only search mutant)" do
    assert {:ok, _} =
      Catalog.ingest(
        catalog([
          pack("zzz-opaque-name", %{"description" => "Specialized GRAFANA Dashboarding"}),
          pack("zzz-other", %{"description" => "unrelated"})
        ])
      )

    hits = Catalog.search("grafana") |> Enum.map(& &1.name)
    assert hits == ["zzz-opaque-name"], "description search failed: #{inspect(hits)}"

    # exact full-name match still resolves
    assert [%{name: "zzz-other"}] = Catalog.search("zzz-other")

    # no match -> real empty list
    assert [] = Catalog.search("nonexistent-entropy")
  end

  test "typed refusals at the real boundary: nonexistent path is raw JSON -> :invalid_json; get_pack! on absent name raises NotFound" do
    assert {:error, %Catalog.Error{reason: :invalid_json}} =
             Catalog.ingest("/nonexistent/w984dg/no-such-catalog.json")

    # Ash.get!/1 surfaces the NotFound inside the Invalid error class
    # (observed at the real surface, matches the landed W984bo court).
    assert_raise Ash.Error.Invalid, fn ->
      Catalog.get_pack!("never-ingested-pack")
    end
  end
end
