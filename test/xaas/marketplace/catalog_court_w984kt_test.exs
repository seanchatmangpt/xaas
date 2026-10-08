defmodule Xaas.Marketplace.CatalogCourtW984ktTest do
  @moduledoc """
  Lane W984kt — unclaimed-family probe court over `Xaas.Marketplace.Catalog`.

  Disposition: W984dg's consumption-depth court exists on disk but is
  UNTRACKED (never landed); the landed `catalog_test.exs` covers the
  schema/pack-validation happy + refusal paths and the tagged real-generator
  path. This court executes the branches NEITHER file reaches:

    * the `ingest/1` catch-all `other` clause (non-map/non-binary input, and a
      map whose `"packs"` value is not a list) — typed `:invalid_catalog` with
      the raw input passed through as detail,
    * a catalog with NO `"schema"` key — detail `{:unexpected_schema, nil}`,
    * `validate_packs` non-binary-name refusal (`missing == []` but
      `is_binary(name)` false) — the second half of the validity conjunction,
    * `readiness_string/1` receiving a non-map, non-binary value → `""`,
    * the real FILE-PATH ingest branch (`File.regular?` true → `File.read/1`),
      self-contained via a tmp file (the landed test's path branch is
      `@tag :real_marketplace_catalog`, excluded from default runs and
      dependent on an external checkout),
    * `search/1` substring-of-name branch (`contains(name)` without full-name
      equality) and `list_packs/0` name ordering,
    * `ontology_fingerprint_sha256` passthrough + `deprecated` default false.

  Chicago discipline: real Postgres rows via the sandbox, a real tmp file on
  disk, real typed errors. Zero mocks. Each test names the mutation it kills.
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
        "description" => "w984kt probe pack",
        "readiness" => %{"gates" => true}
      },
      overrides
    )
  end

  defp catalog(packs, schema \\ Catalog.catalog_schema_url()),
    do: %{"schema" => schema, "packs" => packs}

  test "ingest/1 catch-all: a non-map non-binary input is a typed :invalid_catalog carrying the raw input as detail (kills crash-on-other-type and detail-dropping mutants)" do
    assert {:error, %Catalog.Error{reason: :invalid_catalog, detail: 42}} =
             Catalog.ingest(42)

    assert {:error, %Catalog.Error{reason: :invalid_catalog, detail: [:a, :b]}} =
             Catalog.ingest([:a, :b])
  end

  test "ingest/1 catch-all: a map WITHOUT a list \"packs\" value falls through to :invalid_catalog (kills packs-key-guard-removal mutant)" do
    # map without "packs" at all
    assert {:error, %Catalog.Error{reason: :invalid_catalog, detail: detail}} =
             Catalog.ingest(%{"schema" => Catalog.catalog_schema_url()})

    # the clause head pattern {"packs" => packs} is a guard is_list(packs),
    # so a non-list packs value must also miss it and land in `other`
    assert {:error, %Catalog.Error{reason: :invalid_catalog}} =
             Catalog.ingest(%{"schema" => Catalog.catalog_schema_url(), "packs" => "not-a-list"})
  end

  test "ingest/1 with NO schema key refuses with detail {:unexpected_schema, nil} (kills nil-schema-crash and schema-optional mutants)" do
    # valid packs, but schema key absent entirely
    bad = %{"packs" => []}

    assert {:error,
            %Catalog.Error{reason: :invalid_catalog, detail: {:unexpected_schema, nil}}} =
             Catalog.ingest(bad)
  end

  test "validate_packs refuses a pack whose name is present but not a binary (kills is_binary-name-check-removal mutant)" do
    bad =
      catalog([
        pack(42, %{"name" => 42})
      ])

    assert {:error, %Catalog.Error{reason: :invalid_pack, detail: {0, [], 42}}} =
             Catalog.ingest(bad)

    # nothing leaked into the projection
    assert Catalog.list_packs() == []
  end

  test "readiness that is neither map nor binary is refused typed :invalid_pack (W984ln repair of the W984bo-class raw-raise defect; kills fallthrough-restoration mutants)" do
    # W984ln repair: readiness_string/1's "" fallthrough used to let a raw
    # Ash.Error.Invalid escape ingest/1 (W984bo-class defect). validate_packs
    # now refuses non-map, non-binary readiness as a typed
    # {:error, %Catalog.Error{reason: :invalid_pack}} before any upsert runs.
    assert {:error, %Catalog.Error{reason: :invalid_pack, detail: {0, [:invalid_readiness], 7}}} =
             Catalog.ingest(catalog([pack("readiness-int", %{"readiness" => 7})]))

    # nil (including an entirely absent readiness key) is refused typed too
    assert {:error, %Catalog.Error{reason: :invalid_pack, detail: {0, [:invalid_readiness], nil}}} =
             Catalog.ingest(catalog([pack("readiness-null", %{"readiness" => nil})]))

    # nothing leaked into the projection
    assert Catalog.list_packs() == []
  end

  test "real file-path ingest: an existing on-disk catalog file is read and ingested (kills File.regular?-branch-inversion mutant) " do
    path = Path.join(System.tmp_dir(), "w984kt-catalog-#{:erlang.unique_integer([:positive])}.json")

    body =
      Jason.encode!(catalog([
        pack("from-real-file", %{
          "ontology_fingerprint_sha256" => "fp-" <> String.duplicate("1f", 16)
        })
      ]))

    File.write!(path, body)

    on_exit(fn -> File.rm(path) end)

    assert {:ok, 1} = Catalog.ingest(path)

    stored = Catalog.get_pack!("from-real-file")
    assert stored.ontology_fingerprint == "fp-" <> String.duplicate("1f", 16)
    # deprecated absent -> default false (kills forced-deprecated mutant)
    assert stored.deprecated == false
  end

  test "search/1 substring-of-name branch matches a partial name, and list_packs/0 returns packs sorted by name (kills name-equality-only-search and sort-dropped mutants)" do
    assert {:ok, _} =
             Catalog.ingest(
               catalog([
                 pack("beta-vector-store"),
                 pack("alpha-index"),
                 pack("gamma-unrelated")
               ])
             )

    # "vector" is a strict substring of the name — not a full-name equality hit,
    # not present in any description
    hits = Catalog.search("vector") |> Enum.map(& &1.name)
    assert hits == ["beta-vector-store"]

    # list_packs sorts by name regardless of insertion order
    assert [%{name: "alpha-index"}, %{name: "beta-vector-store"}, %{name: "gamma-unrelated"}] =
             Catalog.list_packs()
  end
end
