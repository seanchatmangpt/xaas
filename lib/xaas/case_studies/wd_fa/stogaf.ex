defmodule Xaas.CaseStudies.WdFa.Stogaf do
  @moduledoc """
  Semantic TOGAF (STOGAF) projection for the WD Case Study 2 demo.

  STOGAF is a TOGAF-compatible semantic execution profile, not an official
  Open Group specification. The canonical architecture state is admitted
  enterprise state O*. Views, work orders, generated applications and
  presentation surfaces are projections of that state rather than independent
  sources of truth.
  """

  @conformance_levels [
    %{id: "ST-0", name: "DOCUMENTED"},
    %{id: "ST-1", name: "ADDRESSABLE"},
    %{id: "ST-2", name: "LINKED"},
    %{id: "ST-3", name: "PROVENANCED"},
    %{id: "ST-4", name: "CONSTRAINED"},
    %{id: "ST-5", name: "GENERATED"},
    %{id: "ST-6", name: "AUTONOMIC"},
    %{id: "ST-7", name: "ACTUATED"},
    %{id: "ST-8", name: "CLOSED_LOOP"},
    %{id: "ST-9", name: "LEARNING"}
  ]

  @adm_phases %{
    "PRELIMINARY" => "principles, vocabulary, authority and evidence ceilings",
    "A" => "architecture vision, scope and measurable outcome",
    "B" => "business architecture and current FA operating process",
    "C" => "data and application architecture for evidence, work and views",
    "D" => "technology architecture for Ash, OCEL, Postgres and generated runtimes",
    "E" => "opportunities, solution building blocks and reusable platform capability",
    "F" => "migration planning and 30/60/90 sequencing",
    "G" => "implementation governance through exact-head courts and receipts",
    "H" => "architecture change management through verified MachineExperience",
    "REQUIREMENTS" => "continuous requirement, constraint and evidence management"
  }

  @building_blocks [
    "EvidenceGraph",
    "TriageAdmission",
    "SemanticWorkOrder",
    "EngineerDisposition",
    "VerificationReceipt",
    "MachineExperience",
    "MorningBriefView",
    "GeneratedProjection"
  ]

  @viewpoints [
    %{
      id: "fa-engineer",
      view: "FA Morning Brief",
      concern: "what requires engineer judgment now"
    },
    %{
      id: "fa-manager",
      view: "FA operating board",
      concern: "queue, blockers, evidence and throughput"
    },
    %{id: "executive", view: "FA Agent Board Deck", concern: "business value, risk and adoption"},
    %{
      id: "architecture",
      view: "System / Space",
      concern: "canonical state, interfaces and authority"
    },
    %{
      id: "assessment",
      view: "WD Case Study 2 Deck",
      concern: "requirements, tradeoffs and evidence"
    }
  ]

  @invariants [
    "No architecture artifact should require a human to reconstruct information the enterprise can derive.",
    "The graph is law; Jira and presentation artifacts are projections.",
    "Candidate ranking does not create authority or KNOWN standing.",
    "Missing required evidence yields UNKNOWN, PARTIAL or BLOCKED rather than guessed completion.",
    "No consequential actuation is accepted without explicit authority and a receipt.",
    "MachineExperience requires verified consequence, provenance, applicability, evidence ceiling and replay identity.",
    "Architecture views are deterministic projections of admitted architecture state."
  ]

  @spec conformance_levels() :: [map()]
  def conformance_levels, do: @conformance_levels

  @spec adm_phases() :: map()
  def adm_phases, do: @adm_phases

  @spec invariants() :: [String.t()]
  def invariants, do: @invariants

  @spec demo_projection() :: map()
  def demo_projection do
    %{
      rfc: "Semantic TOGAF v26.9.22 RFC",
      equation: "A = μ(O*)",
      current_conformance: "ST-4 CONSTRAINED",
      target_conformance: "ST-6 AUTONOMIC",
      evidence_ceiling: "REPO_LOCAL_FIXTURE",
      current_adm_phase: "G IMPLEMENTATION_GOVERNANCE",
      next_adm_phase: "H ARCHITECTURE_CHANGE_MANAGEMENT",
      authority: "SELECT_CONSTRUCT_ONLY",
      human_gate: "ENGINEER_DISPOSITION_REQUIRED",
      baseline:
        "fragmented FA evidence and repeated human reconstruction across reports and structured provenance",
      target:
        "closed semantic FA quality loop whose verified investigations become reusable prior art",
      gap:
        "canonical architecture state, deterministic work projection, generated views and verified learning closure",
      building_blocks: @building_blocks,
      viewpoints: @viewpoints,
      work_projection: "sJira",
      capability_projection: "SA2A",
      canonical_state: "O*",
      architecture_artifact: "μ(O*)"
    }
  end

  @spec conformance_status() :: [map()]
  def conformance_status do
    [
      %{level: "ST-0", standing: "ALIVE", evidence: "RFC and WD conformance package"},
      %{level: "ST-1", standing: "ALIVE", evidence: "stable object, event and work identities"},
      %{
        level: "ST-2",
        standing: "ALIVE",
        evidence: "OCEL object/event relations and semantic work links"
      },
      %{
        level: "ST-3",
        standing: "ALIVE",
        evidence: "source-bound evidence, OCEL and receipt provenance"
      },
      %{
        level: "ST-4",
        standing: "ALIVE",
        evidence: "SHACL/rule constraints and explicit authority ceiling"
      },
      %{
        level: "ST-5",
        standing: "PARTIAL_ALIVE",
        evidence: "views exist; full graph-to-view manufacture is still being closed"
      },
      %{
        level: "ST-6",
        standing: "PARTIAL_ALIVE",
        evidence: "sJira/SA2A/autonomic surfaces exist; WD end-to-end closure still under court"
      },
      %{
        level: "ST-7",
        standing: "UNKNOWN",
        evidence: "no consequential production DO authority is claimed"
      },
      %{
        level: "ST-8",
        standing: "UNKNOWN",
        evidence:
          "fixture replay exists, but cumulative production closed-loop standing is not claimed"
      },
      %{
        level: "ST-9",
        standing: "UNKNOWN",
        evidence: "production organizational-learning effect remains unmeasured"
      }
    ]
  end
end
