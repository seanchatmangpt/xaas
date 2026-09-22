defmodule Xaas.CaseStudies.WdFa.EvidenceCatalog do
  @moduledoc false

  @evidence %{
    "fw_trace" => %{
      kind: "firmware_trace",
      modality: "structured",
      source_ref: "fixture://wd/fa/firmware#trace"
    },
    "timeout_waveform" => %{
      kind: "waveform",
      modality: "plot",
      source_ref: "fixture://wd/fa/presentation#timeout-waveform"
    },
    "lot_genealogy" => %{
      kind: "genealogy",
      modality: "structured",
      source_ref: "fixture://wd/fa/datalake#lot-genealogy"
    },
    "servo_trace" => %{
      kind: "servo_trace",
      modality: "structured",
      source_ref: "fixture://wd/fa/servo#trace"
    },
    "media_scan" => %{
      kind: "media_scan",
      modality: "structured",
      source_ref: "fixture://wd/fa/media#scan"
    }
  }

  @spec fetch(String.t()) :: map()
  def fetch(id), do: Map.fetch!(@evidence, id)

  @spec all() :: map()
  def all, do: @evidence
end
