defmodule Xaas.Ultracode.SemanticWorkTest do
  use ExUnit.Case, async: true

  alias Xaas.Ultracode.SemanticWork

  @checkpoint %{
    checkpoint_iri: "urn:gall:checkpoint:xaas:001",
    graph_digest: "sha256:" <> String.duplicate("a", 64),
    repository: "xaas",
    base_sha: String.duplicate("b", 40),
    goal: "Implement the admitted semantic-work subject.",
    provider: "zcode",
    verifier_suite: "xaas-dod",
    dependencies: [%{id: "dep-1", standing: "ALIVE"}],
    standing: "UNKNOWN"
  }

  test "admits a bounded descriptor with ALIVE dependencies" do
    assert {:ok, admitted} = SemanticWork.admit(@checkpoint)
    assert admitted.checkpoint_iri == @checkpoint.checkpoint_iri
  end

  test "UNKNOWN dependency is a typed refusal" do
    checkpoint = put_in(@checkpoint, [:dependencies], [%{id: "dep-1", standing: "UNKNOWN"}])
    assert {:error, {:refused_dependency, [_]}} = SemanticWork.admit(checkpoint)
  end

  test "bad base identity is refused" do
    assert {:error, {:refused_semantic_work, {:invalid, :base_sha}}} =
             SemanticWork.admit(%{@checkpoint | base_sha: "main"})
  end

  test "frontier selects only UNKNOWN checkpoints whose dependencies are ALIVE" do
    blocked = %{@checkpoint | checkpoint_iri: "urn:gall:blocked", dependencies: ["UNKNOWN"]}
    done = %{@checkpoint | checkpoint_iri: "urn:gall:done", standing: "ALIVE"}

    assert [selected] = SemanticWork.frontier([blocked, done, @checkpoint])
    assert selected.checkpoint_iri == @checkpoint.checkpoint_iri
  end

  test "receipt turtle preserves checkpoint and exact candidate identities" do
    run = %{id: "run-1"}
    epoch = %{id: "epoch-1", final_head: String.duplicate("c", 40)}
    receipt = %{id: "receipt-1", outcome: :alive}

    ttl = SemanticWork.receipt_turtle(@checkpoint, run, epoch, receipt)

    assert ttl =~ "<urn:gall:checkpoint:xaas:001>"
    assert ttl =~ "gall:baseSha \"#{@checkpoint.base_sha}\""
    assert ttl =~ "gall:candidateSha \"#{epoch.final_head}\""
    assert ttl =~ "gall:standing gall:ALIVE"
  end
end
