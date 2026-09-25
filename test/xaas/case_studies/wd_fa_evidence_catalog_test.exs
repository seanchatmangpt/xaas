defmodule Xaas.CaseStudies.WdFaEvidenceCatalogTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa
  alias Xaas.CaseStudies.WdFa.EvidenceCatalog

  test "every evidence identity surfaced by every scenario has a source-bound catalog entry" do
    for scenario <- WdFa.scenario_ids(),
        evidence_id <- WdFa.presentation_state(scenario).evidence do
      evidence = EvidenceCatalog.fetch(evidence_id)

      assert is_binary(evidence.kind)
      assert is_binary(evidence.modality)
      assert String.starts_with?(evidence.source_ref, "fixture://wd/")
    end
  end

  test "waveform retains plot modality instead of being flattened to text" do
    waveform = EvidenceCatalog.fetch("timeout_waveform")

    assert waveform.kind == "waveform"
    assert waveform.modality == "plot"
    assert waveform.source_ref =~ "timeout-waveform"
  end
end
