defmodule Xaas.ZoeDeepeningTest do
  @moduledoc """
  W744 zoe-deepening lane: real Chicago-style deepening of the undocketed ZOE
  event-simulation surface (`lib/xaas/zoe/event_simulation.ex` +
  `XaasWeb.A2A.ZoeEventSimulationAgent` behind POST /a2a/zoe-event).

  No mocks: real simulator modules, real router pipelines, real A2A plug
  stack. The simulator exposes no seed parameter — determinism here is
  input-determined; the "seed" axis is realized as identical-vs-differing
  inputs (typed gap recorded in the lane receipt).
  """

  use XaasWeb.ConnCase, async: false

  alias Xaas.Zoe.EventSimulation

  @token "test-only-internal-api-token"

  # ---------------------------------------------------------------- helpers

  defp timeline_event do
    %{
      "event_id" => "event:youth-night",
      "observations" => [
        %{
          "seq" => 1,
          "phase" => "pre_event",
          "registrations" => 0,
          "check_ins" => 0,
          "volunteers" => 0,
          "registration_staff" => 2,
          "administration_staff" => 1,
          "security_staff" => 2,
          "registration_exceptions" => 1,
          "roster_complete?" => false,
          "attendance_submitted?" => true,
          "incidents" => []
        },
        %{
          "seq" => 2,
          "phase" => "arrival",
          "registrations" => 40,
          "check_ins" => 10,
          "volunteers" => 5,
          "registration_staff" => 1,
          "administration_staff" => 2,
          "security_staff" => 1,
          "registration_exceptions" => 0,
          "roster_complete?" => true,
          "attendance_submitted?" => true,
          "incidents" => [
            %{"id" => "inc-2", "kind" => "FLOW_CONTROL_DEGRADED", "subject_ref" => "gate"}
          ]
        },
        %{
          "seq" => 3,
          "phase" => "closeout",
          "registrations" => 40,
          "check_ins" => 38,
          "attendance_submitted?" => false,
          "volunteers" => 5,
          "registration_staff" => 2,
          "administration_staff" => 2,
          "security_staff" => 2,
          "registration_exceptions" => 0,
          "roster_complete?" => true,
          "incidents" => []
        }
      ]
    }
  end

  defp timeline_policy,
    do: %{registration_per_staff: 10, security_per_guard: 20, minimum_admin_staff: 2}

  defp snapshot do
    %{
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
    }
  end

  defp scenario,
    do: %{
      "walk_ins" => 1,
      "security_staff" => 1,
      "security_required" => 2,
      "incidents" => [
        %{
          "incident_ref" => "incident:near-miss",
          "kind" => "SAFETY_NEAR_MISS",
          "severity" => "high",
          "subject_ref" => "person:participant"
        }
      ],
      "resolutions" => ["incident:near-miss"]
    }

  # ------------------------------------------------------------ (a) + (d)
  # determinism x3, byte-identical JSON encoding of the full result

  test "timeline surface: same input three runs -> byte-identical stream" do
    runs =
      for _ <- 1..3 do
        {:ok, result} = EventSimulation.simulate(timeline_event(), timeline_policy())
        Jason.encode!(result)
      end

    assert length(runs) == 3
    assert [a, b, c] = runs
    assert a == b and b == c
    assert byte_size(a) > 0
  end

  test "timeline surface: different input (mutation) -> different stream and digest" do
    {:ok, base} = EventSimulation.simulate(timeline_event(), timeline_policy())

    mutated_observations =
      List.replace_at(timeline_event()["observations"], 0, %{
        "seq" => 1,
        "phase" => "pre_event",
        "registrations" => 0,
        "check_ins" => 0,
        "volunteers" => 0,
        "registration_staff" => 2,
        "administration_staff" => 1,
        "security_staff" => 2,
        "registration_exceptions" => 0,
        "roster_complete?" => true,
        "attendance_submitted?" => true,
        "incidents" => []
      })

    {:ok, mutated} =
      EventSimulation.simulate(
        %{timeline_event() | "observations" => mutated_observations},
        timeline_policy()
      )

    assert Jason.encode!(base) != Jason.encode!(mutated)
    assert base["digest"] != mutated["digest"]

    # the mutation removed exactly the roster + exception obligations
    base_caps = obligations_capability_ids(base)
    mut_caps = obligations_capability_ids(mutated)

    assert "zoe.event.admin.complete_roster" in base_caps
    assert "zoe.event.admin.complete_roster" not in mut_caps
    assert "zoe.event.registration.resolve_exceptions" in base_caps
    assert "zoe.event.registration.resolve_exceptions" not in mut_caps
  end

  test "snapshot surface: same input three runs -> byte-identical stream incl. receipt digest" do
    runs =
      for _ <- 1..3 do
        {:ok, result} = EventSimulation.simulate(snapshot(), scenario())
        Jason.encode!(result)
      end

    assert [a, b, c] = runs
    assert a == b and b == c

    {:ok, result} = Jason.decode(a)
    digest = result["simulation_receipt"]["digest"]

    assert is_binary(digest) and byte_size(digest) == 64
    assert result["simulation_receipt"]["production_receipt"] == false
  end

  test "snapshot surface: different scenario (mutation) -> different receipt digest" do
    {:ok, base} = EventSimulation.simulate(snapshot(), scenario())

    {:ok, mutated} =
      EventSimulation.simulate(snapshot(), %{scenario() | "walk_ins" => 3})

    assert Jason.encode!(base) != Jason.encode!(mutated)

    base_digest = base["simulation_receipt"]["digest"]
    mutated_digest = mutated["simulation_receipt"]["digest"]
    assert base_digest != mutated_digest
    assert mutated["attendance"]["total"] == base["attendance"]["total"] + 2
  end

  # ----------------------------------------------------------------- (c)
  # invariants the code actually enforces

  test "timeline invariants: obligations authority-fenced, sorted, summary consistent" do
    {:ok, result} = EventSimulation.simulate(timeline_event(), timeline_policy())

    assert result["schema"] == "zoe.event.simulation.v1"
    assert result["standing"] == "CANDIDATE"
    assert result["authority"] == "SELECT_CONSTRUCT"
    assert result["sa2a"] == %{
             "dispatch" => "NOT_EXECUTED",
             "authority" => "NONE",
             "command_bus" => "DOWNSTREAM_ONLY"
           }

    obligations = result["obligations"]
    assert obligations != []
    assert obligations == Enum.sort_by(obligations, & &1["id"])

    Enum.each(obligations, fn o ->
      assert o["protocol"] == "SA2A"
      assert o["authority"] == "NONE"
      assert o["authority_boundary"] == "CONSTRUCT_ONLY"
      assert o["standing"] == "CANDIDATE"
      assert o["dispatch"] == "NOT_EXECUTED"
      assert o["phase"] in ["pre_event", "arrival", "live_event", "closeout"]
    end)

    assert result["summary"]["observation_count"] == 3
    assert result["summary"]["obligation_count"] == length(obligations)
    assert result["summary"]["incident_count"] == 1

    assert result["summary"]["capability_ids"] ==
             obligations |> Enum.map(& &1["capability_id"]) |> Enum.uniq() |> Enum.sort()

    # specific real policy outcomes
    ids = obligations_capability_ids(result)
    assert "zoe.event.admin.complete_roster" in ids
    # seq 1 has administration_staff 1 < minimum_admin_staff 2 -> fires
    assert "zoe.event.admin.request_reinforcement" in ids
    assert "zoe.event.registration.request_reinforcement" in ids
    assert "zoe.event.security.request_reinforcement" in ids
    assert "zoe.event.security.report_incident" in ids
    assert "zoe.event.admin.submit_attendance" in ids

    # digest verifies over the digest-less result (real replay of the receipt)
    without_digest = Map.delete(result, "digest")
    assert EventSimulation.digest(without_digest) == result["digest"]
  end

  test "snapshot invariants: trace ordering, authority fence, routing, reconciliation" do
    {:ok, result} = EventSimulation.simulate(snapshot(), scenario())

    assert result["simulation_status"] == "COMPLETE"
    assert result["standing"] == "UNKNOWN"
    assert result["evidence_ceiling"] == "SIMULATION_ONLY"
    assert result["runtime_boundary"] == "SIMULATION"
    assert result["do_authority"] == false
    assert result["event_ref"] == "event:youth-night"
    assert result["attendance"] == %{"checked_in" => 1, "walk_ins" => 1, "total" => 2}
    assert result["security"] == %{"staffed" => 1, "required" => 2, "shortfall" => 1}

    trace = result["trace"]
    assert Enum.map(trace, & &1["sequence"]) == Enum.to_list(1..length(trace))

    Enum.each(trace, fn item ->
      assert item["protocol"] == "sa2a-event-simulation/v1"
      assert item["do_authority"] == false
      assert item["authority_boundary"] in ["OBSERVE", "SELECT", "CONSTRUCT"]
    end)

    report = Enum.find(trace, &(&1["capability_id"] == "zoe.event.security.incident.report"))
    assert report["routed_to"] == ["church_event_lead", "security_management"]

    resolve = Enum.find(trace, &(&1["capability_id"] == "zoe.event.security.incident.resolve"))
    assert resolve["subject_ref"] == "incident:near-miss"
    assert resolve["payload"] == %{"simulation_only" => true}

    reconcile = Enum.find(trace, &(&1["capability_id"] == "zoe.event.reconcile"))
    assert reconcile["payload"]["unresolved_incidents"] == []
    assert reconcile["payload"]["open_obligations"] == 1
    assert reconcile["payload"]["attendance_total"] == 2

    assert [%{"kind" => "security_reinforcement", "state" => "open", "required_count" => 1}] =
             result["obligations"]

    assert result["incidents"] == [
             %{
               "incident_ref" => "incident:near-miss",
               "kind" => "SAFETY_NEAR_MISS",
               "severity" => "high",
               "reporter_ref" => nil,
               "subject_ref" => "person:participant",
               "state" => "resolved",
               "routed_to" => ["church_event_lead", "security_management"]
             }
           ]
  end

  defp obligations_capability_ids(result),
    do: Enum.map(result["obligations"], & &1["capability_id"])

  # ------------------------------------------------------- typed refusals

  test "typed refusals: non-map input, invalid phase/counts/policy" do
    assert {:error, :invalid_simulation} = EventSimulation.simulate("nope")
    assert {:error, :invalid_simulation} = EventSimulation.simulate(nil, %{})

    bad_phase = put_in(timeline_event()["observations"], [%{"seq" => 1, "phase" => "mid_event"}])
    assert {:error, {:invalid, :phase}} = EventSimulation.simulate(bad_phase, timeline_policy())

    bad_count =
      put_in(timeline_event()["observations"], [
        %{
          "seq" => 1,
          "phase" => "pre_event",
          "registrations" => -1,
          "check_ins" => 0,
          "volunteers" => 0,
          "registration_staff" => 1,
          "administration_staff" => 1,
          "security_staff" => 1,
          "registration_exceptions" => 0,
          "roster_complete?" => true,
          "attendance_submitted?" => true,
          "incidents" => []
        }
      ])

    assert {:error, {:invalid, :registrations}} =
             EventSimulation.simulate(bad_count, timeline_policy())

    assert {:error, {:invalid, :registration_per_staff}} =
             EventSimulation.simulate(timeline_event(), %{minimum_admin_staff: 1})

    assert {:error, {:invalid, :observations}} =
             EventSimulation.simulate(
               %{"event_id" => "e", "observations" => []},
               timeline_policy()
             )
  end

  test "typed refusals: snapshot contract validation and PII refusal" do
    bad_provider =
      put_in(snapshot()["provider"], "rocketyard")

    assert {:error, {:invalid_contract, :provider}} =
             EventSimulation.simulate(bad_provider, scenario())

    bad_authority = put_in(snapshot()["authority_boundary"], "DO")

    assert {:error, {:invalid_contract, :authority_boundary}} =
             EventSimulation.simulate(bad_authority, scenario())

    bad_do = put_in(snapshot()["do_authority"], true)

    assert {:error, {:invalid_contract, :do_authority}} =
             EventSimulation.simulate(bad_do, scenario())

    assert {:error, {:invalid_contract, :event}} =
             EventSimulation.simulate(put_in(snapshot()["event"], "not-a-map"), scenario())

    pii_scenario = put_in(scenario()["registrations"], [%{"first_name" => "Tanner"}])

    assert {:error, {:minor_pii_refused, "registrations.0.first_name"}} =
             EventSimulation.simulate(snapshot(), pii_scenario)

    pii_snapshot = put_in(snapshot()["event"]["name"], "ok")

    pii_snapshot2 =
      put_in(pii_snapshot["observations"]["roster"], [
        %{"person_ref" => "p:1", "last_name" => "Chatman"}
      ])

    assert {:error, {:minor_pii_refused, "observations.roster.0.last_name"}} =
             EventSimulation.simulate(pii_snapshot2, scenario())

    assert contract = EventSimulation.contract()
    assert contract["contract_version"] == "zoe-event-ops/v1"
    assert contract["simulation_protocol"] == "sa2a-event-simulation/v1"
    assert contract["do_authority"] == false
    assert contract["evidence_ceiling"] == "SIMULATION_ONLY"
    assert contract["authority_boundaries"] == ["OBSERVE", "SELECT", "CONSTRUCT"]
  end

  # ----------------------------------------------------------- (b) wire

  describe "POST /a2a/zoe-event wire path" do
    setup do
      %{conn: build_conn() |> put_req_header("content-type", "application/json")}
    end

    defp post_rpc(conn, body) do
      post(conn, "/a2a/zoe-event", body)
    end

    defp rpc_request(method, params) do
      Jason.encode!(%{"jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params})
    end

    defp message_params(text) do
      %{
        "message" => %{
          "role" => "ROLE_USER",
          "messageId" => "msg-w744",
          "parts" => [%{"kind" => "text", "text" => text}]
        }
      }
    end

    defp task_text(%{"result" => %{"task" => task}}) do
      artifacts =
        task["artifacts"]
        |> List.wrap()
        |> Enum.flat_map(fn a -> a["parts"] || [] end)

      status_parts =
        case task["status"] do
          %{"message" => %{"parts" => parts}} -> parts
          _ -> []
        end

      (artifacts ++ status_parts)
      |> Enum.map_join(" ", fn
        %{"text" => t} when is_binary(t) -> t
        _ -> ""
      end)
    end

    test "missing bearer token -> 401 from the marking plug (fail closed)" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> post_rpc(rpc_request("message/send", message_params("contract")))

      assert conn.status == 401
      assert conn.resp_body =~ "unauthorized"
    end

    test "garbage bearer token -> 401" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer wrong-token")
        |> post_rpc(rpc_request("message/send", message_params("contract")))

      assert conn.status == 401
    end

    test "valid token + contract -> real response shape over the wire" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer " <> @token)
        |> post_rpc(rpc_request("message/send", message_params("contract")))

      assert conn.status == 200

      assert %{
               "jsonrpc" => "2.0",
               "id" => 1,
               "result" => %{"task" => %{"status" => %{"state" => "TASK_STATE_COMPLETED"}}}
             } = Jason.decode!(conn.resp_body)

      assert {:ok, contract} =
               conn.resp_body
               |> Jason.decode!()
               |> task_text()
               |> Jason.decode()

      assert contract["contract_version"] == "zoe-event-ops/v1"
      assert contract["do_authority"] == false
      assert contract["evidence_ceiling"] == "SIMULATION_ONLY"
    end

    test "valid token + simulate -> real SA2A-shaped simulation result" do
      payload = Jason.encode!(%{"snapshot" => snapshot(), "scenario" => scenario()})

      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer " <> @token)
        |> post_rpc(rpc_request("message/send", message_params("simulate " <> payload)))

      assert conn.status == 200

      task = Jason.decode!(conn.resp_body)["result"]["task"]
      assert task["status"]["state"] == "TASK_STATE_COMPLETED"

      assert {:ok, result} = task_text(%{"result" => %{"task" => task}}) |> Jason.decode()

      assert result["simulation_status"] == "COMPLETE"
      assert result["do_authority"] == false
      assert result["attendance"]["total"] == 2
      assert result["security"]["shortfall"] == 1
      assert byte_size(result["simulation_receipt"]["digest"]) == 64

      report =
        Enum.find(result["trace"], &(&1["capability_id"] == "zoe.event.security.incident.report"))

      assert report["routed_to"] == ["church_event_lead", "security_management"]
    end

    test "malformed simulate JSON -> typed failed task, not a crash" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer " <> @token)
        |> post_rpc(rpc_request("message/send", message_params("simulate {not json")))

      assert conn.status == 200

      task = Jason.decode!(conn.resp_body)["result"]["task"]
      assert task["status"]["state"] == "TASK_STATE_FAILED"

      text = task_text(%{"result" => %{"task" => task}})
      assert text =~ "invalid_simulation_json"
      assert text =~ "Jason.DecodeError"
      assert text =~ "position:"
    end

    test "malformed JSON-RPC body -> JSON-RPC -32700 parse error" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer " <> @token)
        |> post_rpc("{not json")

      assert conn.status == 200

      assert %{"error" => %{"code" => -32700}} = Jason.decode!(conn.resp_body)
    end

    test "unknown text -> input_required usage reply" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer " <> @token)
        |> post_rpc(rpc_request("message/send", message_params("hello?")))

      assert conn.status == 200

      task = Jason.decode!(conn.resp_body)["result"]["task"]
      assert task["status"]["state"] == "TASK_STATE_INPUT_REQUIRED"

      assert task_text(%{"result" => %{"task" => task}}) =~ "Expected: contract | simulate"
    end
  end
end
