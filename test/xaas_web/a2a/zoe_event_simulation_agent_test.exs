defmodule XaasWeb.A2A.ZoeEventSimulationAgentTest do
  use ExUnit.Case, async: false

  setup do
    name = :"zoe_event_simulation_agent_#{System.unique_integer([:positive])}"
    {:ok, pid} = XaasWeb.A2A.ZoeEventSimulationAgent.start_link(name: name)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{agent: pid}
  end

  defp task_text(task) do
    (task.artifacts ++ [%{parts: []}])
    |> Enum.flat_map(& &1.parts)
    |> Enum.map_join(" ", fn
      %A2A.Part.Text{text: text} -> text
      _ -> ""
    end)
  end

  test "real A2A call returns the simulation contract", %{agent: agent} do
    assert {:ok, task} = A2A.call(agent, "contract")
    assert task.status.state == :completed

    assert {:ok, contract} = Jason.decode(task_text(task))
    assert contract["simulation_protocol"] == "sa2a-event-simulation/v1"
    assert contract["do_authority"] == false
  end

  test "real A2A call runs a full event simulation", %{agent: agent} do
    payload = %{
      "snapshot" => %{
        "contract_version" => "zoe-event-ops/v1",
        "provider" => "planning_center",
        "authority_boundary" => "OBSERVE",
        "do_authority" => false,
        "event" => %{
          "ref" => "event:youth-night",
          "name" => "Youth Night",
          "starts_at" => "2026-09-22T19:00:00-07:00"
        },
        "observations" => %{
          "roster" => [%{"person_ref" => "person:tanner", "role" => "registration"}],
          "registrations" => [
            %{"registration_ref" => "reg:1", "person_ref" => "person:student-1"}
          ],
          "check_ins" => [
            %{"check_in_ref" => "check:1", "person_ref" => "person:student-1"}
          ]
        }
      },
      "scenario" => %{
        "walk_ins" => 1,
        "security_staff" => 1,
        "security_required" => 2,
        "incidents" => [
          %{
            "incident_ref" => "incident:near-miss",
            "kind" => "SAFETY_NEAR_MISS",
            "severity" => "high"
          }
        ],
        "resolutions" => []
      }
    }

    assert {:ok, task} = A2A.call(agent, "simulate " <> Jason.encode!(payload))
    assert task.status.state == :completed

    assert {:ok, result} = Jason.decode(task_text(task))
    assert result["simulation_status"] == "COMPLETE"
    assert result["attendance"]["total"] == 2
    assert result["security"]["shortfall"] == 1
    assert result["do_authority"] == false

    report =
      Enum.find(
        result["trace"],
        &(&1["capability_id"] == "zoe.event.security.incident.report")
      )

    assert report["routed_to"] == ["church_event_lead", "security_management"]
  end
end
