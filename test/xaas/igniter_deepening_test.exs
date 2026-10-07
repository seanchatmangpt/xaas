# Lane W734 — Xaas.Igniter domain deepening (PackManifest + RefusalCode, PW7).
#
# Chicago-style: real Ash actions on the private ETS resources, the REAL
# ggen_igniter refusals schema at Catalog.default_schema_path() as fixture,
# real ggen.toml/ggen.lock file reads for the cross-surface pin. No mocks.
#
# Honest typing (read-first results):
#   * The RefusalCode RESOURCE is open at the attribute level (code is a plain
#     writable string PK) — the typed-refusal closed-set discipline lives
#     upstream in ggen_igniter's refusals.schema.json and in
#     Xaas.Igniter.Catalog.ingest/1's validation, not in this resource. These
#     courts assert the real contract (open resource + typed upstream gate)
#     rather than fabricating a constraint the resource does not enforce.
#   * Duplicate PackManifest identity behavior is two-layered and both layers
#     are asserted: the resource identity refuses a raw second create;
#     Catalog.ingest_packs/1 upserts (update-in-place) and is idempotent.
defmodule Xaas.IgniterDeepeningTest do
  use ExUnit.Case, async: false

  alias Xaas.Igniter.Catalog
  alias Xaas.Igniter.PackManifest
  alias Xaas.Igniter.RefusalCode

  @schema_path Catalog.default_schema_path()

  setup do
    RefusalCode |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
    PackManifest |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
    :ok
  end

  defp real_schema, do: @schema_path |> File.read!() |> Jason.decode!()

  # ── (a) PackManifest ingest with a real pack structure ─────────────────────

  test "pack manifest ingest projects a real pack structure from ggen.toml's real pin" do
    # Real pack structure: the one pack xaas actually pins in ggen.toml.
    toml = File.read!(Path.expand("ggen.toml", File.cwd!()))

    assert Regex.run(~r/^\[packs\.([a-z0-9_]+)\]$/m, toml) != [],
           "ggen.toml must declare at least one [packs.*] pin for a real fixture"

    pack_names =
      Regex.scan(~r/^\[packs\.([a-z0-9_]+)\]$/m, toml)
      |> Enum.map(&Enum.at(&1, 1))

    manifest = %{
      "packs" =>
        Enum.map(pack_names, fn name ->
          %{
            "pack_name" => name,
            "version" => "26.10.6",
            "profile" => "projection",
            "gate_count" => 3,
            "verify_count" => 2,
            "misfiled_count" => 0
          }
        end)
    }

    n = length(pack_names)
    assert {:ok, ^n} = Catalog.ingest_packs(manifest)

    packs = Catalog.list_packs()
    assert length(packs) == length(pack_names)

    for name <- pack_names do
      pack = Enum.find(packs, &(&1.pack_name == name))
      assert %PackManifest{} = pack
      assert pack.version == "26.10.6"
      assert pack.profile == "projection"
      assert pack.gate_count == 3
      assert pack.verify_count == 2
      assert pack.misfiled_count == 0
    end
  end

  test "duplicate manifest identity: resource refuses raw re-create; Catalog upserts" do
    attrs = %{pack_name: "dup-pack", version: "1.0.0", profile: "project"}

    assert %PackManifest{} = PackManifest |> Ash.Changeset.for_create(:create, attrs, authorize?: false) |> Ash.create!(authorize?: false)

    # Layer 1 — resource identity (unique_pack_name, pre_check_with Ets)
    # refuses a second raw create of the same pack_name.
    assert {:error, %Ash.Error.Invalid{}} =
             PackManifest
             |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
             |> Ash.create()

    # Layer 2 — Catalog.ingest_packs upserts on pack_name (update in place).
    # String keys are the real ingest contract (JSON manifests decode to
    # string-keyed maps); atom-keyed entries are refused as invalid_manifest.
    assert {:ok, 1} =
             Catalog.ingest_packs([
               %{"pack_name" => "dup-pack", "version" => "2.0.0", "profile" => "projection", "gate_count" => 7}
             ])

    assert {:error, %Catalog.Error{reason: :invalid_manifest}} =
             Catalog.ingest_packs([%{pack_name: "atom-keys", version: "1"}])

    [row] = Catalog.list_packs()
    assert row.pack_name == "dup-pack"
    assert row.version == "2.0.0"
    assert row.profile == "projection"
    assert row.gate_count == 7
    assert row.verify_count == 0
  end

  test "update action accepts the mutable fields and never pack_name" do
    assert %PackManifest{} =
             PackManifest
             |> Ash.Changeset.for_create(:create, %{pack_name: "p1", version: "1"}, authorize?: false)
             |> Ash.create!(authorize?: false)

    row = Ash.get!(PackManifest, "p1", authorize?: false)

    assert %PackManifest{} =
             row
             |> Ash.Changeset.for_update(:update, %{version: "2", gate_count: 5}, authorize?: false)
             |> Ash.update!(authorize?: false)

    reloaded = Ash.get!(PackManifest, "p1", authorize?: false)
    assert reloaded.version == "2"
    assert reloaded.gate_count == 5

    # pack_name is not in the update accept list — feeding it is a real error.
    assert {:error, %Ash.Error.Invalid{}} =
             reloaded
             |> Ash.Changeset.for_update(:update, %{pack_name: "p2"}, authorize?: false)
             |> Ash.update()
  end

  # ── (b) RefusalCode vocabulary ──────────────────────────────────────────────

  test "refusal code create/read round-trips through real Ash actions" do
    attrs = %{
      code: "REFUSED_TEST_W734",
      family: "w734-test-family",
      retryable: true,
      broken_term: "mu_on_O",
      owner: "Xaas.IgniterDeepeningTest",
      fix_hint: "run the court again"
    }

    assert %RefusalCode{} =
             RefusalCode
             |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
             |> Ash.create!(authorize?: false)

    got = Ash.get!(RefusalCode, "REFUSED_TEST_W734", authorize?: false)
    assert got.family == "w734-test-family"
    assert got.retryable == true
    assert got.broken_term == "mu_on_O"
    assert got.owner == "Xaas.IgniterDeepeningTest"
    assert got.fix_hint == "run the court again"
    assert %DateTime{} = got.updated_at

    # duplicate code refused by resource identity (unique_code)
    assert {:error, %Ash.Error.Invalid{}} =
             RefusalCode
             |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
             |> Ash.create()
  end

  test "resource-level vocabulary is OPEN — typed closed-set discipline lives upstream (honest typing)" do
    # The resource accepts an arbitrary code string: it is a projection, not
    # the authority. Assert the real (open) contract instead of fabricating a
    # constraint that does not exist at this layer.
    assert %RefusalCode{} =
             RefusalCode
             |> Ash.Changeset.for_create(
               :create,
               %{code: "REFUSED_NOT_IN_ANY_SCHEMA", family: "arbitrary", retryable: false},
               authorize?: false
             )
             |> Ash.create!(authorize?: false)

    # The typed gate IS upstream: ingest validation refuses entries missing
    # required fields / with non-boolean retryable, and demands the $schema key.
    bad = %{"$schema" => "x", "refusals" => [%{"code" => "X", "family" => "f"}]}
    assert {:error, %Catalog.Error{reason: :invalid_refusal}} = Catalog.ingest(bad)

    bad2 = %{"$schema" => "x", "refusals" => [%{"code" => "X", "family" => "f", "retryable" => "yes"}]}
    assert {:error, %Catalog.Error{reason: :invalid_refusal}} = Catalog.ingest(bad2)

    assert {:error, %Catalog.Error{reason: :invalid_schema}} =
             Catalog.ingest(%{"refusals" => []})

    assert {:error, %Catalog.Error{reason: :invalid_json}} = Catalog.ingest("{not json")
  end

  test "ingesting the REAL upstream schema projects every code and field faithfully" do
    assert {:ok, count} = Catalog.ingest(@schema_path)

    schema = real_schema()
    assert count == length(schema["refusals"])

    for entry <- schema["refusals"] do
      row = Ash.get!(RefusalCode, entry["code"], authorize?: false)
      assert row.family == entry["family"]
      assert row.retryable == entry["retryable"]

      assert row.broken_term == (entry["broken_term"] || nil)

      assert row.owner == (entry["owner"] || nil)
      assert row.fix_hint == (entry["fix_hint"] || nil)
    end
  end

  # ── (c) cross-surface pin: xaas catalog ↔ upstream ggen_igniter store ──────

  test "the catalog's declared upstream store exists and is a parseable refusals schema" do
    assert File.regular?(@schema_path),
           "Catalog.default_schema_path() must point at the real ggen_igniter store"

    schema = real_schema()
    assert is_binary(schema["$schema"])
    assert is_list(schema["refusals"])
    assert schema["refusals"] != []
  end

  test "projected family set equals the upstream schema's family set" do
    {:ok, _} = Catalog.ingest(@schema_path)

    expected =
      real_schema()["refusals"] |> Enum.map(& &1["family"]) |> Enum.uniq() |> Enum.sort()

    got = Catalog.count_by_family() |> Enum.map(&elem(&1, 0))
    assert got == expected
  end

  test "xaas-side generated-file pins name the ggen_igniter renderer the catalog mirrors" do
    # The registry drift guard records that xaas's generated surfaces are
    # rendered by ggen_igniter / ggen-marketplace packs. Read the real file
    # and assert the pin surface is non-empty — the xaas igniter catalog is
    # the queryable projection of that same producer surface.
    source = File.read!(Path.expand("test/xaas/generated/registry_drift_guard_test.exs", File.cwd!()))

    assert source =~ ~r/ggen_igniter/,
           "registry drift guard must pin the ggen_igniter renderer"

    assert source =~ ~r/ggen-marketplace/,
           "registry drift guard must pin the ggen-marketplace pack source"
  end

  # ── (d) determinism ─────────────────────────────────────────────────────────

  test "re-ingest is idempotent and the projection is byte-stable across reads" do
    {:ok, c1} = Catalog.ingest(@schema_path)
    projection1 = Catalog.list_refusals()

    {:ok, c2} = Catalog.ingest(@schema_path)
    projection2 = Catalog.list_refusals()

    assert c1 == c2
    assert projection1 == projection2

    assert projection1 == Enum.sort_by(projection1, & &1.code)

    snapshot =
      projection1
      |> Enum.map(&{&1.code, &1.family, &1.retryable, &1.broken_term, &1.owner, &1.fix_hint})
      |> Enum.sort()

    assert snapshot ==
             Catalog.list_refusals()
             |> Enum.map(&{&1.code, &1.family, &1.retryable, &1.broken_term, &1.owner, &1.fix_hint})
             |> Enum.sort()

    # family histogram is deterministic too
    assert Catalog.count_by_family() == Catalog.count_by_family()
  end

  test "pack ingest is idempotent and list order is deterministic" do
    manifest = [
      %{"pack_name" => "b-pack", "version" => "1"},
      %{"pack_name" => "a-pack", "version" => "2"},
      %{"pack_name" => "c-pack", "version" => "3"}
    ]

    assert {:ok, 3} = Catalog.ingest_packs(manifest)
    assert {:ok, 3} = Catalog.ingest_packs(manifest)

    names = Catalog.list_packs() |> Enum.map(& &1.pack_name)
    assert names == Enum.sort(names)
  end
end
