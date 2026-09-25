defmodule Xaas.CaseStudies.WdFa.EvidencePolicy do
  @moduledoc """
  Fail-closed repository-local evidence authorization for WD CS2 fixtures.

  This models policy mechanics only. It is not a WD IAM integration.
  """

  alias Xaas.CaseStudies.WdFa.EvidenceCatalog

  @spec admit(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def admit(evidence_id, context) when is_map(context) do
    evidence = EvidenceCatalog.fetch(evidence_id)
    clearances = Map.get(context, :clearances, [])
    purpose = Map.get(context, :purpose)

    cond do
      evidence.classification not in clearances ->
        {:error, :classification_not_authorized}

      evidence.purpose != purpose ->
        {:error, :purpose_not_authorized}

      true ->
        {:ok, evidence}
    end
  end

  @spec private_fixture() :: map()
  def private_fixture do
    %{
      id: "private_lab_note",
      classification: "PRIVATE_FIXTURE",
      purpose: "FA_TRIAGE",
      source_ref: "fixture://wd/private/lab-note"
    }
  end

  @spec admit_private_fixture(map()) :: {:ok, map()} | {:error, term()}
  def admit_private_fixture(context) do
    evidence = private_fixture()
    clearances = Map.get(context, :clearances, [])
    purpose = Map.get(context, :purpose)

    cond do
      evidence.classification not in clearances ->
        {:error, :classification_not_authorized}

      evidence.purpose != purpose ->
        {:error, :purpose_not_authorized}

      true ->
        {:ok, evidence}
    end
  end
end
