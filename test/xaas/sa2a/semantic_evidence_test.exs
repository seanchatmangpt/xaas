defmodule Xaas.Sa2a.SemanticEvidenceTest do
  use ExUnit.Case, async: true

  alias Xaas.Sa2a.SemanticEvidence

  defp ref(overrides \\ %{}) do
    Map.merge(
      %{
        "schema" => "sa2a.semantic-evidence-envelope.v1",
        "contractVersion" => "v26.9.29",
        "subject" => "urn:customer:42",
        "sourceDigest" => "sha256:" <> String.duplicate("a", 64),
        "graphDigest" => "sha256:" <> String.duplicate("b", 64),
        "replayIdentity" => "replay:customer:42",
        "envelopeDigest" => "sha256:" <> String.duplicate("c", 64),
        "authority" => "NONE",
        "consequence" => "EVIDENCE_ONLY"
      },
      overrides
    )
  end

  test "runtime admits portable evidence without authority promotion" do
    assert {:ok, candidate} = SemanticEvidence.attach(%{"id" => "c1"}, ref())
    assert candidate["semantic_evidence"]["authority"] == "NONE"
    assert {:ok, "sha256:" <> digest} = SemanticEvidence.digest(candidate["semantic_evidence"])
    assert byte_size(digest) == 64
  end

  test "runtime refuses semantic evidence posing as authority" do
    assert {:error, %{code: :refused_semantic_evidence, subject: :authority}} =
             SemanticEvidence.attach(%{"id" => "c1"}, ref(%{"authority" => "DO"}))
  end

  test "nil evidence remains a valid compatibility path" do
    assert {:ok, %{"id" => "c1"}} = SemanticEvidence.attach(%{"id" => "c1"}, nil)
  end
end
