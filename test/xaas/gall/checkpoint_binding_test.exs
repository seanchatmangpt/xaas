defmodule Xaas.Gall.CheckpointBindingTest do
  use ExUnit.Case, async: true

  alias Xaas.Gall.Checkpoint
  alias Xaas.Gall.CheckpointBinding

  @base_sha "6d5fca8cff223eb30ef19e237574d54f21cbfc15"

  @checkpoint_fields [
    identity: "urn:gall:checkpoint:xaas:semantic-worker-001",
    class: "CodingCheckpoint",
    repository: "urn:repo:seanchatmangpt:xaas",
    base_sha: @base_sha,
    goal: "https://semantic-a2a.dev/gall#SemanticWorkerIntegration",
    verifier: "https://semantic-a2a.dev/gall#XaasChicagoCourt",
    standing: :UNKNOWN
  ]

  describe "from_checkpoint/1" do
    test "binds identity, repository, base SHA, and the checkpoint's content digest" do
      {:ok, checkpoint} = Checkpoint.new(@checkpoint_fields)
      {:ok, binding} = CheckpointBinding.from_checkpoint(checkpoint)

      assert binding.checkpoint_iri == checkpoint.identity
      assert binding.repository == checkpoint.repository
      assert binding.base_sha == checkpoint.base_sha
      assert binding.graph_digest == Checkpoint.graph_digest(checkpoint)
      assert Regex.match?(~r/^[0-9a-f]{64}$/, binding.graph_digest)
    end

    test "refuses something that was never admitted" do
      assert CheckpointBinding.from_checkpoint(%{identity: "not-a-checkpoint"}) ==
               {:refused, :refused_authority}

      assert CheckpointBinding.from_checkpoint("string") == {:refused, :refused_authority}
    end
  end

  describe "new/1" do
    test "builds a binding from raw fields" do
      {:ok, checkpoint} = Checkpoint.new(@checkpoint_fields)

      assert {:ok, binding} =
               CheckpointBinding.new(
                 checkpoint_iri: checkpoint.identity,
                 repository: checkpoint.repository,
                 base_sha: checkpoint.base_sha,
                 graph_digest: Checkpoint.graph_digest(checkpoint)
               )

      assert %CheckpointBinding{} = binding
    end

    test "refuses missing fields with :refused_authority" do
      assert CheckpointBinding.new(checkpoint_iri: "urn:gall:checkpoint:x:y") ==
               {:refused, :refused_authority}
    end

    test "refuses bad SHA/digest shapes with :refused_subject_mismatch" do
      {:ok, checkpoint} = Checkpoint.new(@checkpoint_fields)

      assert CheckpointBinding.new(
               checkpoint_iri: checkpoint.identity,
               repository: checkpoint.repository,
               base_sha: "short",
               graph_digest: Checkpoint.graph_digest(checkpoint)
             ) == {:refused, :refused_subject_mismatch}

      assert CheckpointBinding.new(
               checkpoint_iri: checkpoint.identity,
               repository: checkpoint.repository,
               base_sha: checkpoint.base_sha,
               graph_digest: String.duplicate("z", 64)
             ) == {:refused, :refused_subject_mismatch}
    end

    test "refuses wrong URN namespaces with :refused_subject_mismatch" do
      {:ok, checkpoint} = Checkpoint.new(@checkpoint_fields)
      digest = Checkpoint.graph_digest(checkpoint)

      assert CheckpointBinding.new(
               checkpoint_iri: "urn:other:checkpoint:x:y",
               repository: checkpoint.repository,
               base_sha: checkpoint.base_sha,
               graph_digest: digest
             ) == {:refused, :refused_subject_mismatch}

      assert CheckpointBinding.new(
               checkpoint_iri: checkpoint.identity,
               repository: "urn:not-repo:x",
               base_sha: checkpoint.base_sha,
               graph_digest: digest
             ) == {:refused, :refused_subject_mismatch}
    end
  end

  describe "matches_checkpoint?/2 (drift falsifier)" do
    test "true when the binding pins exactly this checkpoint" do
      {:ok, checkpoint} = Checkpoint.new(@checkpoint_fields)
      {:ok, binding} = CheckpointBinding.from_checkpoint(checkpoint)

      assert CheckpointBinding.matches_checkpoint?(binding, checkpoint)
    end

    test "false when the checkpoint's content changed under the same identity" do
      {:ok, checkpoint} = Checkpoint.new(@checkpoint_fields)
      {:ok, binding} = CheckpointBinding.from_checkpoint(checkpoint)

      {:ok, mutated} = Checkpoint.new(Keyword.put(@checkpoint_fields, :standing, :ALIVE))

      assert Checkpoint.graph_digest(mutated) != binding.graph_digest
      refute CheckpointBinding.matches_checkpoint?(binding, mutated)
    end

    test "false for a different subject under the same content shape" do
      {:ok, checkpoint} = Checkpoint.new(@checkpoint_fields)
      {:ok, binding} = CheckpointBinding.from_checkpoint(checkpoint)

      {:ok, other} =
        Checkpoint.new(
          Keyword.merge(@checkpoint_fields,
            identity: "urn:gall:checkpoint:xaas:semantic-worker-002"
          )
        )

      refute CheckpointBinding.matches_checkpoint?(binding, other)
    end
  end
end
