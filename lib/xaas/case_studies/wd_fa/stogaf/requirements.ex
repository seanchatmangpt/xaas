defmodule Xaas.CaseStudies.WdFa.Stogaf.Requirements do
  @moduledoc false

  @requirements [
    %{
      id: "R-01",
      name: "ranked failure modes",
      block: "TriageAdmission",
      standing: "ALIVE_FIXTURE"
    },
    %{id: "R-02", name: "supporting evidence", block: "EvidenceGraph", standing: "ALIVE_FIXTURE"},
    %{id: "R-03", name: "closest prior cases", block: "EvidenceGraph", standing: "ALIVE_FIXTURE"},
    %{
      id: "R-04",
      name: "specific next action",
      block: "SemanticWorkOrder",
      standing: "ALIVE_FIXTURE"
    },
    %{id: "R-05", name: "multimodal corpus", block: "EvidenceGraph", standing: "ALIVE_FIXTURE"},
    %{
      id: "R-06",
      name: "structured/unstructured joins",
      block: "EvidenceGraph",
      standing: "ALIVE_FIXTURE"
    },
    %{
      id: "R-07",
      name: "grounding and traceability",
      block: "VerificationReceipt",
      standing: "ALIVE_FIXTURE"
    },
    %{
      id: "R-08",
      name: "prevent confidently wrong root cause",
      block: "TriageAdmission",
      standing: "ALIVE_FIXTURE"
    },
    %{
      id: "R-09",
      name: "visible confidence basis",
      block: "MorningBriefView",
      standing: "ALIVE_FIXTURE"
    },
    %{id: "R-10", name: "human loop", block: "EngineerDisposition", standing: "ALIVE_FIXTURE"},
    %{
      id: "R-11",
      name: "known versus novel",
      block: "TriageAdmission",
      standing: "ALIVE_FIXTURE"
    },
    %{
      id: "R-12",
      name: "feedback and learning",
      block: "MachineExperience",
      standing: "ALIVE_FIXTURE"
    },
    %{id: "R-13", name: "MTTR and process measurement", block: "Evaluation", standing: "DESIGN"},
    %{
      id: "R-14",
      name: "security and governance",
      block: "Governance",
      standing: "PARTIAL_ALIVE"
    },
    %{id: "R-15", name: "evaluation rigor", block: "Verification", standing: "ALIVE_FIXTURE"},
    %{id: "R-16", name: "30/60/90 delivery", block: "MigrationPlan", standing: "DESIGN"}
  ]

  @spec all() :: [map()]
  def all, do: @requirements

  @spec mapped_count() :: non_neg_integer()
  def mapped_count, do: length(@requirements)

  @spec standing_counts() :: map()
  def standing_counts do
    Enum.frequencies_by(@requirements, & &1.standing)
  end
end
