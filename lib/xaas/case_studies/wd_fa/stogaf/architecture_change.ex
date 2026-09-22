defmodule Xaas.CaseStudies.WdFa.Stogaf.ArchitectureChange do
  @moduledoc """
  STOGAF Phase H projection for a verified WD MachineExperience.
  """

  alias Xaas.CaseStudies.WdFa.StandardCatalog

  @spec from_experience(map()) :: {:ok, map()} | {:error, term()}
  def from_experience(experience) do
    with {:ok, standard} <- StandardCatalog.admit_experience(experience) do
      {:ok,
       %{
         adm_phase: "H ARCHITECTURE_CHANGE_MANAGEMENT",
         trigger: "VERIFIED_MACHINE_EXPERIENCE",
         experience_id: experience.id,
         from_standard: standard.previous_version,
         to_standard: standard.version,
         change: "add admitted failure-mode standard work",
         mode_id: experience.mode_id,
         evidence_ceiling: standard.evidence_ceiling,
         receipt_digest: standard.receipt_digest,
         authority: "CONSTRUCT_ONLY"
       }}
    end
  end
end
