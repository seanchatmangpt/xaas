defmodule Xaas.CaseStudies.WdFa.StandardCatalog do
  @moduledoc """
  Versioned repository-local standard-work catalog for the WD CS2 fixture.

  It models the architecture-change consequence of admitted MachineExperience.
  """

  @baseline %{
    version: "CS2-V1",
    modes: [
      %{id: "MODE-A-FIRMWARE", next_action: "RUN_FIRMWARE_DIAGNOSTIC_T14"},
      %{id: "MODE-B-SUPPLIER", next_action: "INSPECT_SUPPLIER_LOT"}
    ],
    evidence_ceiling: "REPO_LOCAL_FIXTURE"
  }

  @spec baseline() :: map()
  def baseline, do: @baseline

  @spec admit_experience(map()) :: {:ok, map()} | {:error, term()}
  def admit_experience(experience) when is_map(experience) do
    cond do
      experience.evidence_ceiling != "REPO_LOCAL_FIXTURE" ->
        {:error, :evidence_ceiling_mismatch}

      not is_binary(experience.receipt_digest) ->
        {:error, :receipt_required}

      true ->
        mode = %{id: experience.mode_id, next_action: experience.next_action}

        {:ok,
         %{
           version: "CS2-V2",
           previous_version: @baseline.version,
           modes: @baseline.modes ++ [mode],
           admitted_experience: experience.id,
           receipt_digest: experience.receipt_digest,
           evidence_ceiling: @baseline.evidence_ceiling
         }}
    end
  end
end
