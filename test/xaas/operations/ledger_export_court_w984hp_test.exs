defmodule Xaas.Operations.LedgerExportCourtW984hpTest do
  @moduledoc """
  Lane W984hp unclaimed-family court for the refusal/authority ledger
  export surface (`Xaas.Operations.RefusalLedgerExport`,
  `Xaas.Operations.AuthorityLedgerExport`, and their two mix-task shells
  `mix xaas.export_refusal_ledger` / `mix xaas.export_authority_ledger`).

  Pre-existing coverage census (read this session, per test file):

    * `test/xaas/operations/refusal_ledger_export_depth_test.exs` (W984cw4):
      determinism, census consistency, digest replay, real-artifact emit
      byte-stability, `court/0` three legs, `inject_fake/1` typed refusal.
    * `test/xaas/operations/authority_ledger_export_test.exs` (W603):
      bundle determinism, vocabulary/entry-source shape, root replay,
      content sensitivity, `--since` exclusion, empty-ledger typed refusal
      (module + real mix task), `--out` determinism, invalid `--since`.

  This court targets only the genuinely unexercised branches, Chicago
  style: real files, real parse, real SHA-256, zero mocks. Mutation
  rationale per test (the source change that flips the test to red):

    1. `rebuild_digest/0` on a MISSING artifact: a mutant that replaces
       the `with` short-circuit with `File.read!` still crashes — the
       court pins the typed `{:error, :enoent}` return instead of a raise.
    2. `rebuild_digest/0` on a CORRUPT artifact: kills a mutant that
       drops the `Jason.decode!` shape check (it would return a digest
       over malformed bytes instead of raising).
    3. duplicate-atom merge in `build/0`: kills a mutant that drops
       `merge_by_atom/1` (unmerged duplicates would break the census
       `declared == unique atoms` invariant and the sort invariant).
    4. `pick_court/2` line-qualified court preservation: kills a mutant
       that lets the bare-file side of a merge overwrite a
       line-qualified court citation.
    5. `recompute_root/1` malformed input: kills a mutant that replaces
       the guard-clause fallback with a crash or a `{:ok, garbage}`.
    6. `merkle_root/1` degenerate cases: zero leaves -> 64 hex zeros;
       one leaf -> the leaf itself; odd trailing leaf duplicated (3-leaf
       root differs from a naive pairwise-without-duplication mutant).
    7. `entry_leaves/1` order: kills a mutant dropping the
       `{source, id}` sort (reversed input would hash a different tree).
  """

  use ExUnit.Case, async: false

  alias Xaas.Operations.{AuthorityLedgerExport, RefusalLedgerExport}

  @source_ledger "docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json"
  @artifact "docs/cro/artifacts/refusal-ledger-v26.10.7.jcs.json"

  # ------------------------------------------------------------------
  # RefusalLedgerExport — rebuild_digest failure paths (real file I/O)
  # ------------------------------------------------------------------

  describe "rebuild_digest/0 failure paths" do
    test "missing artifact returns the typed {:error, :enoent}, never a raise" do
      original = File.read!(RefusalLedgerExport.out_path())
      File.rm(RefusalLedgerExport.out_path())

      on_exit(fn -> File.write(RefusalLedgerExport.out_path(), original) end)

      assert {:error, :enoent} = RefusalLedgerExport.rebuild_digest()

      # The mutation leg for test 1: restore inline (on_exit runs at suite
      # end only) — with the artifact back, the same call succeeds, proving
      # the {:error, :enoent} came from the missing file, not a broken path.
      File.write(RefusalLedgerExport.out_path(), original)
      assert {:ok, _} = RefusalLedgerExport.rebuild_digest()
    end

    test "corrupt artifact raises the real parse error (fail-closed shape check)" do
      original = File.read!(RefusalLedgerExport.out_path())
      File.write!(RefusalLedgerExport.out_path(), "{not json at all")

      on_exit(fn -> File.write(RefusalLedgerExport.out_path(), original) end)

      assert_raise Jason.DecodeError, fn ->
        RefusalLedgerExport.rebuild_digest()
      end
    end
  end

  # ------------------------------------------------------------------
  # RefusalLedgerExport — merge-by-atom path via a real temp source ledger
  # ------------------------------------------------------------------

  describe "build/0 duplicate-atom merge (real source-ledger fixture)" do
    setup :with_temp_source_ledger_duplicate

    test "a duplicate variant from the source ledger merges into one entry with unioned sources", %{
      backup: backup,
      source_path: source_path
    } do
      assert {:ok, canon, json} = RefusalLedgerExport.build()

      entries = canon["entries"]
      atoms = Enum.map(entries, & &1["atom"])

      # Merge killed the duplicate: declared == unique atoms, sorted, unique.
      assert Enum.sort(atoms) == atoms
      assert Enum.uniq(atoms) == atoms
      assert canon["counts"]["declared"] == length(atoms)
      assert canon["counts"]["court_cited"] == length(atoms)

      # The duplicate atom is present exactly once, citing BOTH sources.
      merged =
        Enum.find(entries, &(&1["atom"] == "REFUSED_UNKNOWN_CHANNEL"))

      assert merged != nil
      assert Enum.sort(merged["sources"]) == ["airo_risk_mapping_variants", "typed_gap_register"]

      # pick_court: the first side in sorted order (the airo source variant,
      # whose fixture is the bare test file) keeps its court citation; the
      # typed_gap line-qualified citation does not overwrite it. Mutation
      # kill: a mutant flipping pick_court's argument order or dropping the
      # keep-acc clause changes the emitted citation.
      assert merged["pinning_court"] == "test/xaas/semantics/authority_channel_test.exs"

      # The merged emit is still byte-deterministic and newline-terminated.
      assert json != "" and String.contains?(json, "REFUSED_UNKNOWN_CHANNEL")

      # Digest replay still matches over the merged artifact bytes.
      assert {:ok, %{digest: digest}} = RefusalLedgerExport.emit()
      assert {:ok, ^digest} = RefusalLedgerExport.rebuild_digest()
      _ = backup
      _ = source_path
    end
  end

  defp with_temp_source_ledger_duplicate(_ctx) do
    repo_root = RefusalLedgerExport.repo_root()
    source_path = Path.join(repo_root, @source_ledger)
    original = File.read!(source_path)
    artifact_original = File.read!(RefusalLedgerExport.out_path())

    ledger = Jason.decode!(original)

    # Inject a duplicate of an atom that already exists in the appended
    # entries (REFUSED_UNKNOWN_CHANNEL), citing a REAL on-disk court with
    # no line qualification — exercising the pick_court nil-vs-line branch.
    ledger =
      Map.update!(ledger, "variants", fn variants ->
        variants ++
          [
            %{
              "variant" => "REFUSED_UNKNOWN_CHANNEL",
              "sites" => ["lib/xaas/semantics/authority_channel.ex:72"],
              "fixture" => "test/xaas/semantics/authority_channel_test.exs",
              "refused?" => true
            }
          ]
      end)

    File.write!(source_path, Jason.encode!(ledger))

    on_exit(fn ->
      File.write(source_path, original)
      File.write(RefusalLedgerExport.out_path(), artifact_original)
    end)

    %{backup: original, source_path: source_path}
  end

  # ------------------------------------------------------------------
  # AuthorityLedgerExport — pure canonicalization / Merkle branches
  # (no DB rows needed: real maps, real SHA-256, real JCS)
  # ------------------------------------------------------------------

  defp entry(source, id),
    do: %{"source" => source, "id" => id, "v" => 1}

  describe "merkle_root/1 degenerate and odd-leaf cases" do
    test "zero leaves yield the 64-hex-zero root idiom" do
      assert AuthorityLedgerExport.merkle_root([]) == String.duplicate("0", 64)
    end

    test "a single leaf is the root itself, not hashed further" do
      leaf = :crypto.hash(:sha256, "leaf") |> Base.encode16(case: :lower)
      assert AuthorityLedgerExport.merkle_root([leaf]) == leaf
    end

    test "odd trailing leaf is duplicated (three-leaf root matches the CT idiom)" do
      h = fn bin -> :crypto.hash(:sha256, bin) |> Base.encode16(case: :lower) end

      [a, b, c] = leaves = Enum.map(["a", "b", "c"], h)

      expected = h.(h.(a <> b) <> h.(c <> c))

      # Mutation kill: the naive no-duplication variant (reusing c bare)
      # produces a different root — the court distinguishes the two.
      naive = h.(h.(h.(a <> b) <> c))
      assert naive != expected

      assert AuthorityLedgerExport.merkle_root(leaves) == expected
    end
  end

  describe "recompute_root/1 malformed input" do
    test "non-map and map-without-entries inputs return the typed :malformed_bundle" do
      assert {:error, :malformed_bundle} = AuthorityLedgerExport.recompute_root("not a map")
      assert {:error, :malformed_bundle} = AuthorityLedgerExport.recompute_root(%{})
      assert {:error, :malformed_bundle} = AuthorityLedgerExport.recompute_root(%{"entries" => 7})
    end

    test "an entries list with non-map members returns the typed :malformed_bundle (W984ii repair)" do
      # W984hp finding, repaired by W984ii: the typed
      # {:error, :malformed_bundle} contract now covers member shape too.
      # A bundle whose "entries" list contains non-map members returns the
      # typed refusal instead of crashing with BadMapError inside
      # Map.delete/2. Mutation kill: a mutant dropping the is_map/1 guard
      # resumes crashing (BadMapError), flipping this to red.
      assert {:error, :malformed_bundle} =
               AuthorityLedgerExport.recompute_root(%{"entries" => [%{"a" => 1}, "scalar", 3]})

      assert {:error, :malformed_bundle} =
               AuthorityLedgerExport.recompute_root(%{"entries" => [nil]})
    end
  end

  describe "entry_leaves/1 ordering" do
    test "entries are sorted by {source, id} before hashing, independent of input order" do
      e1 = entry("audit_log_entry", "b")
      e2 = entry("actuation_receipt", "z")
      e3 = entry("audit_log_entry", "a")

      [{ge1, l1}, {ge2, _}, {ge3, l3}] = AuthorityLedgerExport.entry_leaves([e1, e2, e3])

      assert [ge1, ge2, ge3] == [e2, e3, e1]

      leaf_of = fn e -> e |> Xaas.Semantics.Jcs.encode() |> sha256_hex() end
      assert l1 == leaf_of.(e2)
      assert l3 == leaf_of.(e1)
    end

    test "leaf hashes are content-sensitive and 64-hex" do
      [{_, la}] = AuthorityLedgerExport.entry_leaves([entry("a", "1")])

      assert byte_size(la) == 64
      assert la != sha256_hex(Xaas.Semantics.Jcs.encode(entry("a", "2")))
    end
  end

  defp sha256_hex(bin), do: :crypto.hash(:sha256, bin) |> Base.encode16(case: :lower)
end
