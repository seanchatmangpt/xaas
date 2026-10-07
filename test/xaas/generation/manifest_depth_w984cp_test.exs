defmodule Xaas.Generation.ManifestDepthW984cpTest do
  @moduledoc """
  Lane W984cp depth court — deterministic-generation-closure family,
  `Xaas.Generation.ProjectionRecord` excluded (already covered by
  `test/xaas/generation/projection_record_admission_depth_test.exs` and
  `generation_deepening_test.exs`).

  Five Chicago courts on depth edges no prior file in this session's
  tree asserts, each with a named mutation rationale (the mutation the
  test kills is in the comment):
  1. `Manifest.load/1` fail-loud on a missing required key
  2. `ProvenanceHeader` build/parse round-trip + malformed-hash refusal
  3. `ModificationDetector.detect_content/1` tri-state on real bytes
  4. `CapabilityRegistry` unknown-generator / unknown-artifact edges
  5. `ResidueRegistry` unregistered-path edges

  Real bytes, real modules, no mocks — the only filesystem touch is real
  `File` work in test 3 via `detect/1` on a real temp file.
  """

  use ExUnit.Case, async: true

  alias Xaas.Generation.{
    CapabilityRegistry,
    Manifest,
    ModificationDetector,
    ProvenanceHeader,
    ResidueRegistry
  }

  describe "Manifest.load/1 fail-loud edges" do
    # Mutation killed: `Map.fetch!/2` -> `Map.get(key, nil)`. A mutant that
    # silently admits a manifest entry missing a required key would build a
    # %Entry{} with a nil projection_path/source_path, which later no-ops
    # every find_by_projection/dependency-graph lookup instead of failing at
    # the manifest boundary.
    # NOTE: Manifest.load/1's moduledoc claims "Raises ArgumentError", but
    # Map.fetch!/2 actually raises KeyError. The test pins the REAL
    # contract; the doc discrepancy is disclosed in the lane receipt.
    test "raises KeyError on each missing required key, not a partial entry" do
      assert_raise KeyError, fn ->
        Manifest.load([%{source_path: "a.ttl", projection_path: "gen/a.ex"}])
      end

      assert_raise KeyError, fn ->
        Manifest.load([%{source_path: "a.ttl", generator_id: "ggen"}])
      end

      assert_raise KeyError, fn ->
        Manifest.load([%{projection_path: "gen/a.ex", generator_id: "ggen"}])
      end
    end
  end

  describe "ProvenanceHeader round-trip and format refusal" do
    # Mutation killed: (a) regex anchors/case-sensitivity relaxation — a
    # mutant accepting uppercase or short hashes would admit a header the
    # detector can never reproduce; (b) `build/1` field-order mutation —
    # a reordered header line would fail the round-trip.
    test "build/parse round-trip exactly; malformed or misplaced hash is refused" do
      line =
        ProvenanceHeader.build(%{
          generator_id: "ggen",
          source_path: "priv/ontology/a.ttl",
          hash: String.duplicate("0a", 32)
        })

      assert line ==
               "# xaas:generated generator=ggen source=priv/ontology/a.ttl hash=" <>
                 String.duplicate("0a", 32)

      # round-trip over real multi-line file content (the /m flag path)
      content = line <> "\ndefmodule A do\n  :ok\nend\n"
      assert %{generator_id: "ggen", source_path: "priv/ontology/a.ttl", hash: h} =
               ProvenanceHeader.parse(content)

      assert h == String.duplicate("0a", 32)

      # not 64 lowercase hex chars -> nil (uppercase, short, and truncated)
      assert nil == ProvenanceHeader.parse("# xaas:generated generator=g source=s hash=" <> String.duplicate("A", 64))
      assert nil == ProvenanceHeader.parse("# xaas:generated generator=g source=s hash=abc123")
      assert nil == ProvenanceHeader.parse("# xaas:generated generator=g source=s hash=")

      # header field missing entirely -> nil
      assert nil == ProvenanceHeader.parse("# xaas:generated generator=g source=s")
      assert nil == ProvenanceHeader.parse("plain elixir with no header at all")
    end
  end

  describe "ModificationDetector.detect_content/1 tri-state" do
    # Mutation killed: (a) `strip_header_line/1` splitting on the whole
    # content instead of only the first line (a mutant hashing the full
    # content would report :modified for every well-formed file);
    # (b) `:match == :modified` branch swap; (c) header-absent -> :match
    # (silent admission of unmanaged files).
    test "match, modified, and unmanaged are exact on real bytes" do
      body = "defmodule Generated do\n  :ok\nend\n"
      header = ProvenanceHeader.build(%{generator_id: "ggen", source_path: "a.ttl", hash: ""})

      header =
        String.replace_trailing(header, "hash=", "hash=" <> hash_of(body))

      content = header <> "\n" <> body

      assert ModificationDetector.detect_content(content) == :match

      # one real byte changed in the body -> :modified
      tampered = String.replace(content, ":ok", ":other")
      assert ModificationDetector.detect_content(tampered) == :modified

      # header removed entirely -> unmanaged, not silently :match
      assert ModificationDetector.detect_content(body) == :unmanaged

      # real-file path through detect/1 (real File.read, real temp file)
      path =
        Path.join(
          System.tmp_dir!(),
          "xaas_w984cp_#{System.system_time(:millisecond)}_#{:erlang.unique_integer([:positive])}"
        )

      File.write!(path, content)

      on_exit(fn -> File.rm(path) end)

      assert ModificationDetector.detect(path) == :match
      assert ModificationDetector.detect(path <> "-missing") == {:error, :enoent}
    end

    defp hash_of(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
  end

  describe "CapabilityRegistry unknown edges" do
    # Mutation killed: `Map.get(@registry, generator_id, [])` default ->
    # some catch-all capability list (a mutant claiming an unknown
    # generator supports everything would admit artifact kinds no real
    # generator can produce).
    test "unknown generator supports nothing and reports nil capabilities" do
      refute CapabilityRegistry.registered?("does-not-exist")
      assert CapabilityRegistry.capabilities("does-not-exist") == nil
      refute CapabilityRegistry.supports?("does-not-exist", :ash_resource)

      # known generator: exact declared set, and a kind it does not declare
      assert CapabilityRegistry.capabilities("ggen") == [
               :ash_resource,
               :ash_change,
               :rdf_shacl,
               :ocel_schema
             ]

      refute CapabilityRegistry.supports?("ggen", :handwritten_residue)

      # the manual entry is registered but capable of nothing
      assert CapabilityRegistry.registered?("manual")
      assert CapabilityRegistry.capabilities("manual") == []
      refute CapabilityRegistry.supports?("manual", :ash_resource)
    end
  end

  describe "ResidueRegistry unregistered-path edges" do
    # Mutation killed: `registered?/1` -> `true` (a mutant that treats
    # every path as registered residue would admit manual patches on any
    # file, voiding the CanonicalGraph+ManualPatch invariant); plus
    # `reason_for/1` returning a default reason instead of nil.
    test "unregistered path is not residue and carries no reason; validate clean on empty" do
      refute ResidueRegistry.registered?("lib/some/patched_file.ex")
      assert ResidueRegistry.reason_for("lib/some/patched_file.ex") == nil
      assert ResidueRegistry.entries() == []
      assert ResidueRegistry.validate() == []
    end
  end
end
