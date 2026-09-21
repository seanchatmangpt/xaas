defmodule Xaas.Zoe.EventSimulationTest do
  use ExUnit.Case, async: true

  alias Xaas.Zoe.EventSimulation

  defp snapshot do
    %{
      "contract_version" => "zoe-event-ops/v1",
      "provider" => "planning_center",
      "authority_boundary" => "OBSERVE",
      "do_authority" => false,
      "standing" => "UNKNOWN",
      "evidence_ceiling" => "CONTRACT_ONLY",
      "event" => %{
        "ref" => "event:youth-night",
        "name" => "Youth Night",
        "starts_at" => "2026-09-22T19:00:00-07:00"
      },
      "observations" => %{
        "roster" => [
          %{"person_ref" => "person:tanner", "role" => "registration"},
          %{"person_ref" => "person:security-1", "role" => "security"}
        ],
        "registrations" => [
          %{"registration_ref" => "reg:1", "person_ref" => "person:student-1"},
          %{"registration_ref" => "reg:2", "person_ref" => "person:student-2"},
          %{"registration_ref" => "reg:3", "person_ref" => "person:student-3"}
        ],
        "check_ins" => [
          %{"check_in_ref" => "check:1", "person_ref" => "person:student-1"},
          %{"check_in_ref" => "check:2", "person_ref" => "person:student-2"}
        ]
      },
      "counts" => %{"roster" => 2, "registrations" => 3, "check_ins" => 2},
      "source_refs" => ["pco:event:youth-night"]
    }
  end

  test "simulates the entire event without manufacturing DO authority" do
    scenario = %{
      "walk_ins" => 2,
      "security_staff" => 1,
      "security_required" => 2,
      "incidents" => [
        %{
          "incident_ref" => "incident:gate-flow",
          "kind" => "FLOW_CONTROL_DEGRADED",
          "severity" => "moderate",
          "reporter_ref" => "person:observer"
        },
        %{
          "incident_ref" => "incident:near-miss",
          "kind" => "SAFETY_NEAR_MISS",
          "severity" => "high",
          "reporter_ref" => "person:observer",
          "subject_ref" => "person:participant"
        }
      ],
      "resolutions" => ["incident:gate-flow"]
    }

    assert {:ok, result} = EventSimulation.simulate(snapshot(), scenario)

    assert result["simulation_status"] == "COMPLETE"
    assert result["standing"] == "UNKNOWN"
    assert result["evidence_ceiling"] == "SIMULATION_ONLY"
    refute result["do_authority"]
    assert result["attendance"] == %{"checked_in" => 2, "walk_ins" => 2, "total" => 4}
    assert result["security"] == %{"staffed" => 1, "required" => 2, "shortfall" => 1}

    assert [
             %{
               "kind" => "security_reinforcement",
               "owner_role" => "security_management",
               "required_count" => 1,
               "state" => "open"
             }
           ] = result["obligations"]

    incident_reports =
      Enum.filter(
        result["trace"],
        &(&1["capability_id"] == "zoe.event.security.incident.report")
      )

    assert length(incident_reports) == 2

    assert Enum.all?(incident_reports, fn report ->
             report["routed_to"] == ["church_event_lead", "security_management"]
           end)

    assert Enum.all?(result["trace"], &(&1["do_authority"] == false))

    assert Enum.all?(result["trace"], fn trace ->
             trace["authority_boundary"] in ["OBSERVE", "SELECT", "CONSTRUCT"]
           end)

    assert Enum.any?(
             result["trace"],
             &(&1["capability_id"] == "zoe.event.security.reinforcement.request")
           )

    assert Enum.any?(
             result["trace"],
             &(&1["capability_id"] == "zoe.event.attendance.reconcile")
           )

    unresolved =
      result["incidents"]
      |> Enum.filter(&(&1["state"] != "resolved"))
      |> Enum.map(& &1["incident_ref"])

    assert unresolved == ["incident:near-miss"]

    assert %{
             "kind" => "SIMULATION_RECEIPT",
             "algorithm" => "sha256",
             "production_receipt" => false,
             "digest" => digest
           } = result["simulation_receipt"]

    assert byte_size(digest) == 64
  end

  test "the same event and scenario produce the same simulation receipt" do
    scenario = %{
      "walk_ins" => 1,
      "security_staff" => 2,
      "security_required" => 2,
      "incidents" => [],
      "resolutions" => []
    }

    assert {:ok, left} = EventSimulation.simulate(snapshot(), scenario)
    assert {:ok, right} = EventSimulation.simulate(snapshot(), scenario)

    assert left["simulation_receipt"]["digest"] == right["simulation_receipt"]["digest"]
  end

  test "refuses youth PII at the simulation boundary" do
    unsafe =
      put_in(
        snapshot(),
        ["observations", "registrations"],
        [
          %{
            "registration_ref" => "reg:1",
            "person_ref" => "person:opaque",
            "first_name" => "Minor"
          }
        ]
      )

    assert {:error, {:minor_pii_refused, path}} = EventSimulation.simulate(unsafe, %{})
    assert path =~ "first_name"
  end

  test "refuses a snapshot that attempts to carry DO authority" do
    assert {:error, {:invalid_contract, :do_authority}} =
             snapshot()
             |> Map.put("do_authority", true)
             |> EventSimulation.simulate(%{})
  end
end
