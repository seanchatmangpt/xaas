defmodule Xaas.CaseStudies.WdFaEvidencePolicyTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.EvidencePolicy

  test "authorized fixture evidence is admitted for the declared purpose" do
    context = %{clearances: ["INTERNAL_FIXTURE"], purpose: "FA_TRIAGE"}

    assert {:ok, evidence} = EvidencePolicy.admit("timeout_waveform", context)
    assert evidence.classification == "INTERNAL_FIXTURE"
    assert evidence.purpose == "FA_TRIAGE"
  end

  test "classification mismatch fails closed" do
    context = %{clearances: ["PUBLIC"], purpose: "FA_TRIAGE"}

    assert {:error, :classification_not_authorized} =
             EvidencePolicy.admit("timeout_waveform", context)
  end

  test "purpose mismatch fails closed" do
    context = %{clearances: ["INTERNAL_FIXTURE"], purpose: "MARKETING"}

    assert {:error, :purpose_not_authorized} =
             EvidencePolicy.admit("timeout_waveform", context)
  end

  test "private evidence remains refused without explicit private clearance" do
    context = %{clearances: ["INTERNAL_FIXTURE"], purpose: "FA_TRIAGE"}

    assert {:error, :classification_not_authorized} =
             EvidencePolicy.admit_private_fixture(context)
  end
end
