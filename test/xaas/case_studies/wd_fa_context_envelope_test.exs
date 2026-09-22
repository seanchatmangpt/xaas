defmodule Xaas.CaseStudies.WdFaContextEnvelopeTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.ContextEnvelope

  test "operator context envelope reconstructs the exact partial case" do
    assert {:ok, envelope} =
             ContextEnvelope.build("partial_firmware", "fa-engineer")

    assert envelope.schema == "WD_FA_CONTEXT_ENVELOPE_V1"
    assert envelope.canonical_subject == "urn:xaas:wd-cs2:case:partial_firmware"
    assert envelope.viewpoint == "fa-engineer"
    assert envelope.classification == "PARTIAL"
    assert envelope.work_standing == "BLOCKED_ON_EVIDENCE"
    assert envelope.authority_ceiling == "SELECT_CONSTRUCT_ONLY"
    assert envelope.human_gate == "ENGINEER_DISPOSITION_REQUIRED"
    assert envelope.evidence_ceiling == "REPO_LOCAL_FIXTURE"
    assert envelope.replay_identity == nil
  end

  test "verified replay envelope carries replay identity" do
    assert {:ok, envelope} =
             ContextEnvelope.build("novel_x", "assessment", true)

    assert envelope.classification == "KNOWN"
    assert envelope.admitted_mode == "MODE-X-NOVEL"
    assert envelope.replay_identity == "NOVEL-X-REPLAY"
  end

  test "unknown viewpoint fails closed" do
    assert {:error, :unknown_viewpoint} =
             ContextEnvelope.build("known_firmware", "invented-view")
  end

  test "unknown case fails closed" do
    assert {:error, :unknown_case} =
             ContextEnvelope.build("missing-case", "fa-engineer")
  end
end
