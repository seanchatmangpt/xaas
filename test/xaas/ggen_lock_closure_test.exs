# Lane W700 — ggen gap absorption: lock/receipt closure gate.
#
# ggen proven machinery mirrored here (audit 2026-10-06):
#   * ggen.lock is the generated pin of every [packs.X] in ggen.toml —
#     ggen's sync-drift and verify-tcps legs refuse lock/manifest divergence
#     (FM-PACK-008 pack-content pinning). xaas had ggen.lock +
#     .ggen-v2/receipt-portable.json on disk but NO test binding them.
#   * ggen `receipt verify` checks the .ggen-v2/receipt-log.jsonl hash chain
#     (each record's prev_chain_hash_hex == previous record's chain_hash_hex).
#     xaas had the log but no chain-linkage verifier.
#
# Chicago discipline: real files on disk, real parsing, assert on real state.
# A legit `ggen sync run` that changes the pin must re-pin NOTHING here — this
# test reads consistency, not frozen content (registry_drift_guard_test.exs
# owns frozen-content pins for generated files).
defmodule Xaas.GgenLockClosureTest do
  use ExUnit.Case, async: true

  @ggen_toml Path.expand("ggen.toml", File.cwd!())
  @lock Path.expand("ggen.lock", File.cwd!())
  @receipt_portable Path.expand(".ggen-v2/receipt-portable.json", File.cwd!())
  @receipt_log Path.expand(".ggen-v2/receipt-log.jsonl", File.cwd!())

  # ── ggen.lock ↔ ggen.toml pin closure ──────────────────────────────────────

  test "every ggen.toml pack pin is locked with the exact pinned SHA and pack dir" do
    toml = File.read!(@ggen_toml)
    lock = File.read!(@lock)

    toml_pins = parse_toml_pack_pins(toml)
    lock_entries = parse_lock_packs(lock)

    assert toml_pins != [], "no [packs.*] sections parsed from ggen.toml"
    assert MapSet.new(Map.keys(toml_pins)) == MapSet.new(Map.keys(lock_entries)),
           "ggen.lock and ggen.toml disagree on the pack set: " <>
             "toml=#{Map.keys(toml_pins)} lock=#{Map.keys(lock_entries)}"

    for {name, pin} <- toml_pins do
      assert pin.git =~ ~r|^https://|,
             "pack #{name}: git source must be an https URL"

      assert pin.version =~ ~r/^[0-9a-f]{40}$/,
             "pack #{name}: version must be a 40-hex producer SHA, got #{pin.version}"

      entry = Map.fetch!(lock_entries, name)

      assert entry.source ==
               "git:#{pin.git}@#{pin.version}##{pin.subdir}",
             "pack #{name}: ggen.lock source #{entry.source} does not match " <>
               "ggen.toml pin (git=#{pin.git} sha=#{pin.version} subdir=#{pin.subdir})"

      assert entry.content_hash =~ ~r/^blake3:[0-9a-f]{64}$/,
             "pack #{name}: lock content_hash must be blake3:<64 hex>, got #{entry.content_hash}"
    end
  end

  test "lock has no orphaned pack entries absent from ggen.toml" do
    # covered structurally by the set-equality assertion above; this test
    # exists so the failure message names the orphan direction explicitly.
    toml_pins = parse_toml_pack_pins(File.read!(@ggen_toml))
    lock_entries = parse_lock_packs(File.read!(@lock))

    orphans = MapSet.difference(MapSet.new(Map.keys(lock_entries)), MapSet.new(Map.keys(toml_pins)))
    assert MapSet.to_list(orphans) == [],
           "ggen.lock pins packs ggen.toml no longer declares: #{inspect(orphans)}"
  end

  # ── ggen receipt chain verification (mirrors `ggen receipt verify`) ────────

  test "receipt-log.jsonl is a well-formed, chain-linked receipt DAG" do
    lines =
      @receipt_log
      |> File.read!()
      |> String.split("\n", trim: true)

    assert lines != [], "receipt log is empty — run `ggen sync run` to mint one"

    records =
      for line <- lines do
        assert {:ok, rec} = Jason.decode(line), "receipt-log line is not valid JSON"
        assert %{"record" => %{"chain_hash_hex" => _, "prev_chain_hash_hex" => _}} = rec
        rec["record"]
      end

    first = hd(records)
    assert first["prev_chain_hash_hex"] == String.duplicate("0", 64),
           "first receipt record must anchor the chain at 64 zeros"

    records
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [prev, curr] ->
      assert curr["prev_chain_hash_hex"] == prev["chain_hash_hex"],
             "receipt chain broken: record chain_hash #{String.slice(prev["chain_hash_hex"] || "", 0, 12)} " <>
               "does not feed the next record's prev_chain_hash"
    end)
  end

  # ── receipt-portable.json 5-field receipt surface ──────────────────────────

  test "receipt-portable.json carries the required receipt fields with ALIVE standing" do
    assert {:ok, receipt} =
             @receipt_portable
             |> File.read!()
             |> Jason.decode()

    for field <- ["spec", "subject", "standing", "consequences", "replay"] do
      assert Map.has_key?(receipt, field),
             "receipt-portable.json missing required receipt field: #{field}"
    end

    assert receipt["standing"] == "ALIVE",
           "lock-closure receipt standing must be ALIVE, got #{receipt["standing"]}"

    subject = receipt["subject"]
    assert subject["pack"] != nil and subject["pack_digest"] != nil

    assert subject["pack_digest"] =~ ~r/^sha256:[0-9a-f]{64}$/,
           "subject pack_digest must be sha256:<64 hex>, got #{subject["pack_digest"]}"
  end

  # ── declared sync inputs exist on disk ──────────────────────────────────────

  test "declared ontology source and template dir exist" do
    toml = File.read!(@ggen_toml)

    ontology_source =
      case Regex.run(~r/^\[ontology\]\s*$\n^source\s*=\s*"([^"]+)"/m, toml) do
        [_, src] -> src
        nil -> flunk("ggen.toml has no [ontology] source declaration")
      end

    assert File.exists?(Path.expand(ontology_source, File.cwd!())),
           "declared ontology source #{ontology_source} is missing from the repo"

    assert Regex.named_captures(~r/^\[templates\]\s*$\n^dir\s*=\s*"(?<dir>[^"]+)"/m, toml) ||
             flunk("ggen.toml has no [templates] dir declaration")
  end

  # ── minimal TOML section parsing (ggen.toml/ggen.lock are simple tables) ───

  defp parse_toml_pack_pins(toml) do
    toml
    |> String.split(~r/^$|(?=\n\[)/m)
    |> Enum.reduce(%{}, fn section, acc ->
      case Regex.run(~r/^\[packs\.([A-Za-z0-9_]+)\]\s*$/, section) do
        [_, name] -> Map.put(acc, name, parse_pack_fields(section))
        nil -> acc
      end
    end)
  end

  defp parse_pack_fields(section) do
    git = fetch_kv(section, "git")
    version = fetch_kv(section, "version")
    subdir = fetch_kv(section, "subdir")

    assert git and version and subdir,
           "ggen.toml pack pin missing git/version/subdir: #{inspect(section)}"

    %{git: git, version: version, subdir: subdir}
  end

  defp parse_lock_packs(lock) do
    lock
    |> String.split(~r/(?=\n\[)/m)
    |> Enum.reduce(%{}, fn section, acc ->
      case Regex.run(~r/^\[packs\.([A-Za-z0-9_]+)\]\s*$/, section) do
        [_, name] -> Map.put(acc, name, %{source: fetch_kv(section, "source"), content_hash: fetch_kv(section, "content_hash")})
        nil -> acc
      end
    end)
  end

  defp fetch_kv(section, key) do
    case Regex.run(Regex.compile!("^" <> key <> "\\s*=\\s*\"([^\"]*)\"", "m"), section) do
      [_, v] -> v
      nil -> nil
    end
  end
end
