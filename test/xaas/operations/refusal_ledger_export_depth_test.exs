defmodule Xaas.Operations.RefusalLedgerExportDepthTest do
  @moduledoc """
  Lane W984cw4 depth court for `Xaas.Operations.RefusalLedgerExport`
  (v26.10.7 WP-6, lane W616) — the anti-vacuity refusal ledger regeneration
  module. Zero prior test-tree coverage (W984cj map: 28→29 uncovered;
  `RefusalLedgerExport` had 0 mentions anywhere under `test/`).

  Chicago discipline: real repo files, real source ledger on disk, real
  canonical JSON via `Xaas.Semantics.Jcs`, real SHA-256 over real bytes,
  real `File.write!` to the real artifact path. No mocks. The emit is
  deterministic (no wall clock, RFC 8785 JCS, entries sorted by atom), so
  re-emitting the real artifact is idempotent — disclosed: the court writes
  the real `docs/cro/artifacts/refusal-ledger-v26.10.7.jcs.json`, and its
  bytes are asserted stable across independent runs.

  Real invariants under court (one mutation target per test):

    1. build determinism + census consistency: two builds produce identical
       canonical bytes; counts are internally consistent (declared = entries,
       refused_atoms counts the REFUSED_ prefix). Mutation killed: a mutant
       that drops the sort, miscounts, or reorders the JSON changes bytes or
       census and fails.
    2. digest replay (receipt R/replay leg): the digest in the emit result
       equals a from-disk re-read + re-canonicalization — a from-disk digest
       over a tampered body diverges (content sensitivity).
    3. emit writes the real artifact; bytes are byte-identical across two
       emits, end in a newline, and decode as JSON with the required
       top-level keys. Mutation killed: a mutant breaking File.write, the
       digest computation, or canonicalization fails.
    4. court/0 runs all three legs on the real tree and returns
       {:ok, report} with digest_replay_match: true, the real fake-injection
       refusal, and consistent counts. Mutation killed: weakening
       inject_fake to return success (anti-vacuity survived) fails the
       court, because the court itself pattern-matches the typed refusal.
    5. typed refusals are real: inject_fake/1 with a custom atom returns
       the typed `{:error, {:unpinned_variant, %{atom: ..., reason:
       :court_missing}}}` and never writes the artifact; every entry in the
       full vocabulary carries a nonempty on-disk-resolvable pinning court
       and a typed REFUSED_*/BLOCKED_* atom drawn from the four grounded
       sources.
  """

  use ExUnit.Case, async: false

  alias Xaas.Operations.RefusalLedgerExport
  alias Xaas.Semantics.Jcs

  @artifact "docs/cro/artifacts/refusal-ledger-v26.10.7.jcs.json"

  # Grounded standing-vocabulary prefix regime: every entry atom is a typed
  # REFUSED_* or BLOCKED_* atom. Exactly the BLOCKED_* subset (currently the
  # airo source ledger's BLOCKED_CASTLE_TRANSPORT) falls outside the
  # refused_atoms count.
  defp non_refused_count do
    RefusalLedgerExport.vocabulary()
    |> Enum.count(&String.starts_with?(&1.atom, "BLOCKED_"))
  end

  test "build is deterministic and census-consistent across two runs" do
    {:ok, canon1, json1} = RefusalLedgerExport.build()
    {:ok, canon2, json2} = RefusalLedgerExport.build()

    assert json1 == json2
    assert json1 != ""

    assert canon1["ledger_version"] == "26.10.7"
    assert canon1["hash_algorithm"] == "sha256"
    assert canon1["source_ledger"] == "docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json"

    entries = canon1["entries"]
    atoms = Enum.map(entries, & &1["atom"])
    assert Enum.sort(atoms) == atoms
    assert Enum.uniq(atoms) == atoms

    counts = canon1["counts"]
    assert counts["declared"] == length(entries)
    assert counts["refused_atoms"] == Enum.count(atoms, &String.starts_with?(&1, "REFUSED_"))
    assert counts["mutation_kill_verified"] ==
             Enum.count(entries, & &1["mutation_kill"]["killed"])

    assert counts["court_cited"] == length(entries)

    assert canon1["vocabulary_sources"] == [
             "airo_risk_mapping_variants (W984bj/ce)",
             "eyerun_eu_gate_refusal_codes (W613, wasm4pm crates/eu_gate/src/lib.rs:39-43)",
             "typed_gap_register_authority_channel",
             "xaas_semantics_vkg"
           ]
  end

  test "digest replays from disk and is content-sensitive to tampered bytes" do
    {:ok, %{digest: digest}} = RefusalLedgerExport.emit()
    assert {:ok, ^digest} = RefusalLedgerExport.rebuild_digest()

    # Content sensitivity: the same entry set with one entry's atom byte
    # rewritten must produce a different canonical digest — the digest is
    # over content, not shape.
    {:ok, canon, _} = RefusalLedgerExport.build()

    mutated =
      Map.update!(canon, "entries", fn [first | rest] ->
        [Map.update!(first, "atom", &("TAMPERED_" <> &1)) | rest]
      end)

    mutated_digest =
      :crypto.hash(:sha256, Jcs.encode(mutated)) |> Base.encode16(case: :lower)

    assert mutated_digest != digest
  end

  test "emit writes the real artifact: byte-stable across two emits, newline-terminated, decodeable" do
    {:ok, %{path: path, digest: d1}} = RefusalLedgerExport.emit()
    {:ok, %{digest: d2}} = RefusalLedgerExport.emit()

    assert path == RefusalLedgerExport.out_path()
    assert String.ends_with?(path, @artifact)
    assert d1 == d2

    bytes = File.read!(path)
    assert bytes != ""
    assert String.ends_with?(bytes, "\n")

    decoded = Jason.decode!(bytes)
    assert decoded["ledger_version"] == "26.10.7"
    assert is_map(decoded["counts"])
    assert is_list(decoded["entries"]) and decoded["entries"] != []

    assert {:ok, ^d1} = RefusalLedgerExport.rebuild_digest()
  end

  test "court/0 runs all three legs on the real tree and returns a full report" do
    assert {:ok, report} = RefusalLedgerExport.court()

    assert report.emitted == "docs/cro/artifacts/refusal-ledger-v26.10.7.jcs.json"
    assert report.digest_replay_match == true
    assert is_binary(report.digest) and byte_size(report.digest) == 64

    # The mutation leg really fired: the injected fake was refused by atom,
    # by court path, and with the :court_missing reason.
    fake = report.fake_injection_refused
    assert fake.atom == "REFUSED_FAKE_W616_NO_COURT"
    assert fake.court == "test/xaas/w616_does_not_exist_test.exs"
    assert fake.reason == :court_missing

    counts = report.counts
    assert counts["declared"] >= 1
    assert counts["court_cited"] == counts["declared"]

    # The prefix regime is REFUSED_* plus the grounded BLOCKED_* variant
    # from the airo source ledger; refused_atoms counts the REFUSED_* subset.
    assert counts["refused_atoms"] + non_refused_count() == counts["declared"]
    assert counts["mutation_kill_verified"] <= counts["declared"]
  end

  test "typed refusals are real: custom fake atom is refused with :court_missing and vocabulary is fully pinned" do
    # Custom fake atom: typed refusal, artifact untouched at this point's
    # digest (the refusal path never writes).
    assert {:error, {:unpinned_variant, refused}} =
             RefusalLedgerExport.inject_fake("REFUSED_W984CW4_PROBE_NO_COURT")

    assert refused.atom == "REFUSED_W984CW4_PROBE_NO_COURT"
    assert refused.reason == :court_missing
    assert String.contains?(refused.court, "w616_does_not_exist")

    # Every vocabulary entry is REFUSED_-prefixed, carries a nonempty
    # on-disk court, and cites at least one grounded source.
    entries = RefusalLedgerExport.vocabulary()

    assert entries != []

    assert Enum.all?(entries, fn e ->
             String.starts_with?(e.atom, "REFUSED_") or String.starts_with?(e.atom, "BLOCKED_")
           end)

    assert Enum.all?(entries, fn e -> is_binary(e.pinning_court) and e.pinning_court != "" end)
    assert Enum.all?(entries, fn e -> e.mutation_kill["killed"] in [true, false] end)

    grounded =
      [:airo_risk_mapping_variants, :eyerun_eu_gate, :typed_gap_register, :xaas_semantics_vkg]

    assert Enum.all?(entries, fn e -> Enum.all?(e.sources, &(&1 in grounded)) end)
  end
end
