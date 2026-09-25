defmodule Xaas.CaseStudies.WdFaSemanticWorkTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.SemanticWork

  test "known case prepares bounded work but does not close the case" do
    work = SemanticWork.for_case("known_firmware")

    assert work.standing == "READY_FOR_ENGINEER_DISPOSITION"
    assert work.obligation =~ "prepare known-path action"
    assert work.authority == "SELECT_CONSTRUCT_ONLY"
    assert work.human_gate == "ENGINEER_DISPOSITION_REQUIRED"
  end

  test "partial case turns missing evidence into an explicit obligation" do
    work = SemanticWork.for_case("partial_firmware")

    assert work.standing == "BLOCKED_ON_EVIDENCE"
    assert work.required_evidence == ["timeout_waveform"]
    assert work.obligation == "acquire required evidence: timeout_waveform"
  end

  test "unknown case constructs novel investigation work" do
    work = SemanticWork.for_case("novel_x")

    assert work.standing == "NOVEL_INVESTIGATION_REQUIRED"
    assert work.obligation == "open bounded novel-failure investigation"
    assert work.authority == "SELECT_CONSTRUCT_ONLY"
  end
end
