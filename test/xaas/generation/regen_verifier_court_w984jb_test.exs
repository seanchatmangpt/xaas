defmodule Xaas.Generation.RegenVerifierCourtW984jbTest do
  @moduledoc """
  Lane W984jb unclaimed-family probe: RegenerationVerifier branch census.

  Existing coverage (generation_test.exs, generation_deepening_test.exs):
  :match, :mismatch, and the typed UNSUPPORTED receipt's generator_id +
  reason. This court adds the genuinely unexercised state-bearing
  branches, each with its mutation rationale. Real files, zero mocks.
  """

  use ExUnit.Case, async: true

  alias Xaas.Generation.{HashManifest, Manifest, RegenerationVerifier, UnsupportedReceipt}

  defp write_tmp(name, content) do
    path =
      Path.join(
        System.tmp_dir!(),
        "xaas_w984jb_#{name}_#{System.system_time(:millisecond)}_#{:erlang.unique_integer([:positive])}"
      )

    File.write!(path, content)
    path
  end

  describe "verify/2 error branch" do
    test "missing projection file returns {:error, :enoent}, never :match or :mismatch" do
      # Mutation rationale: a mutant that collapses the File.read error
      # branch into :mismatch (or :match) would silently pass stale/absent
      # projections as verified. Only the typed error tuple pins the branch.
      missing = write_tmp("w984jb_missing", "x")
      File.rm!(missing)
      {:ok, digest} = HashManifest.compute_hash(write_tmp("w984jb_anchor", "anchor"))

      assert {:error, :enoent} = RegenerationVerifier.verify(missing, digest)
    end
  end

  describe "regenerate_and_diff/1 receipt content binding" do
    test "receipt detail names the actual generator_id and projection_path" do
      # Mutation rationale: a mutant hardcoding the detail string (or
      # interpolating the wrong entry fields) passes the existing tests,
      # which assert only generator_id/reason. Binding the detail to both
      # key entry fields kills it.
      entry = %Manifest.Entry{
        source_path: "ontology/w984jb.ttl",
        projection_path: "gen/w984jb/proj.ex",
        generator_id: "w984jb-gen"
      }

      receipt = RegenerationVerifier.regenerate_and_diff(entry)

      assert %UnsupportedReceipt{} = receipt
      assert receipt.reason == :no_generic_regeneration_entrypoint
      assert receipt.detail =~ "w984jb-gen"
      assert receipt.detail =~ "gen/w984jb/proj.ex"
    end

    test "distinct entries produce distinct receipts (no shared/cached receipt)" do
      # Mutation rationale: a mutant memoizing one receipt struct across
      # entries (shared occurred_at/generator_id) would pass a single-call
      # test; two entries must yield per-entry identity.
      e1 = %Manifest.Entry{
        source_path: "ontology/a.ttl",
        projection_path: "gen/a.ex",
        generator_id: "gen-a"
      }

      e2 = %Manifest.Entry{
        source_path: "ontology/b.ttl",
        projection_path: "gen/b.ex",
        generator_id: "gen-b"
      }

      r1 = RegenerationVerifier.regenerate_and_diff(e1)
      r2 = RegenerationVerifier.regenerate_and_diff(e2)

      assert r1.generator_id != r2.generator_id
      assert r1.detail != r2.detail
      assert %DateTime{} = r1.occurred_at
      assert %DateTime{} = r2.occurred_at
    end
  end

  describe "UnsupportedReceipt.build/3 guards" do
    test "non-binary generator_id is refused by guard (typed contract floor)" do
      # Mutation rationale: dropping the guard clause would let atom/nil
      # generator_ids through, breaking the receipt's identity contract.
      assert_raise FunctionClauseError, fn ->
        UnsupportedReceipt.build(:not_a_binary, :some_reason, "detail")
      end
    end

    test "non-atom reason is refused by guard" do
      assert_raise FunctionClauseError, fn ->
        UnsupportedReceipt.build("gen", "not_an_atom", "detail")
      end
    end
  end
end
