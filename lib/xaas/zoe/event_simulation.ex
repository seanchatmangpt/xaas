defmodule Xaas.Zoe.EventSimulation do
  @moduledoc """
  Deterministic, side-effect-free simulation of a complete ZOE event.

  The simulator consumes the `zoe-event-ops/v1` observation contract and
  emits a SA2A-shaped capability trace across administration, registration,
  attendance, security capacity, incident routing, reinforcement, program
  execution, closing, and reconciliation.

  This module is deliberately not a DO boundary. Every emitted capability is
  OBSERVE, SELECT, or CONSTRUCT with `do_authority: false`. The final digest
  is a simulation receipt only; it is never a production actuation receipt or
  runtime standing promotion.
  """

  @contract_version "zoe-event-ops/v1"
  @simulation_protocol "sa2a-event-simulation/v1"
  @management_routes ["church_event_lead", "security_management"]

  @pii_keys MapSet.new([
              "first_name",
              "last_name",
              "email",
              "phone",
              "phone_number",
              "address",
              "street_address",
              "date_of_birth",
              "dob",
              "student_name",
              "youth_name"
            ])

  @type simulation_error ::
          {:invalid_contract, term()}
          | {:invalid_scenario, term()}
          | {:minor_pii_refused, String.t()}

  @spec simulate(map(), map()) :: {:ok, map()} | {:error, simulation_error()}
  def simulate(snapshot, scenario \\ %{}) when is_map(snapshot) and is_map(scenario) do
    with :ok <- refuse_pii(snapshot),
         :ok <- refuse_pii(scenario),
         :ok <- validate_snapshot(snapshot),
         {:ok, normalized} <- normalize_scenario(scenario) do
      state =
        new_state(snapshot, normalized)
        |> emit(
          "zoe.event.snapshot.observe",
          "system",
          "OBSERVE",
          "observe",
          "event",
          %{"source" => "planning_center_contract"}
        )
        |> emit(
          "zoe.event.administration.roster",
          "event_admin",
          "OBSERVE",
          "observe",
          "roster",
          %{"rostered" => roster_count(snapshot)}
        )
        |> emit(
          "zoe.event.registration.open",
          "registration_team",
          "CONSTRUCT",
          "construct",
          "registration",
          %{"registered" => registration_count(snapshot)}
        )
        |> emit(
          "zoe.event.registration.check_in",
          "registration_team",
          "OBSERVE",
          "observe",
          "check_ins",
          %{"checked_in" => check_in_count(snapshot)}
        )
        |> maybe_emit_walk_ins(normalized.walk_ins)
        |> evaluate_security(normalized.security_staff, normalized.security_required)
        |> route_incidents(normalized.incidents)
        |> emit(
          "zoe.event.program.start",
          "event_lead",
          "SELECT",
          "select",
          "program",
          %{"phase" => "program"}
        )
        |> resolve_incidents(normalized.resolutions)
        |> reconcile_attendance(normalized.walk_ins)
        |> emit(
          "zoe.event.program.close",
          "event_lead",
          "SELECT",
          "select",
          "program",
          %{"phase" => "closing"}
        )
        |> reconcile_event()

      {:ok, finalize(state)}
    end
  end

  def simulate(_snapshot, _scenario), do: {:error, {:invalid_contract, :expected_maps}}

  @spec contract() :: map()
  def contract do
    %{
      "contract_version" => @contract_version,
      "simulation_protocol" => @simulation_protocol,
      "authority_boundaries" => ["OBSERVE", "SELECT", "CONSTRUCT"],
      "do_authority" => false,
      "evidence_ceiling" => "SIMULATION_ONLY",
      "incident_routes" => @management_routes
    }
  end

  defp new_state(snapshot, scenario) do
    %{
      snapshot: snapshot,
      scenario: scenario,
      sequence: 0,
      trace: [],
      obligations: [],
      incidents: [],
      attendance: nil,
      security: nil
    }
  end

  defp emit(state, capability_id, actor_role, boundary, consequence_class, subject_ref, payload) do
    sequence = state.sequence + 1

    item = %{
      "sequence" => sequence,
      "protocol" => @simulation_protocol,
      "capability_id" => capability_id,
      "actor_role" => actor_role,
      "authority_boundary" => boundary,
      "do_authority" => false,
      "consequence_class" => consequence_class,
      "subject_ref" => subject_ref,
      "routed_to" => [],
      "payload" => payload
    }

    %{state | sequence: sequence, trace: [item | state.trace]}
  end

  defp emit_routed(
         state,
         capability_id,
         actor_role,
         boundary,
         consequence_class,
         subject_ref,
         routes,
         payload
       ) do
    sequence = state.sequence + 1

    item = %{
      "sequence" => sequence,
      "protocol" => @simulation_protocol,
      "capability_id" => capability_id,
      "actor_role" => actor_role,
      "authority_boundary" => boundary,
      "do_authority" => false,
      "consequence_class" => consequence_class,
      "subject_ref" => subject_ref,
      "routed_to" => routes,
      "payload" => payload
    }

    %{state | sequence: sequence, trace: [item | state.trace]}
  end

  defp maybe_emit_walk_ins(state, 0), do: state

  defp maybe_emit_walk_ins(state, walk_ins) do
    emit(
      state,
      "zoe.event.registration.walk_in.construct",
      "registration_team",
      "CONSTRUCT",
      "construct",
      "walk_ins",
      %{"count" => walk_ins}
    )
  end

  defp evaluate_security(state, staffed, required) do
    shortfall = max(required - staffed, 0)

    state =
      state
      |> Map.put(:security, %{
        "staffed" => staffed,
        "required" => required,
        "shortfall" => shortfall
      })
      |> emit(
        "zoe.event.security.capacity.evaluate",
        "security_lead",
        "SELECT",
        "select",
        "security_capacity",
        %{"staffed" => staffed, "required" => required, "shortfall" => shortfall}
      )

    if shortfall > 0 do
      obligation = %{
        "kind" => "security_reinforcement",
        "owner_role" => "security_management",
        "required_count" => shortfall,
        "state" => "open"
      }

      state
      |> Map.update!(:obligations, &[obligation | &1])
      |> emit_routed(
        "zoe.event.security.reinforcement.request",
        "security_lead",
        "CONSTRUCT",
        "construct",
        "security_capacity",
        @management_routes,
        %{"required_count" => shortfall}
      )
    else
      state
    end
  end

  defp route_incidents(state, incidents) do
    Enum.reduce(incidents, state, fn incident, acc ->
      incident_ref = incident["incident_ref"]

      recorded =
        incident
        |> Map.put("state", "reported")
        |> Map.put("routed_to", @management_routes)

      acc
      |> Map.update!(:incidents, &[recorded | &1])
      |> emit_routed(
        "zoe.event.security.incident.report",
        "event_observer",
        "CONSTRUCT",
        "construct",
        incident_ref,
        @management_routes,
        %{
          "kind" => incident["kind"],
          "severity" => incident["severity"],
          "reporter_ref" => incident["reporter_ref"],
          "subject_ref" => incident["subject_ref"]
        }
      )
    end)
  end

  defp resolve_incidents(state, resolution_refs) do
    resolution_set = MapSet.new(resolution_refs)

    incidents =
      Enum.map(state.incidents, fn incident ->
        if MapSet.member?(resolution_set, incident["incident_ref"]) do
          Map.put(incident, "state", "resolved")
        else
          incident
        end
      end)

    state = %{state | incidents: incidents}

    resolution_refs
    |> Enum.sort()
    |> Enum.reduce(state, fn incident_ref, acc ->
      emit(
        acc,
        "zoe.event.security.incident.resolve",
        "authorized_responder",
        "CONSTRUCT",
        "construct",
        incident_ref,
        %{"simulation_only" => true}
      )
    end)
  end

  defp reconcile_attendance(state, walk_ins) do
    checked_in = check_in_count(state.snapshot)
    total = checked_in + walk_ins

    state
    |> Map.put(:attendance, %{
      "checked_in" => checked_in,
      "walk_ins" => walk_ins,
      "total" => total
    })
    |> emit(
      "zoe.event.attendance.reconcile",
      "event_admin",
      "CONSTRUCT",
      "construct",
      "attendance",
      %{"checked_in" => checked_in, "walk_ins" => walk_ins, "total" => total}
    )
  end

  defp reconcile_event(state) do
    unresolved_incidents =
      state.incidents
      |> Enum.filter(&(&1["state"] != "resolved"))
      |> Enum.map(& &1["incident_ref"])
      |> Enum.sort()

    open_obligations =
      state.obligations
      |> Enum.filter(&(&1["state"] == "open"))

    emit(
      state,
      "zoe.event.reconcile",
      "event_admin",
      "OBSERVE",
      "observe",
      "event",
      %{
        "unresolved_incidents" => unresolved_incidents,
        "open_obligations" => length(open_obligations),
        "attendance_total" => state.attendance["total"]
      }
    )
  end

  defp finalize(state) do
    trace = state.trace |> Enum.reverse()

    result_without_receipt = %{
      "contract_version" => @contract_version,
      "simulation_protocol" => @simulation_protocol,
      "simulation_status" => "COMPLETE",
      "standing" => "UNKNOWN",
      "evidence_ceiling" => "SIMULATION_ONLY",
      "runtime_boundary" => "SIMULATION",
      "do_authority" => false,
      "event_ref" => event_ref(state.snapshot),
      "attendance" => state.attendance,
      "security" => state.security,
      "incidents" => state.incidents |> Enum.reverse(),
      "obligations" => state.obligations |> Enum.reverse(),
      "trace" => trace
    }

    digest =
      result_without_receipt
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    Map.put(result_without_receipt, "simulation_receipt", %{
      "kind" => "SIMULATION_RECEIPT",
      "algorithm" => "sha256",
      "digest" => digest,
      "production_receipt" => false
    })
  end

  defp validate_snapshot(snapshot) do
    cond do
      field(snapshot, "contract_version") != @contract_version ->
        {:error, {:invalid_contract, :contract_version}}

      field(snapshot, "provider") != "planning_center" ->
        {:error, {:invalid_contract, :provider}}

      field(snapshot, "authority_boundary") != "OBSERVE" ->
        {:error, {:invalid_contract, :authority_boundary}}

      field(snapshot, "do_authority") != false ->
        {:error, {:invalid_contract, :do_authority}}

      not is_map(field(snapshot, "event", nil)) ->
        {:error, {:invalid_contract, :event}}

      not is_map(field(snapshot, "observations", nil)) ->
        {:error, {:invalid_contract, :observations}}

      true ->
        :ok
    end
  end

  defp normalize_scenario(scenario) do
    with {:ok, walk_ins} <- non_negative_integer(scenario, "walk_ins", 0),
         {:ok, security_staff} <- non_negative_integer(scenario, "security_staff", 0),
         {:ok, security_required} <- non_negative_integer(scenario, "security_required", 0),
         {:ok, incidents} <- normalize_incidents(field(scenario, "incidents", [])),
         {:ok, resolutions} <- normalize_resolution_refs(field(scenario, "resolutions", [])) do
      {:ok,
       %{
         walk_ins: walk_ins,
         security_staff: security_staff,
         security_required: security_required,
         incidents: incidents,
         resolutions: resolutions
       }}
    end
  end

  defp normalize_incidents(incidents) when is_list(incidents) do
    incidents
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {incident, index}, {:ok, acc} ->
      with true <- is_map(incident),
           incident_ref when is_binary(incident_ref) and incident_ref != "" <-
             field(incident, "incident_ref"),
           kind when is_binary(kind) and kind != "" <- field(incident, "kind") do
        normalized = %{
          "incident_ref" => incident_ref,
          "kind" => kind,
          "severity" => field(incident, "severity", "unknown"),
          "reporter_ref" => field(incident, "reporter_ref"),
          "subject_ref" => field(incident, "subject_ref")
        }

        {:cont, {:ok, [normalized | acc]}}
      else
        _ -> {:halt, {:error, {:invalid_scenario, {:incident, index}}}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end

  defp normalize_incidents(_), do: {:error, {:invalid_scenario, :incidents}}

  defp normalize_resolution_refs(refs) when is_list(refs) do
    if Enum.all?(refs, &(is_binary(&1) and &1 != "")) do
      {:ok, Enum.uniq(refs)}
    else
      {:error, {:invalid_scenario, :resolutions}}
    end
  end

  defp normalize_resolution_refs(_), do: {:error, {:invalid_scenario, :resolutions}}

  defp non_negative_integer(map, key, default) do
    case field(map, key, default) do
      value when is_integer(value) and value >= 0 -> {:ok, value}
      _ -> {:error, {:invalid_scenario, key}}
    end
  end

  defp roster_count(snapshot), do: observation_count(snapshot, "roster")
  defp registration_count(snapshot), do: observation_count(snapshot, "registrations")

  defp check_in_count(snapshot) do
    snapshot
    |> observations()
    |> field("check_ins", [])
    |> Enum.map(&field(&1, "person_ref"))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> length()
  end

  defp observation_count(snapshot, key) do
    snapshot
    |> observations()
    |> field(key, [])
    |> length()
  end

  defp observations(snapshot), do: field(snapshot, "observations", %{})

  defp event_ref(snapshot) do
    snapshot
    |> field("event", %{})
    |> field("ref")
  end

  defp field(map, key, default \\ nil)\n\n  defp field(map, key, default) when is_map(map) and is_binary(key) do
    atom_key =
      try do
        String.to_existing_atom(key)
      rescue
        ArgumentError -> nil
      end

    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      atom_key && Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      true -> default
    end
  end

  defp field(_not_map, _key, default), do: default

  defp refuse_pii(value), do: refuse_pii(value, [])

  defp refuse_pii(map, path) when is_map(map) do
    Enum.reduce_while(map, :ok, fn {key, value}, :ok ->
      key_string = to_string(key)
      next_path = path ++ [key_string]

      cond do
        MapSet.member?(@pii_keys, key_string) ->
          {:halt, {:error, {:minor_pii_refused, Enum.join(next_path, ".")}}}

        true ->
          case refuse_pii(value, next_path) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end
      end
    end)
  end

  defp refuse_pii(list, path) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {value, index}, :ok ->
      case refuse_pii(value, path ++ [Integer.to_string(index)]) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp refuse_pii(_value, _path), do: :ok
end
