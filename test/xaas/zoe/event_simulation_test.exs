defmodule Xaas.Zoe.EventSimulationTest do
  use ExUnit.Case, async: true

  alias Xaas.Zoe.EventSimulation

  test "simulates the entire event and preserves SA2A as candidate-only" do
    event = %{
      event_id: "youth-2026-09-20",
      observations: [
        %{
          seq: 1,
          phase: :pre_event,
          registrations: 120,
          check_ins: 0,
          volunteers: 18,
          registration_staff: 2,
          administration_staff: 0,
          security_staff: 1,
          registration_exceptions: 0,
          roster_complete?: false,
          attendance_submitted?: false,
          incidents: []
        },
        %{
          seq: 2,
          phase: :arrival,
          registrations: 120,
          check_ins: 20,
          volunteers: 18,
          registration_staff: 2,
          administration_staff: 1,
          security_staff: 1,
          registration_exceptions: 3,
          roster_complete?: true,
          attendance_submitted?: false,
          incidents: []
        },
        %{
          seq: 3,
          phase: :live_event,
          registrations: 120,
          check_ins: 110,
          volunteers: 18,
          registration_staff: 3,
          administration_staff: 1,
          security_staff: 1,
          registration_exceptions: 0,
          roster_complete?: true,
          attendance_submitted?: false,
          incidents: [
            %{id: "umbrella-near-miss-1", kind: :near_miss, subject_ref: "gate"}
          ]
        },
        %{
          seq: 4,
          phase: :closeout,
          registrations: 120,
          check_ins: 114,
          volunteers: 18,
          registration_staff: 1,
          administration_staff: 1,
          security_staff: 2,
          registration_exceptions: 0,
          roster_complete?: true,
          attendance_submitted?: false,
          incidents: []
        }
      ]
    }

    policy = %{
      registration_per_staff: 20,
      security_per_guard: 50,
      minimum_admin_staff: 1
    }

    assert {:ok, simulation} = EventSimulation.simulate(event, policy)

    assert simulation["schema"] == "zoe.event.simulation.v1"
    assert simulation["authority"] == "SELECT_CONSTRUCT"
    assert simulation["standing"] == "CANDIDATE"
    assert simulation["sa2a"]["dispatch"] == "NOT_EXECUTED"
    assert simulation["sa2a"]["authority"] == "NONE"
    assert simulation["summary"]["observation_count"] == 4
    assert simulation["summary"]["incident_count"] == 1

    capabilities = simulation["summary"]["capability_ids"]

    assert "zoe.event.admin.complete_roster" in capabilities
    assert "zoe.event.admin.request_reinforcement" in capabilities
    assert "zoe.event.registration.request_reinforcement" in capabilities
    assert "zoe.event.registration.resolve_exceptions" in capabilities
    assert "zoe.event.security.request_reinforcement" in capabilities
    assert "zoe.event.security.report_incident" in capabilities
    assert "zoe.event.admin.submit_attendance" in capabilities

    assert Enum.all?(simulation["obligations"], fn obligation ->
             obligation["protocol"] == "SA2A" and
               obligation["authority"] == "NONE" and
               obligation["authority_boundary"] == "CONSTRUCT_ONLY" and
               obligation["dispatch"] == "NOT_EXECUTED" and
               obligation["standing"] == "CANDIDATE" and
               not Map.has_key?(obligation, "receipt") and
               not Map.has_key?(obligation, "do")
           end)

    assert {:ok, replay} = EventSimulation.simulate(event, policy)
    assert replay["digest"] == simulation["digest"]
    assert replay["obligations"] == simulation["obligations"]
  end

  test "refuses implicit capacity policy" do
    assert {:error, {:invalid, :registration_per_staff}} =
             EventSimulation.simulate(
               %{
                 event_id: "event",
                 observations: [
                   %{
                     seq: 1,
                     phase: :pre_event,
                     registrations: 0,
                     check_ins: 0,
                     volunteers: 0,
                     registration_staff: 0,
                     administration_staff: 0,
                     security_staff: 0,
                     registration_exceptions: 0,
                     roster_complete?: true,
                     attendance_submitted?: true,
                     incidents: []
                   }
                 ]
               },
               %{}
             )
  end
end
