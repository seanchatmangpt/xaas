defmodule Xaas.CaseStudies.WdFaProcessDeltaTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.ProcessDelta

  test "verified experience retires the novel-investigation work class for the exact fixture" do
    delta = ProcessDelta.verified_replay_delta()

    assert delta.before.classification == "UNKNOWN"
    assert delta.before.work_standing == "NOVEL_INVESTIGATION_REQUIRED"
    assert delta.after.classification == "KNOWN"
    assert delta.after.work_standing == "READY_FOR_ENGINEER_DISPOSITION"
    assert delta.novel_investigation_retired
    assert delta.production_time_saved == "UNMEASURED"
    assert delta.evidence_ceiling == "REPO_LOCAL_FIXTURE"
  end
end
