defmodule Xaas.CaseStudies.WdFa.Ingestion do
  @moduledoc """
  Deterministic ingestion of the repository-local multimodal WD fixture.

  The court preserves each original source and emits source-bound normalized
  projections. It does not flatten all modalities into one text blob.
  """

  @relative_root "priv/packs/wd_cs2_pack/source-fixtures/known_firmware"

  @spec ingest_known_fixture() :: map()
  def ingest_known_fixture do
    root = Application.app_dir(:xaas, @relative_root)

    structured_path = Path.join(root, "build_history.csv")
    report_path = Path.join(root, "fa_report.md")
    waveform_path = Path.join(root, "timeout_waveform.svg")

    %{
      case_id: "known_firmware",
      artifacts: [
        structured_artifact(structured_path),
        text_artifact(report_path),
        plot_artifact(waveform_path)
      ],
      evidence_ceiling: "REPO_LOCAL_FIXTURE"
    }
  end

  defp structured_artifact(path) do
    raw = File.read!(path)
    [header, row | _] = raw |> String.trim() |> String.split("\n")
    keys = String.split(header, ",")
    values = String.split(row, ",")

    %{
      id: "build_history",
      kind: "build_provenance",
      modality: "structured",
      classification: "INTERNAL_FIXTURE",
      purpose: "FA_TRIAGE",
      source_ref: "fixture://wd/known_firmware/build_history.csv",
      digest: digest(raw),
      normalized: Enum.zip(keys, values) |> Map.new(),
      bytes: byte_size(raw)
    }
  end

  defp text_artifact(path) do
    raw = File.read!(path)

    %{
      id: "fa_report",
      kind: "failure_analysis_report",
      modality: "text",
      classification: "INTERNAL_FIXTURE",
      purpose: "FA_TRIAGE",
      source_ref: "fixture://wd/known_firmware/fa_report.md",
      digest: digest(raw),
      normalized: %{text: raw},
      bytes: byte_size(raw)
    }
  end

  defp plot_artifact(path) do
    raw = File.read!(path)

    %{
      id: "timeout_waveform",
      kind: "waveform",
      modality: "plot",
      classification: "INTERNAL_FIXTURE",
      purpose: "FA_TRIAGE",
      source_ref: "fixture://wd/known_firmware/timeout_waveform.svg",
      digest: digest(raw),
      normalized: %{format: "image/svg+xml", title: "synthetic timeout waveform"},
      bytes: byte_size(raw)
    }
  end

  defp digest(raw) do
    "sha256:" <> (:crypto.hash(:sha256, raw) |> Base.encode16(case: :lower))
  end
end
