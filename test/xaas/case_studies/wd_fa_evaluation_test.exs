defmodule Xaas.CaseStudies.WdFaEvaluationTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.Evaluation

  test "offline report executes all six negative/positive controls" do
    report = Evaluation.offline_report()

    assert report.evidence_ceiling == "REPO_LOCAL_FIXTURE"
    assert report.controls_total == 6
    assert report.controls_passed == 6
    assert report.all_controls_passed
    assert Enum.all?(report.controls, & &1.passed)
  end

  test "production outcome metrics remain explicitly unmeasured" do
    metrics = Evaluation.offline_report().production_metrics

    assert metrics.mttr == "UNMEASURED"
    assert metrics.false_known_rate == "UNMEASURED"
    assert metrics.false_unknown_rate == "UNMEASURED"
    assert metrics.engineer_touches == "UNMEASURED"
    assert metrics.machine_experience_reuse_rate == "UNMEASURED"
  end
end
