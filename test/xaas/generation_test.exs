defmodule Xaas.GenerationTest do
  @moduledoc """
  Real, non-mocked exercise of the deterministic-generation-closure slice
  (docs/jira/v26.9.11/deterministic-generation-closure.md). Every test
  below operates on real temp files on disk and a real Ash resource
  (`Xaas.Generation.ProjectionRecord`, `Ash.DataLayer.Ets`) -- no
  `unittest.mock`/`Mox`/stubbed collaborators.
  """
  use ExUnit.Case, async: true

  alias Xaas.Generation.{
    CapabilityRegistry,
    DependencyGraph,
    HashManifest,
    Lock,
    Manifest,
    ModificationDetector,
    ProjectionRecord,
    ProvenanceHeader,
    RegenerationVerifier,
    ResidueRegistry,
    UnsupportedReceipt
  }

  # Real temp file helper -- writes real bytes to a real file on disk and
  # returns its path. No in-memory fake filesystem.
  defp write_tmp(name, content) do
    path =
      Path.join(System.tmp_dir!(), "xaas_dgc_test_#{name}_#{:erlang.unique_integer([:positive])}")

    File.write!(path, content)
    on_exit_delete(path)
    path
  end

  defp on_exit_delete(path) do
    ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)
  end

  describe "HashManifest" do
    test "compute_hash/1 returns the real sha256 of real file content" do
      path = write_tmp("hash", "hello world")
      assert {:ok, digest} = HashManifest.compute_hash(path)
      assert digest == Base.encode16(:crypto.hash(:sha256, "hello world"), case: :lower)
    end

    test "compute_hash/1 reports a real error for a missing file" do
      assert {:error, :enoent} = HashManifest.compute_hash("/nonexistent/path/does-not-exist")
    end

    test "verify/2 returns :match when the real file hash matches" do
      path = write_tmp("verify_match", "same content")
      {:ok, digest} = HashManifest.compute_hash(path)
      assert HashManifest.verify(path, digest) == :match
    end

    test "verify/2 returns :mismatch when the real file diverged (the ticket's falsifier)" do
      path = write_tmp("verify_mismatch", "original content")
      {:ok, original_digest} = HashManifest.compute_hash(path)

      # Real manual edit to the projection.
      File.write!(path, "manually patched content")

      assert HashManifest.verify(path, original_digest) == :mismatch
    end

    test "build/1 computes real hashes for every manifest entry, and errors don't hide others" do
      good_path = write_tmp("build_good", "generated content")

      entries =
        Manifest.load([
          %{source_path: "src/a.ttl", projection_path: good_path, generator_id: "ggen"},
          %{
            source_path: "src/b.ttl",
            projection_path: "/nonexistent/missing_projection",
            generator_id: "ggen"
          }
        ])

      hash_manifest = HashManifest.build(entries)
      assert {:ok, hash} = HashManifest.compute_hash(good_path)
      assert Map.fetch!(hash_manifest, good_path) == hash
      assert {:error, :enoent} = Map.fetch!(hash_manifest, "/nonexistent/missing_projection")
    end
  end

  describe "DependencyGraph" do
    test "build/1 groups real manifest entries by source_path" do
      entries =
        Manifest.load([
          %{source_path: "ontology/a.ttl", projection_path: "gen/a1.ex", generator_id: "ggen"},
          %{source_path: "ontology/a.ttl", projection_path: "gen/a2.ex", generator_id: "ggen"},
          %{source_path: "ontology/b.ttl", projection_path: "gen/b1.ex", generator_id: "ggen"}
        ])

      graph = DependencyGraph.build(entries)

      assert DependencyGraph.projections_for(graph, "ontology/a.ttl") == [
               "gen/a1.ex",
               "gen/a2.ex"
             ]

      assert DependencyGraph.projections_for(graph, "ontology/b.ttl") == ["gen/b1.ex"]
      assert DependencyGraph.projections_for(graph, "ontology/nonexistent.ttl") == []
    end
  end

  describe "Lock" do
    test "build/1 is deterministic across independent computations of the same real hash manifest" do
      path_a = write_tmp("lock_a", "content a")
      path_b = write_tmp("lock_b", "content b")

      {:ok, hash_a} = HashManifest.compute_hash(path_a)
      {:ok, hash_b} = HashManifest.compute_hash(path_b)

      manifest_1 = %{path_a => hash_a, path_b => hash_b}
      manifest_2 = %{path_b => hash_b, path_a => hash_a}

      assert Lock.build(manifest_1) == Lock.build(manifest_2)
    end

    test "verify/2 detects a real change to the hash manifest" do
      path = write_tmp("lock_verify", "v1")
      {:ok, hash} = HashManifest.compute_hash(path)
      manifest = %{path => hash}
      lock = Lock.build(manifest)

      assert Lock.verify(manifest, lock) == :match

      changed_manifest = %{
        path => "0000000000000000000000000000000000000000000000000000000000000000"
      }

      assert Lock.verify(changed_manifest, lock) == :mismatch
    end
  end

  describe "ProvenanceHeader + ModificationDetector" do
    test "an unmanaged file (no header) is reported as :unmanaged" do
      path = write_tmp("unmanaged", "plain content, no header")
      assert ModificationDetector.detect(path) == :unmanaged
    end

    test "a real generated file with a correct header hash reports :match" do
      body = "defmodule Generated do\n  :ok\nend\n"

      header =
        ProvenanceHeader.build(%{
          generator_id: "ggen",
          source_path: "src/x.ttl",
          hash: sha256(body)
        })

      path = write_tmp("match", header <> "\n" <> body)

      assert ModificationDetector.detect(path) == :match
    end

    test "a manually edited generated file reports :modified (the ticket's second falsifier)" do
      body = "defmodule Generated do\n  :ok\nend\n"

      header =
        ProvenanceHeader.build(%{
          generator_id: "ggen",
          source_path: "src/x.ttl",
          hash: sha256(body)
        })

      path = write_tmp("modified", header <> "\n" <> body)

      # Real hand edit after generation -- this is exactly the forbidden
      # CanonicalGraph + ManualPatch path the detector must catch.
      File.write!(path, header <> "\n" <> body <> "# manually appended\n")

      assert ModificationDetector.detect(path) == :modified
    end
  end

  describe "CapabilityRegistry" do
    test "reports real, declared capabilities and rejects an unregistered generator" do
      assert CapabilityRegistry.registered?("ggen")
      assert CapabilityRegistry.supports?("ggen", :ash_resource)
      refute CapabilityRegistry.supports?("ggen", :nonexistent_kind)
      refute CapabilityRegistry.registered?("totally-unknown-generator")
    end
  end

  describe "ResidueRegistry" do
    test "validate/0 flags an unregistered path as not registered, not silently allowed" do
      refute ResidueRegistry.registered?("some/random/path.ex")
      assert ResidueRegistry.reason_for("some/random/path.ex") == nil
    end

    test "validate/0 returns no problems for the current (empty) registry" do
      assert ResidueRegistry.validate() == []
    end
  end

  describe "UnsupportedReceipt + RegenerationVerifier bounded scope" do
    test "regenerate_and_diff/1 returns a typed UnsupportedReceipt, never a fabricated diff" do
      entry = %Manifest.Entry{
        source_path: "ontology/x.ttl",
        projection_path: "gen/x.ex",
        generator_id: "ggen"
      }

      receipt = RegenerationVerifier.regenerate_and_diff(entry)

      assert %UnsupportedReceipt{} = receipt
      assert receipt.generator_id == "ggen"
      assert receipt.reason == :no_generic_regeneration_entrypoint
      assert %DateTime{} = receipt.occurred_at
    end

    test "verify/2 is a real hash check delegating to HashManifest (falsifier-safe)" do
      path = write_tmp("regen_verify", "generated body")
      {:ok, digest} = HashManifest.compute_hash(path)
      assert RegenerationVerifier.verify(path, digest) == :match

      File.write!(path, "manually patched body")
      assert RegenerationVerifier.verify(path, digest) == :mismatch
    end
  end

  describe "Xaas.Generation.ProjectionRecord Ash admission boundary" do
    test "admits a projection whose real on-disk hash matches the recorded hash" do
      path = write_tmp("admit_match", "real generated content")
      {:ok, hash} = HashManifest.compute_hash(path)

      assert {:ok, record} =
               ProjectionRecord
               |> Ash.Changeset.for_create(:admit, %{
                 source_path: "ontology/x.ttl",
                 projection_path: path,
                 generator_id: "ggen",
                 recorded_hash: hash
               })
               |> Ash.create()

      assert record.projection_path == path
      assert record.recorded_hash == hash
    end

    test "refuses admission of a manually patched projection not in the residue registry (the key invariant)" do
      path = write_tmp("admit_patched", "original generated content")
      {:ok, original_hash} = HashManifest.compute_hash(path)

      # Real manual patch after the hash was recorded -- the forbidden
      # CanonicalGraph + ManualPatch path.
      File.write!(path, "hand-patched content, never regenerated")

      assert {:error, error} =
               ProjectionRecord
               |> Ash.Changeset.for_create(:admit, %{
                 source_path: "ontology/x.ttl",
                 projection_path: path,
                 generator_id: "ggen",
                 recorded_hash: original_hash
               })
               |> Ash.create()

      assert %Ash.Error.Invalid{} = error
      message = Exception.message(error)
      assert message =~ "forbidden CanonicalGraph + ManualPatch path"
    end

    test "refuses admission when the projection file genuinely does not exist" do
      assert {:error, error} =
               ProjectionRecord
               |> Ash.Changeset.for_create(:admit, %{
                 source_path: "ontology/x.ttl",
                 projection_path: "/nonexistent/never-existed",
                 generator_id: "ggen",
                 recorded_hash: "0000000000000000000000000000000000000000000000000000000000000000"
               })
               |> Ash.create()

      assert %Ash.Error.Invalid{} = error
      assert Exception.message(error) =~ "could not read projection"
    end
  end

  defp sha256(content), do: Base.encode16(:crypto.hash(:sha256, content), case: :lower)
end
