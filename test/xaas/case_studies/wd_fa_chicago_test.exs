defmodule Xaas.CaseStudies.WdFaChicagoTest do
  @moduledoc """
  Chicago-style WD CS2 qualification: real Postgres, real Ash actions, real
  OCEL rows and relations, no owned-collaborator mocks.
  """
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  test "KNOWN requires deterministic evidence closure, not candidate score" do
    known = WdFa.presentation_state("known_firmware")
    assert known.classification == "KNOWN"
    assert known.standing == "ALIVE"
    assert known.admitted_mode == "MODE-A-FIRMWARE"
    assert known.confidence_basis == "DETERMINISTIC_RULE_AND_REQUIRED_EVIDENCE"
    assert known.human_gate == "ENGINEER_DISPOSITION_REQUIRED"
    assert known.authority == "SELECT_CONSTRUCT_ONLY"
  end

  test "PARTIAL remains unadmitted when required waveform evidence is absent" do
    partial = WdFa.presentation_state("partial_firmware")
    assert partial.classification == "PARTIAL"
    assert partial.standing == "PARTIAL_ALIVE"
    assert partial.admitted_mode == nil
    assert partial.missing_evidence == ["timeout_waveform"]
  end

  test "a plausible high-scoring novel candidate cannot counterfeit KNOWN" do
    unknown = WdFa.presentation_state("novel_x")
    [candidate | _] = unknown.ranked_hypotheses
    assert candidate.score == 0.68
    assert unknown.classification == "UNKNOWN"
    assert unknown.standing == "UNKNOWN"
    assert unknown.admitted_mode == nil
    assert unknown.next_action == "ESCALATE_NOVEL_INVESTIGATION"
  end

  test "verified MachineExperience converts the exact novel fixture into reusable prior art" do
    before = WdFa.presentation_state("novel_x")
    learned = WdFa.presentation_state("novel_x", true)
    assert before.classification == "UNKNOWN"
    assert learned.classification == "KNOWN"
    assert learned.admitted_mode == "MODE-X-NOVEL"
    assert learned.prior_cases == ["MX-NOVEL-X-001"]
    assert learned.confidence_basis == "ADMITTED_MACHINE_EXPERIENCE"
  end

  test "real Ash/OCEL persistence binds observation to manufacturing and evidence objects" do
    %{projection: projection, state: state} = WdFa.seed_ocel!("known_firmware")
    assert state.classification == "KNOWN"
    assert Enum.sort(projection["eventTypes"]) == ["failure_observed", "triage_constructed"]

    for type <- WdFa.object_types(), do: assert(type in projection["objectTypes"])

    triage = Enum.find(projection["events"], &(&1["type"] == "triage_constructed"))
    assert triage["attributes"]["classification"] == "KNOWN"
    assert triage["attributes"]["authority"] == "SELECT_CONSTRUCT_ONLY"
    assert triage["attributes"]["human_gate"] == "ENGINEER_DISPOSITION_REQUIRED"
    assert length(triage["relationships"]) >= 6
  end
end
