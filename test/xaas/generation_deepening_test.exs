defmodule Xaas.GenerationDeepeningTest do
  @moduledoc """
  W736 deepening court for the deterministic generation closure
  (`Xaas.Generation`): g(CanonicalGraph) -> Projection determinism, the
  `CanonicalGraph + ManualPatch` admission refusal at the real Ash
  boundary, graph-mutation sensitivity, and degenerate-graph behavior.

  Chicago-style: real temp files on disk, real hashing, real Ash ETS
  resource. No mocks, no stubs.
  """

  use ExUnit.Case, async: true

  alias Xaas.Generation.{
    HashManifest,
    Manifest,
    ProjectionRecord,
    ProvenanceHeader,
    RegenerationVerifier
  }

  defp tmp_path(name) do
    Path.join(
      System.tmp_dir!(),
      "xaas_w736_#{name}_#{System.system_time(:millisecond)}_#{:erlang.unique_integer([:positive])}"
    )
  end

  defp write_tmp(name, content) do
    path = tmp_path(name)
    File.write!(path, content)
    ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)
    path
  end

  # A tiny, real, deterministic "generator" standing in for g/1 over the
  # manifest's canonical-graph inputs: same entries + same graph bytes ->
  # same projection bytes, every time. This is the closure shape the
  # domain declares; determinism is asserted over real written output.
  defp render_projection(%Manifest.Entry{} = entry, graph_content) do
    hash = Base.encode16(:crypto.hash(:sha256, graph_content), case: :lower)

    header = ProvenanceHeader.build(%{generator_id: entry.generator_id, source_path: entry.source_path, hash: hash})

    """
    #{header}
    # projection of #{entry.source_path}
    graph_sha256=#{hash}
    """
  end

  defp admit_attrs(projection_path, source_path, recorded_hash) do
    [
      source_path: source_path,
      projection_path: projection_path,
      generator_id: "ggen",
      recorded_hash: recorded_hash
    ]
  end

  describe "g(CanonicalGraph) -> Projection closure determinism" do
    test "same canonical graph input yields byte-identical projection, three runs" do
      entry = %Manifest.Entry{
        source_path: "ontology/canon.ttl",
        projection_path: "generated/ash/canon.ex",
        generator_id: "ggen"
      }

      graph = "<http://ex/subject> <http://ex/pred> \"v1\" .\n"

      runs =
        for i <- 1..3 do
          path = write_tmp("determinism_#{i}", render_projection(entry, graph))
          File.read!(path)
        end

      assert hd(runs) == Enum.at(runs, 1)
      assert hd(runs) == Enum.at(runs, 2)
      # the first run's on-disk hash equals the sha256 of its bytes:
      assert {:ok, written_hash} = HashManifest.compute_hash(write_tmp("sink", hd(runs)))
      assert written_hash == Base.encode16(:crypto.hash(:sha256, hd(runs)), case: :lower)
    end

    test "a regenerated projection matches the previously recorded generation hash" do
      entry = %Manifest.Entry{
        source_path: "ontology/canon.ttl",
        projection_path: "generated/ash/canon.ex",
        generator_id: "ggen"
      }

      graph = "<http://ex/s> <http://ex/p> \"stable\" .\n"

      first = render_projection(entry, graph)
      path = write_tmp("regen", first)
      {:ok, recorded} = HashManifest.compute_hash(path)

      # later regeneration from the same graph:
      second = render_projection(entry, graph)
      assert second == first
      assert RegenerationVerifier.verify(path, recorded) == :match
    end
  end

  describe "CanonicalGraph + ManualPatch admission boundary" do
    test "manual patch after generation refuses admission with the typed invariant message" do
      path = write_tmp("patch_refused", "generated from canonical graph\n")
      {:ok, original_hash} = HashManifest.compute_hash(path)

      File.write!(path, "hand-edited divergence\n")

      assert {:error, %Ash.Error.Invalid{} = error} =
               ProjectionRecord
               |> Ash.Changeset.for_create(:admit, admit_attrs(path, "ontology/canon.ttl", original_hash))
               |> Ash.create()

      message = Exception.message(error)
      assert message =~ "forbidden CanonicalGraph + ManualPatch path"
      assert message =~ "Xaas.Generation.ResidueRegistry"
    end

    test "regeneration to the original bytes re-admits (patch reversed, closure restored)" do
      path = write_tmp("patch_reversed", "generated from canonical graph\n")
      {:ok, original_hash} = HashManifest.compute_hash(path)

      File.write!(path, "hand-edited divergence\n")

      assert {:error, %Ash.Error.Invalid{}} =
               ProjectionRecord
               |> Ash.Changeset.for_create(:admit, admit_attrs(path, "ontology/canon.ttl", original_hash))
               |> Ash.create()

      # regenerate to the exact original bytes:
      File.write!(path, "generated from canonical graph\n")

      assert {:ok, record} =
               ProjectionRecord
               |> Ash.Changeset.for_create(:admit, admit_attrs(path, "ontology/canon.ttl", original_hash))
               |> Ash.create()

      assert record.recorded_hash == original_hash
    end
  end

  describe "graph mutation sensitivity" do
    test "different canonical graph produces a different projection and a different recorded hash" do
      entry = %Manifest.Entry{
        source_path: "ontology/canon.ttl",
        projection_path: "generated/ash/canon.ex",
        generator_id: "ggen"
      }

      g1 = "<http://ex/s> <http://ex/p> \"v1\" .\n"
      g2 = "<http://ex/s> <http://ex/p> \"v2\" .\n"

      p1 = render_projection(entry, g1)
      p2 = render_projection(entry, g2)

      assert p1 != p2

      path1 = write_tmp("mut_a", p1)
      path2 = write_tmp("mut_b", p2)

      {:ok, h1} = HashManifest.compute_hash(path1)
      {:ok, h2} = HashManifest.compute_hash(path2)
      assert h1 != h2

      assert RegenerationVerifier.verify(path1, h2) == :mismatch
    end
  end

  describe "degenerate graph behavior" do
    test "empty canonical graph renders a well-formed, self-consistent projection" do
      entry = %Manifest.Entry{
        source_path: "ontology/empty.ttl",
        projection_path: "generated/ash/empty.ex",
        generator_id: "ggen"
      }

      projection = render_projection(entry, "")
      path = write_tmp("empty_graph", projection)
      {:ok, hash} = HashManifest.compute_hash(path)

      header = ProvenanceHeader.parse(projection)
      assert %{} = header
      # the provenance header records the sha256 of the SOURCE GRAPH bytes
      # (empty graph -> sha256("")), not of the projection file:
      assert header.hash == Base.encode16(:crypto.hash(:sha256, ""), case: :lower)
      assert header.source_path == "ontology/empty.ttl"

      assert {:ok, _record} =
               ProjectionRecord
               |> Ash.Changeset.for_create(:admit, admit_attrs(path, "ontology/empty.ttl", hash))
               |> Ash.create()
    end

    test "admission of a projection file that does not exist refuses with a read error" do
      assert {:error, %Ash.Error.Invalid{} = error} =
               ProjectionRecord
               |> Ash.Changeset.for_create(:admit, admit_attrs("/nonexistent/w736", "ontology/x.ttl", String.duplicate("0", 64)))
               |> Ash.create()

      assert Exception.message(error) =~ "could not read projection"
    end
  end
end
