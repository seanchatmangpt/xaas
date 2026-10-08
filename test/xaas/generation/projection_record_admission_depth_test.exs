defmodule Xaas.Generation.ProjectionRecordAdmissionDepthTest do
  @moduledoc """
  W980i depth batch -- generation surface: the `ProjectionRecord` admission
  boundary's uncourted slice. Chicago-style: real temp files on disk, real
  `Ash.DataLayer.Ets` resource actions, real SHA-256 via
  `Xaas.Generation.HashManifest`. No mocks.

  Existing courts (`generation_test.exs` describe block +
  `generation_deepening_test.exs`) cover: hash-match admission, the
  manual-patch refusal (the key invariant), missing-file refusal, patch
  reversal, graph-mutation sensitivity. This file covers the adjacent
  uncourted slice:

  - read-back of an admitted record with full provenance (ETS round trip)
  - required-attribute refusals (`allow_nil? false` on provenance fields)
  - append-only admission of the same unchanged projection
  - divergence refusal where the recorded hash names *different real
    content* (both hashes real, file never patched after recording)

  Mutation rationale (W980i): remove
  `validate(Xaas.Generation.Validations.NoManualPatch)` from
  `ProjectionRecord`'s `:admit` action in
  `lib/xaas/generation/projection_record.ex` -- the divergence-refusal
  court below fails (admission proceeds despite the recorded hash naming
  content that never existed at that path), proving the validation, not
  the ETS data layer, is the refusing collaborator.
  """
  use ExUnit.Case, async: true
  require Ash.Query

  alias Xaas.Generation.{HashManifest, ProjectionRecord}

  defp write_tmp(name, content) do
    path =
      Path.join(
        System.tmp_dir!(),
        "xaas_w980i_#{name}_#{System.system_time(:millisecond)}_#{:erlang.unique_integer([:positive])}"
      )

    File.write!(path, content)
    path
  end

  defp admit!(path, recorded_hash, source \\ "ontology/w980i.ttl") do
    ProjectionRecord
    |> Ash.Changeset.for_create(:admit, %{
      source_path: source,
      projection_path: path,
      generator_id: "ggen-w980i",
      recorded_hash: recorded_hash
    })
    |> Ash.create!()
  end

  test "an admitted record is readable back with full provenance via the ETS data layer" do
    path = write_tmp("readback", "projection bytes v1\n")
    {:ok, hash} = HashManifest.compute_hash(path)

    record = admit!(path, hash, "ontology/readback.ttl")

    found =
      ProjectionRecord
      |> Ash.Query.filter(projection_path == ^path)
      |> Ash.read_one!()

    assert found.id == record.id
    assert found.source_path == "ontology/readback.ttl"
    assert found.generator_id == "ggen-w980i"
    assert found.recorded_hash == hash
    assert found.inserted_at != nil
  end

  test "admission refuses when a required provenance attribute is missing" do
    path = write_tmp("missing_hash", "projection bytes\n")

    assert {:error, %Ash.Error.Invalid{}} =
             ProjectionRecord
             |> Ash.Changeset.for_create(:admit, %{
               source_path: "ontology/w980i.ttl",
               projection_path: path,
               generator_id: "ggen-w980i"
             })
             |> Ash.create()
  end

  test "admission refuses a recorded hash naming different real content (divergence, not patch)" do
    # Two real files, two real hashes: the record declares the hash of B
    # while the on-disk projection is A. Nothing was ever patched after
    # recording -- this is pure provenance divergence, and NoManualPatch
    # must refuse it because the path is not registered residue.
    path_a = write_tmp("diverge_a", "content alpha\n")
    path_b = write_tmp("diverge_b", "content beta\n")
    {:ok, hash_b} = HashManifest.compute_hash(path_b)

    assert {:error, %Ash.Error.Invalid{} = error} =
             ProjectionRecord
             |> Ash.Changeset.for_create(:admit, %{
               source_path: "ontology/w980i.ttl",
               projection_path: path_a,
               generator_id: "ggen-w980i",
               recorded_hash: hash_b
             })
             |> Ash.create()

    assert Exception.message(error) =~ "diverges from its recorded generation hash"
  end

  test "admission is append-only: the same unchanged projection admits twice as independent records" do
    path = write_tmp("append", "stable projection bytes\n")
    {:ok, hash} = HashManifest.compute_hash(path)

    r1 = admit!(path, hash, "ontology/append.ttl")
    r2 = admit!(path, hash, "ontology/append.ttl")

    assert r1.id != r2.id

    count =
      ProjectionRecord
      |> Ash.Query.filter(projection_path == ^path and recorded_hash == ^hash)
      |> Ash.count!()

    assert count == 2
  end

  test "two distinct projections admitted independently keep distinct provenance" do
    path_a = write_tmp("two_a", "projection A\n")
    path_b = write_tmp("two_b", "projection B\n")
    {:ok, hash_a} = HashManifest.compute_hash(path_a)
    {:ok, hash_b} = HashManifest.compute_hash(path_b)

    r1 = admit!(path_a, hash_a, "ontology/two_a.ttl")
    r2 = admit!(path_b, hash_b, "ontology/two_b.ttl")

    assert r1.id != r2.id
    assert r1.recorded_hash != r2.recorded_hash

    found_b =
      ProjectionRecord
      |> Ash.Query.filter(projection_path == ^path_b)
      |> Ash.read_one!()

    assert found_b.source_path == "ontology/two_b.ttl"
    assert found_b.recorded_hash == hash_b
  end
end
