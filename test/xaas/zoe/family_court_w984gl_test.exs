defmodule Xaas.Zoe.FamilyCourtW984glTest do
  @moduledoc """
  W984gl unclaimed-family probe on the zoe/meeting domain
  (`lib/xaas/zoe/private_meeting_inference.ex` + `lib/xaas/zoe/event_simulation.ex`).

  W984em already courts the zoe wire stack (`ZoeEventPlug`,
  `ZoeEventSimulationAgent` over POST /a2a/zoe-event); this court exercises the
  lib modules directly. Zero mocks: real temp directories, real manifests, real
  simulator state. Each test names the mutation it kills.
  """

  use ExUnit.Case, async: true

  alias Xaas.Zoe.EventSimulation
  alias Xaas.Zoe.PrivateMeetingInference

  @digest String.duplicate("a", 64)

  # ---------------------------------------------- private_meeting_inference

  defp tmp_model_dir do
    dir =
      Path.join(System.tmp_dir!(), "zoe-w984gl-model-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  defp write_artifact(dir, relative, content) do
    path = Path.join(dir, relative)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
    digest = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    "#{digest}  #{relative}"
  end

  test "repository/1 refuses a non-binary model directory (kills deletion of the unguarded clause)"
       do
    assert {:error, %{code: :invalid_model_directory}} =
             PrivateMeetingInference.repository(nil)
  end

  test "repository/1 refuses a regular file and a nonexistent path with the same typed refusal (kills a File.exists?-style rewrite)"
       do
    file = tmp_model_dir() |> Path.join("weights.bin")
    File.write!(file, "weights")

    assert {:error, %{code: :local_model_directory_missing}} =
             PrivateMeetingInference.repository(file)

    assert {:error, %{code: :local_model_directory_missing}} =
             PrivateMeetingInference.repository(Path.join(tmp_model_dir(), "never-created"))
  end

  test "verify_model_manifest/1 refuses a non-binary directory argument (kills the guardless head clause)"
       do
    assert {:error, %{code: :invalid_model_directory}} =
             PrivateMeetingInference.verify_model_manifest(:not_a_path)
  end

  test "manifest validation refuses empty, unsafe, malformed, and duplicate manifest lines"
       do
    dir = tmp_model_dir()

    File.write!(Path.join(dir, ".model-manifest.sha256"), "\n")

    assert {:error, %{code: :model_manifest_empty}} =
             PrivateMeetingInference.verify_model_manifest(dir)

    File.write!(Path.join(dir, ".model-manifest.sha256"), "#{@digest}  ../escape.bin\n")

    assert {:error, %{code: :unsafe_model_manifest_path}} =
             PrivateMeetingInference.verify_model_manifest(dir)

    File.write!(Path.join(dir, ".model-manifest.sha256"), "not-a-manifest-line\n")

    assert {:error, %{code: :invalid_model_manifest_line}} =
             PrivateMeetingInference.verify_model_manifest(dir)

    good = write_artifact(dir, "config.json", "cfg")
    File.write!(Path.join(dir, ".model-manifest.sha256"), "#{good}\n#{good}\n")

    assert {:error, %{code: :duplicate_model_manifest_path}} =
             PrivateMeetingInference.verify_model_manifest(dir)
  end

  test "manifest completeness fails on the missing-from-disk direction (kills a one-sided MapSet.difference rewrite)"
       do
    dir = tmp_model_dir()
    line = write_artifact(dir, "config.json", "cfg")
    File.write!(Path.join(dir, ".model-manifest.sha256"), line <> "\n")
    File.rm!(Path.join(dir, "config.json"))

    assert {:error, %{code: :model_manifest_incomplete}} =
             PrivateMeetingInference.verify_model_manifest(dir)

    assert {:error, %{detail: detail_text}} =
             PrivateMeetingInference.verify_model_manifest(dir)

    assert detail_text =~ "missing_files"
  end

  test "manifest verification refuses a symlink planted inside the model directory (kills a wildcard-without-dotfiles rewrite)"
       do
    dir = tmp_model_dir()
    line = write_artifact(dir, "config.json", "cfg")
    File.write!(Path.join(dir, ".model-manifest.sha256"), line <> "\n")

    File.ln_s!(dir, Path.join(dir, "escape-link"))

    assert {:error, %{code: :model_symlink_refused}} =
             PrivateMeetingInference.verify_model_manifest(dir)
  end

  test "decoder requires an observations list and rejects wrong-shaped arguments (kills the fallthrough refusal clause)"
       do
    no_observations = Jason.encode!(%{"novel_observations" => []})

    assert {:error, %{code: :observations_required}} =
             PrivateMeetingInference.decode_output(
               no_observations,
               ["roles_and_ownership"],
               @digest,
               "t"
             )

    assert {:error, %{code: :invalid_model_output}} =
             PrivateMeetingInference.decode_output(:not_a_string, ["x"], @digest, "t")
  end

  test "decoder defaults process waste to zero when the model omits process_metrics (kills a raise-on-missing rewrite)"
       do
    generated =
      Jason.encode!(%{
        "observations" => [%{"requirement_id" => "roles_and_ownership", "status" => "SATISFIED"}]
      })

    assert {:ok, candidate} =
             PrivateMeetingInference.decode_output(
               generated,
               ["roles_and_ownership"],
               @digest,
               "t"
             )

    assert candidate["process_metrics"]["unnecessary_minutes"] == 0
  end

  test "extract/3 refuses invalid argument shapes without touching a serving (kills the guardless fallthrough)"
       do
    assert {:error, %{code: :invalid_private_inference_request}} =
             PrivateMeetingInference.extract("not-a-serving", "t", [%{"id" => "req:1"}])
  end

  # ---------------------------------------------------- event_simulation

  defp timeline_event do
    %{
      "event_id" => "event:w984gl",
      "observations" => [
        %{
          "seq" => 1,
          "phase" => "closeout",
          "registrations" => 10,
          "check_ins" => 10,
          "volunteers" => 2,
          "registration_staff" => 2,
          "administration_staff" => 2,
          "security_staff" => 2,
          "registration_exceptions" => 0,
          "roster_complete?" => true,
          "attendance_submitted?" => true,
          "incidents" => []
        }
      ]
    }
  end

  defp policy, do: %{registration_per_staff: 10, security_per_guard: 20, minimum_admin_staff: 2}

  defp snapshot do
    %{
      "contract_version" => "zoe-event-ops/v1",
      "provider" => "planning_center",
      "authority_boundary" => "OBSERVE",
      "do_authority" => false,
      "event" => %{"ref" => "event:w984gl"},
      "observations" => %{
        "roster" => [%{"person_ref" => "p:1"}],
        "registrations" => [%{"registration_ref" => "reg:1"}],
        "check_ins" => [%{"check_in_ref" => "c:1", "person_ref" => "person:a"}]
      }
    }
  end

  defp scenario(opts \\ []) do
    %{
      "walk_ins" => Keyword.get(opts, :walk_ins, 0),
      "security_staff" => Keyword.get(opts, :security_staff, 2),
      "security_required" => Keyword.get(opts, :security_required, 2),
      "incidents" => Keyword.get(opts, :incidents, []),
      "resolutions" => Keyword.get(opts, :resolutions, [])
    }
  end

  test "simulate/2 refuses a non-map params argument (kills deletion of the is_map(params) guard)"
       do
    assert {:error, :invalid_simulation} = EventSimulation.simulate(timeline_event(), "nope")
  end

  test "timeline surface refuses a non-map observation, non-boolean flags, and a non-list incidents value"
       do
    assert {:error, {:invalid, :observation}} =
             EventSimulation.simulate(
               put_in(timeline_event()["observations"], [42]),
               policy()
             )

    obs = timeline_event()["observations"] |> hd()

    bad_flag =
      put_in(timeline_event()["observations"], [Map.put(obs, "roster_complete?", "yes")])

    assert {:error, {:invalid, :roster_complete?}} =
             EventSimulation.simulate(bad_flag, policy())

    bad_attendance =
      put_in(timeline_event()["observations"], [Map.put(obs, "attendance_submitted?", 1)])

    assert {:error, {:invalid, :attendance_submitted?}} =
             EventSimulation.simulate(bad_attendance, policy())

    bad_incidents =
      put_in(timeline_event()["observations"], [Map.put(obs, "incidents", "many")])

    assert {:error, {:invalid, :incidents}} = EventSimulation.simulate(bad_incidents, policy())
  end

  test "a snapshot with a drifted contract_version routes to the timeline surface and refuses on event_id (kills a prefix-match routing rewrite)"
       do
    drifted = put_in(snapshot()["contract_version"], "zoe-event-ops/v2")

    assert {:error, {:invalid, :event_id}} = EventSimulation.simulate(drifted, scenario())
  end

  test "scenario refusals: negative walk_ins, non-list incidents, malformed incident, non-list resolutions"
       do
    assert {:error, {:invalid_scenario, "walk_ins"}} =
             EventSimulation.simulate(snapshot(), scenario(walk_ins: -1))

    assert {:error, {:invalid_scenario, :incidents}} =
             EventSimulation.simulate(snapshot(), %{"incidents" => "many"})

    assert {:error, {:invalid_scenario, {:incident, 0}}} =
             EventSimulation.simulate(
               snapshot(),
               scenario(incidents: [%{"incident_ref" => "i:1"}])
             )

    assert {:error, {:invalid_scenario, :resolutions}} =
             EventSimulation.simulate(snapshot(), %{"resolutions" => ["ok", 3]})
  end

  test "an unresolved incident stays reported and surfaces in the reconcile payload (kills a resolve-everything rewrite)"
       do
    incident = %{
      "incident_ref" => "incident:unresolved",
      "kind" => "SAFETY_NEAR_MISS",
      "severity" => "low"
    }

    assert {:ok, result} =
             EventSimulation.simulate(
               snapshot(),
               scenario(incidents: [incident], resolutions: [])
             )

    assert [%{"state" => "reported"}] = result["incidents"]

    reconcile =
      result["trace"]
      |> Enum.find(&(&1["capability_id"] == "zoe.event.reconcile"))

    assert reconcile["payload"]["unresolved_incidents"] == ["incident:unresolved"]
    assert reconcile["payload"]["open_obligations"] == 0
  end

  test "zero walk-ins and a satisfied security capacity emit no walk-in trace item and no reinforcement obligation (kills the drop-the-zero-clause rewrite)"
       do
    assert {:ok, result} =
             EventSimulation.simulate(snapshot(), scenario(walk_ins: 0, security_staff: 2, security_required: 2))

    refute Enum.any?(
             result["trace"],
             &(&1["capability_id"] == "zoe.event.registration.walk_in.construct")
           )

    assert result["obligations"] == []

    security =
      result["trace"]
      |> Enum.find(&(&1["capability_id"] == "zoe.event.security.capacity.evaluate"))

    assert security["payload"]["shortfall"] == 0
  end

  test "duplicate check-in person_refs are deduplicated in attendance reconciliation (kills a length-of-list rewrite)"
       do
    snap =
      put_in(snapshot()["observations"]["check_ins"], [
        %{"check_in_ref" => "c:1", "person_ref" => "person:a"},
        %{"check_in_ref" => "c:2", "person_ref" => "person:a"}
      ])

    assert {:ok, result} = EventSimulation.simulate(snap, scenario())

    assert result["attendance"] == %{
             "checked_in" => 1,
             "walk_ins" => 0,
             "total" => 1
           }
  end
end
