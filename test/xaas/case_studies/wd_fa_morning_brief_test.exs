defmodule Xaas.CaseStudies.WdFaMorningBriefTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.MorningBrief

  test "brief allocates human attention from deterministic case standing" do
    brief = MorningBrief.summary()

    assert brief.total_subjects == 3
    assert brief.needs_judgment == 1
    assert brief.missing_evidence == 1
    assert brief.prior_art_ready == 1
    assert brief.authority == "SELECT_CONSTRUCT_ONLY"
    assert brief.human_gate == "ENGINEER_DISPOSITION_REQUIRED"
    assert brief.semantic_rule =~ "consequential disposition remains with the engineer"
  end
end
