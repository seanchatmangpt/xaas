defmodule Xaas.Generation.GenReceiptsCourtW984jdTest do
  @moduledoc """
  Lane W984jd unclaimed-family probe: the `.ash-gen-receipts/` surface
  (88 files per W984ik's census) and the `lib/xaas/generation` readers.

  Probe findings baked into this court:

  1. `.ash-gen-receipts/` is referenced by ZERO code under `lib/`/`test/`
     (`grep -r 'ash-gen-receipts'` → no hits) — the dir is a real
     state-bearing surface with no in-repo reader. This census court is
     therefore the first guard over it: it parses the real receipt files
     from disk (read-only) and pins their structural contract.
  2. `ModificationDetector.detect/1`'s `File.read` error branch
     (`{:error, :enoent}`) and `detect_content/1`'s single-line
     (no-newline) header branch were exercised by no existing test.
  3. `ProvenanceHeader.build/parse` roundtrip over a space-containing
     field is an unexercised documented boundary: the header format is
     `\\S+`-delimited, so a space-containing `generator_id` roundtrips
     truncated — pinned as a typed boundary, not silently tolerated.
  """

  use ExUnit.Case, async: true

  alias Xaas.Generation.{ModificationDetector, ProvenanceHeader}

  @receipts_dir Path.join(File.cwd!(), ".ash-gen-receipts")

  defp receipt_names do
    @receipts_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".txt"))
    |> Enum.map(&String.replace_suffix(&1, ".txt", ""))
    |> Enum.sort()
  end

  defp command_lines(name) do
    path = Path.join(@receipts_dir, name <> ".txt")

    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "command: "))
    |> Enum.map(&String.replace_prefix(&1, "command: ", ""))
  end

  defp read_receipt(name) do
    path = Path.join(@receipts_dir, name <> ".txt")
    content = File.read!(path)

    Map.new(String.split(content, "\n"), fn line ->
      case String.split(line, ": ", parts: 2) do
        [k, v] -> {k, v}
        [k] -> {k, ""}
      end
    end)
  end

  describe ".ash-gen-receipts real-file census (read-only)" do
    test "dir exists and is non-empty (surface still present)" do
      # Mutation rationale: a mutant deleting the receipts dir (or the
      # census pointing at a wrong path) must fail loudly — this is the
      # only in-repo guard over the surface.
      assert File.dir?(@receipts_dir)
      assert length(receipt_names()) > 0
    end

    test "every .txt receipt has a matching .mix.log sibling, no orphans" do
      # Mutation rationale: a mutant that drops the mix.log pairing check
      # would let a half-written receipt pair (txt without log or log
      # without txt) pass silently. Both directions pinned.
      names = receipt_names()
      assert length(names) == 44

      all_files = MapSet.new(File.ls!(@receipts_dir))

      for name <- names do
        assert MapSet.member?(all_files, name <> ".mix.log"),
               "missing .mix.log for receipt #{name}"

        assert MapSet.member?(all_files, name <> ".txt"),
               "missing .txt for receipt #{name}"
      end

      orphans =
        all_files
        |> Enum.reject(&(String.ends_with?(&1, ".txt") or String.ends_with?(&1, ".mix.log")))
        |> Enum.to_list()

      assert orphans == [], "unexpected orphan files in receipts dir: #{inspect(orphans)}"
    end

    test "every receipt txt parses into the generated:/domain:/command: contract, subject matches filename" do
      # Mutation rationale: a mutant weakening the per-line contract (e.g.
      # accepting a receipt missing any `command:` line, or letting the
      # `generated:` subject drift from the filename) passes any
      # aggregate-only check. Per-file binding kills it.
      for name <- receipt_names() do
        receipt = read_receipt(name)

        assert receipt["generated"] == name,
               "receipt #{name}.txt subject #{inspect(receipt["generated"])} != filename"

        assert is_binary(receipt["domain"]) and receipt["domain"] != ""

        commands = command_lines(name)

        assert commands != [], "receipt #{name}.txt has no command: line"
        assert Enum.any?(commands, &String.contains?(&1, name)),
               "no command line names subject #{name}"

        assert Enum.any?(commands, &String.contains?(&1, "--ignore-if-exists")),
               "receipt #{name}.txt commands missing --ignore-if-exists"
      end
    end

    test "every .mix.log sibling is non-empty" do
      # Mutation rationale: a truncated/zero-byte mix.log (crashed
      # generation) is exactly the state the census must catch. (Observed
      # ground truth: mix.log bodies are Igniter/compiler output and do
      # not reliably name the subject, so only non-emptiness is pinned.)
      for name <- receipt_names() do
        log = File.read!(Path.join(@receipts_dir, name <> ".mix.log"))
        assert String.trim(log) != "", "empty mix.log for #{name}"
      end
    end

    test "every command: line in every receipt declares the ash.gen.resource family" do
      # Mutation rationale: a mutant that swaps the generator family
      # check for a tautology (e.g. checking only "mix ") would admit a
      # hand-written resource smuggled in with a receipt-shaped file.
      # Pinning every command line to the literal generator prefix kills it.
      for name <- receipt_names() do
        for cmd <- command_lines(name) do
          assert cmd =~ ~r/^mix ash\.gen\.resource /,
                 "receipt #{name}.txt has non-ash.gen command line: #{inspect(cmd)}"
        end
      end
    end
  end

  describe "ModificationDetector unexercised branches" do
    test "detect/1 on a missing file returns the typed File.read error, never a verdict" do
      # Mutation rationale: a mutant collapsing the File.read error branch
      # into :unmanaged (or :match) would classify absent projections as
      # safe. Only the typed error tuple pins the branch.
      missing =
        Path.join(System.tmp_dir!(), "w984jd_missing_#{System.system_time(:millisecond)}")

      assert {:error, :enoent} = ModificationDetector.detect(missing)
    end

    test "detect_content/1 on a header-only, newline-terminated file: body is empty, hash of \"\" decides" do
      # Mutation rationale: a mutant that hashes the whole content (not
      # the stripped body) passes on normal files but fails here, where
      # the declared hash must equal sha256("") for :match. Pins the
      # strip_header_line body-vs-whole-file distinction.
      empty_hash = Base.encode16(:crypto.hash(:sha256, ""), case: :lower)

      header =
        ProvenanceHeader.build(%{
          generator_id: "w984jd-gen",
          source_path: "src/w984jd.ttl",
          hash: empty_hash
        })

      assert ModificationDetector.detect_content(header <> "\n") == :match
    end

    test "detect_content/1 on a header line with appended body and no newline: header fails to parse, verdict is :unmanaged" do
      # Observed ground truth: the header regex anchors hash=<64 hex> to
      # end-of-line ($ in /m), so "hash=<hex>body" without a newline does
      # not parse at all — parse/1 returns nil and the content is
      # classified :unmanaged, never :modified. Mutation rationale: a
      # mutant that loosens the hash anchor (matching a prefix of the
      # hash) would flip this to :modified — silently flagging a
      # header-prefixed file as tampered. This input is the killer.
      hash = Base.encode16(:crypto.hash(:sha256, "body"), case: :lower)

      header =
        ProvenanceHeader.build(%{
          generator_id: "w984jd-gen",
          source_path: "src/w984jd.ttl",
          hash: hash
        })

      assert ModificationDetector.detect_content(header <> "body") == :unmanaged
    end
  end

  describe "ProvenanceHeader roundtrip boundary" do
    test "space-containing field makes a built header unparseable: parse returns nil (fail-closed \\S+ boundary)" do
      # Observed ground truth: build/1 does not escape spaces; a
      # space-containing generator_id breaks the strict field ordering in
      # the regex (generator=(\S+) is followed by a literal " source="),
      # so parse/1 fails CLOSED — nil, never truncated fields. Mutation
      # rationale: a mutant that partially matches (accepting the first
      # \S+ fields and dropping the rest) would return a struct with
      # corrupted provenance; nil pins the fail-closed contract.
      header =
        ProvenanceHeader.build(%{
          generator_id: "ggen v2",
          source_path: "src.ttl",
          hash: String.duplicate("a", 64)
        })

      assert ProvenanceHeader.parse(header) == nil
    end
  end
end
