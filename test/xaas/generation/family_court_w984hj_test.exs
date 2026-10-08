defmodule Xaas.Generation.FamilyCourtW984hjTest do
  @moduledoc """
  Lane W984hj unclaimed-family court on `lib/xaas/generation/`.

  Most of this family is already deeply covered (generation_test.exs,
  generation_deepening_test.exs, manifest_depth_w984cp_test.exs,
  lock_error_roundtrip_w984dj5b2_test.exs, lock_persistence_depth_w984dj5_test.exs,
  projection_record_admission_depth_test.exs). This court targets only the
  genuinely unexercised state-bearing branches found by the probe:

  1. `CapabilityRegistry.known_generators/0` — zero callers in lib/ or test/.
  2. `ProvenanceHeader.parse/1` rejection edges (uppercase hash, truncated header).
  3. `UnsupportedReceipt.build/3` input guards (non-binary id, non-atom reason).
  4. `HashManifest.load/1` failure paths (missing store file, malformed JSON).

  Real files, real structs, real Jason decode — zero mocks. Mutation
  rationale per test: the mutation that would survive the prior suite.
  """

  use ExUnit.Case, async: true

  alias Xaas.Generation.{
    CapabilityRegistry,
    HashManifest,
    ProvenanceHeader,
    UnsupportedReceipt
  }

  defp tmp_path(name) do
    Path.join(System.tmp_dir!(), "w984hj-#{name}-#{System.unique_integer([:positive])}")
  end

  describe "CapabilityRegistry.known_generators/0 (zero prior callers)" do
    test "lists every registry key, both directions agree with registered?/1" do
      known = CapabilityRegistry.known_generators()

      assert is_list(known)
      assert "ggen" in known
      assert "manual" in known
      # Cross-check: known list and registered?/1 are consistent over real
      # registry state — mutating a registry key away breaks one of these.
      for generator <- known do
        assert CapabilityRegistry.registered?(generator)
      end
      # And the capability map itself is real, not an empty husk.
      assert CapabilityRegistry.capabilities("ggen") |> Enum.sort() == [
               :ash_change,
               :ash_resource,
               :ocel_schema,
               :rdf_shacl
             ]
    end
  end

  describe "ProvenanceHeader.parse/1 rejection edges" do
    test "uppercase hex hash is refused, not coerced (hash alphabet is exact)" do
      content =
        "# xaas:generated generator=ggen source=ontology/a.ttl hash=" <>
          String.upcase(String.duplicate("ab", 32)) <> "\nbody\n"

      assert ProvenanceHeader.parse(content) == nil

      # The lowercase form of the very same hash parses — the refusal is the
      # alphabet, not the length or shape.
      assert %{hash: hash} =
               ProvenanceHeader.parse(
                 "# xaas:generated generator=ggen source=ontology/a.ttl hash=" <>
                   String.duplicate("ab", 32)
               )

      assert String.valid?(hash) and byte_size(hash) == 64
    end

    test "truncated / malformed header lines return nil (absence is data)" do
      assert ProvenanceHeader.parse("# xaas:generated generator=ggen source=ontology/a.ttl\n") ==
               nil

      assert ProvenanceHeader.parse(
               "# xaas:generated generator=ggen source=ontology/a.ttl hash=short\n"
             ) == nil

      assert ProvenanceHeader.parse("not a header at all") == nil
    end
  end

  describe "UnsupportedReceipt.build/3 guards" do
    test "non-binary generator_id is rejected with FunctionClauseError" do
      assert_raise FunctionClauseError, fn ->
        UnsupportedReceipt.build(:ggen, :some_reason, "detail")
      end
    end

    test "non-atom reason is rejected with FunctionClauseError" do
      assert_raise FunctionClauseError, fn ->
        UnsupportedReceipt.build("ggen", "some_reason", "detail")
      end
    end

    test "valid inputs still build a fully-keyed real receipt" do
      receipt = UnsupportedReceipt.build("ggen", :no_generic_regeneration_entrypoint, "detail")

      assert %UnsupportedReceipt{generator_id: "ggen", reason: :no_generic_regeneration_entrypoint} =
               receipt

      assert %DateTime{} = receipt.occurred_at
    end
  end

  describe "HashManifest.load/1 failure paths" do
    test "missing store file yields {:error, :enoent}, never a fabricated map" do
      assert {:error, :enoent} = HashManifest.load(tmp_path("missing-store.json"))
    end

    test "malformed JSON yields {:error, %Jason.DecodeError{}}" do
      path = tmp_path("malformed-store.json")
      File.write!(path, "{not json")

      assert {:error, %Jason.DecodeError{}} = HashManifest.load(path)
      File.rm(path)
    end
  end
end
