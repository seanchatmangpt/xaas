defmodule Xaas.CaseStudies.WdFaIngestionTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.Ingestion

  test "multimodal fixture preserves structured, text and plot sources" do
    payload = Ingestion.ingest_known_fixture()

    assert payload.case_id == "known_firmware"
    assert payload.evidence_ceiling == "REPO_LOCAL_FIXTURE"

    by_modality = Map.new(payload.artifacts, &{&1.modality, &1})
    assert Map.keys(by_modality) |> Enum.sort() == ["plot", "structured", "text"]

    assert by_modality["structured"].normalized["serial"] == "SN-0001"
    assert by_modality["structured"].normalized["lot"] == "L-42"
    assert by_modality["structured"].normalized["firmware"] == "FW-3.14"

    assert by_modality["text"].normalized.text =~ "intermittent command timeout"
    assert by_modality["plot"].normalized.format == "image/svg+xml"

    Enum.each(payload.artifacts, fn artifact ->
      assert String.starts_with?(artifact.source_ref, "fixture://wd/")
      assert String.starts_with?(artifact.digest, "sha256:")
      assert artifact.bytes > 0
    end)
  end

  test "plot remains a plot projection rather than destructive text normalization" do
    payload = Ingestion.ingest_known_fixture()
    plot = Enum.find(payload.artifacts, &(&1.id == "timeout_waveform"))

    assert plot.modality == "plot"
    assert plot.kind == "waveform"
    refute Map.has_key?(plot.normalized, :text)
  end
end
