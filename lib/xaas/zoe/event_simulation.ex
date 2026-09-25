defmodule Xaas.Zoe.EventSimulation do
  @moduledoc """
  Deterministic ZOE event simulator with two admission surfaces.

  * **Whole-event timeline** — `simulate/2` consumes an observation timeline
    plus a capacity policy and emits SA2A-shaped candidate obligations
    (DfCM SELECT/CONSTRUCT surface).
  * **`zoe-event-ops/v1` snapshot** — `simulate/2` consumes a contract
    snapshot plus a scenario and emits a SA2A-shaped capability trace across
    administration, registration, attendance, security capacity, incident
    routing, reinforcement, program execution, closing, and reconciliation.
    This surface backs `XaasWeb.A2A.ZoeEventSimulationAgent` together with
    `contract/0`.

  The two surfaces are distinguished by the snapshot's `contract_version`;
  an input without it is treated as a whole-event timeline. Both surfaces
  preserve candidate responses and emit SA2A-shaped obligations, but neither
  performs DO, claims authority, writes a provider, or manufactures execution
  receipts. The final digest is a simulation receipt only; it is never a
  production actuation receipt or runtime standing promotion.
  """

  @phases ~w(pre_event arrival live_event closeout)a

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

  @type simulation :: map()

  @type simulation_error ::
          {:invalid_contract, term()}
          | {:invalid_scenario, term()}
          | {:minor_pii_refused, String.t()}

  @spec simulate(map(), map()) :: {:ok, simulation()} | {:error, term()}
  def simulate(input, params \\ %{})

  def simulate(input, params) when is_map(input) and is_map(params) do
    if contract_snapshot?(input) do
      simulate_snapshot(input, params)
    else
      simulate_event(input, params)
    end
  end

  def simulate(_, _), do: {:error, :invalid_simulation}

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

  @spec digest(map()) :: String.t()
  def digest(value) when is_map(value) do
    value
    |> Map.delete("digest")
    |> canonical()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp contract_snapshot?(input), do: field(input, "contract_version") == @contract_version

  # Whole-event timeline surface (observation timeline + capacity policy).

  defp simulate_event(event, policy) do
    with {:ok, event_id} <- required_binary(event, :event_id),
         {:ok, observations} <- observations(event),
         {:ok, normalized_policy} <- policy(policy) do
      timeline = Enum.map(observations, &normalize_observation/1)

      obligations =
        timeline
        |> Enum.flat_map(&obligations_for(event_id, &1, normalized_policy))
        |> Enum.sort_by(& &1["id"])

      result = %{
        "schema" => "zoe.event.simulation.v1",
        "event_id" => event_id,
        "authority" => "SELECT_CONSTRUCT",
        "standing" => "CANDIDATE",
        "sa2a" => %{
          "dispatch" => "NOT_EXECUTED",
          "authority" => "NONE",
          "command_bus" => "DOWNSTREAM_ONLY"
        },
        "policy" => stringify_policy(normalized_policy),
        "timeline" => timeline,
        "obligations" => obligations,
        "summary" => %{
          "observation_count" => length(timeline),
          "obligation_count" => length(obligations),
          "incident_count" =>
            Enum.reduce(timeline, 0, fn observation, acc ->
              acc + length(observation["incidents"])
            end),
          "capability_ids" =>
            obligations
            |> Enum.map(& &1["capability_id"])
            |> Enum.uniq()
            |> Enum.sort()
        }
      }

      {:ok, Map.put(result, "digest", digest(result))}
    end
  end

  defp observations(event) do
    case value(event, :observations) do
      observations when is_list(observations) and observations != [] ->
        observations
        |> Enum.reduce_while({:ok, []}, fn observation, {:ok, acc} ->
          case validate_observation(observation) do
            {:ok, valid} -> {:cont, {:ok, [valid | acc]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)
        |> case do
          {:ok, valid} -> {:ok, valid |> Enum.reverse() |> Enum.sort_by(&value(&1, :seq))}
          error -> error
        end

      _ ->
        {:error, {:invalid, :observations}}
    end
  end

  defp validate_observation(observation) when is_map(observation) do
    phase = normalize_phase(value(observation, :phase))

    required_counts = [
      :seq,
      :registrations,
      :check_ins,
      :volunteers,
      :registration_staff,
      :administration_staff,
      :security_staff,
      :registration_exceptions
    ]

    with {:ok, phase} <- valid_phase(phase),
         :ok <- validate_counts(observation, required_counts),
         :ok <- validate_boolean(observation, :roster_complete?),
         :ok <- validate_boolean(observation, :attendance_submitted?),
         {:ok, _incidents} <- validate_incidents(observation) do
      {:ok, Map.put(observation, :phase, phase)}
    end
  end

  defp validate_observation(_), do: {:error, {:invalid, :observation}}

  defp valid_phase(phase) when phase in @phases, do: {:ok, phase}
  defp valid_phase(_), do: {:error, {:invalid, :phase}}

  defp validate_boolean(observation, key) do
    if is_boolean(value(observation, key)), do: :ok, else: {:error, {:invalid, key}}
  end

  defp validate_incidents(observation) do
    case value(observation, :incidents, []) do
      incidents when is_list(incidents) -> {:ok, incidents}
      _ -> {:error, {:invalid, :incidents}}
    end
  end

  defp validate_counts(observation, keys) do
    Enum.reduce_while(keys, :ok, fn key, :ok ->
      case value(observation, key) do
        count when is_integer(count) and count >= 0 -> {:cont, :ok}
        _ -> {:halt, {:error, {:invalid, key}}}
      end
    end)
  end

  defp normalize_observation(observation) do
    incidents =
      observation
      |> value(:incidents, [])
      |> Enum.map(&normalize_incident/1)
      |> Enum.sort_by(& &1["id"])

    %{
      "seq" => value(observation, :seq),
      "phase" => observation |> value(:phase) |> Atom.to_string(),
      "registrations" => value(observation, :registrations),
      "check_ins" => value(observation, :check_ins),
      "volunteers" => value(observation, :volunteers),
      "registration_staff" => value(observation, :registration_staff),
      "administration_staff" => value(observation, :administration_staff),
      "security_staff" => value(observation, :security_staff),
      "registration_exceptions" => value(observation, :registration_exceptions),
      "roster_complete" => value(observation, :roster_complete?),
      "attendance_submitted" => value(observation, :attendance_submitted?),
      "incidents" => incidents
    }
  end

  defp normalize_incident(incident) when is_map(incident) do
    %{
      "id" => incident |> value(:id, "unknown") |> to_string(),
      "kind" => incident |> value(:kind, "unknown") |> to_string(),
      "subject_ref" => incident |> value(:subject_ref, "event") |> to_string()
    }
  end

  defp normalize_incident(other) do
    %{"id" => "invalid", "kind" => "unknown", "subject_ref" => inspect(other)}
  end

  defp obligations_for(event_id, observation, policy) do
    []
    |> maybe_add_roster(event_id, observation)
    |> maybe_add_admin_capacity(event_id, observation, policy)
    |> maybe_add_registration_capacity(event_id, observation, policy)
    |> maybe_add_registration_exceptions(event_id, observation)
    |> maybe_add_security_capacity(event_id, observation, policy)
    |> add_incident_reports(event_id, observation)
    |> maybe_add_attendance_submission(event_id, observation)
  end

  defp maybe_add_roster(
         acc,
         event_id,
         %{"phase" => "pre_event", "roster_complete" => false} = observation
       ) do
    [
      obligation(event_id, observation, "zoe.event.admin.complete_roster", %{
        "roster_complete" => false
      })
      | acc
    ]
  end

  defp maybe_add_roster(acc, _, _), do: acc

  defp maybe_add_admin_capacity(acc, event_id, observation, policy) do
    if observation["administration_staff"] < policy.minimum_admin_staff do
      [
        obligation(event_id, observation, "zoe.event.admin.request_reinforcement", %{
          "observed_staff" => observation["administration_staff"],
          "required_staff" => policy.minimum_admin_staff
        })
        | acc
      ]
    else
      acc
    end
  end

  defp maybe_add_registration_capacity(acc, event_id, observation, policy) do
    backlog = max(observation["registrations"] - observation["check_ins"], 0)
    capacity = observation["registration_staff"] * policy.registration_per_staff

    if observation["phase"] in ["arrival", "live_event"] and backlog > capacity do
      [
        obligation(event_id, observation, "zoe.event.registration.request_reinforcement", %{
          "backlog" => backlog,
          "observed_staff" => observation["registration_staff"],
          "capacity" => capacity
        })
        | acc
      ]
    else
      acc
    end
  end

  defp maybe_add_registration_exceptions(acc, event_id, observation) do
    if observation["registration_exceptions"] > 0 do
      [
        obligation(event_id, observation, "zoe.event.registration.resolve_exceptions", %{
          "exception_count" => observation["registration_exceptions"]
        })
        | acc
      ]
    else
      acc
    end
  end

  defp maybe_add_security_capacity(acc, event_id, observation, policy) do
    crowd = observation["check_ins"] + observation["volunteers"]
    capacity = observation["security_staff"] * policy.security_per_guard

    if crowd > capacity do
      [
        obligation(event_id, observation, "zoe.event.security.request_reinforcement", %{
          "crowd" => crowd,
          "observed_staff" => observation["security_staff"],
          "capacity" => capacity
        })
        | acc
      ]
    else
      acc
    end
  end

  defp add_incident_reports(acc, event_id, observation) do
    Enum.reduce(observation["incidents"], acc, fn incident, current ->
      [
        obligation(event_id, observation, "zoe.event.security.report_incident", %{
          "incident_id" => incident["id"],
          "kind" => incident["kind"],
          "subject_ref" => incident["subject_ref"]
        })
        | current
      ]
    end)
  end

  defp maybe_add_attendance_submission(
         acc,
         event_id,
         %{"phase" => "closeout", "attendance_submitted" => false} = observation
       ) do
    [
      obligation(event_id, observation, "zoe.event.admin.submit_attendance", %{
        "final_check_ins" => observation["check_ins"],
        "volunteers" => observation["volunteers"]
      })
      | acc
    ]
  end

  defp maybe_add_attendance_submission(acc, _, _), do: acc

  defp obligation(event_id, observation, capability_id, inputs) do
    subject =
      inputs["incident_id"] ||
        inputs["kind"] ||
        inputs["backlog"] ||
        inputs["exception_count"] ||
        observation["seq"]

    id =
      [event_id, observation["seq"], capability_id, subject]
      |> Enum.map_join("|", &to_string/1)
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    %{
      "id" => id,
      "protocol" => "SA2A",
      "capability_id" => capability_id,
      "phase" => observation["phase"],
      "observation_seq" => observation["seq"],
      "authority" => "NONE",
      "authority_boundary" => "CONSTRUCT_ONLY",
      "standing" => "CANDIDATE",
      "dispatch" => "NOT_EXECUTED",
      "inputs" => inputs
    }
  end

  defp policy(policy) do
    with {:ok, registration_per_staff} <- positive(policy, :registration_per_staff),
         {:ok, security_per_guard} <- positive(policy, :security_per_guard),
         {:ok, minimum_admin_staff} <- positive(policy, :minimum_admin_staff) do
      {:ok,
       %{
         registration_per_staff: registration_per_staff,
         security_per_guard: security_per_guard,
         minimum_admin_staff: minimum_admin_staff
       }}
    end
  end

  defp stringify_policy(policy) do
    %{
      "registration_per_staff" => policy.registration_per_staff,
      "security_per_guard" => policy.security_per_guard,
      "minimum_admin_staff" => policy.minimum_admin_staff
    }
  end

  defp positive(map, key) do
    case value(map, key) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      _ -> {:error, {:invalid, key}}
    end
  end

  defp required_binary(map, key) do
    case value(map, key) do
      value when is_binary(value) and byte_size(value) > 0 -> {:ok, value}
      _ -> {:error, {:invalid, key}}
    end
  end

  defp normalize_phase(phase) when phase in @phases, do: phase

  defp normalize_phase(phase) when is_binary(phase) do
    Enum.find(@phases, fn candidate -> Atom.to_string(candidate) == phase end)
  end

  defp normalize_phase(_), do: nil

  defp canonical(value) when is_map(value) do
    value
    |> Enum.map(fn {key, nested} -> {to_string(key), canonical(nested)} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp canonical(value) when is_list(value), do: Enum.map(value, &canonical/1)
  defp canonical(value), do: value

  defp value(map, key, default \\ nil) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  # Contract snapshot surface (zoe-event-ops/v1 snapshot + scenario).

  defp simulate_snapshot(snapshot, scenario) do
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

  defp emit(
         state,
         capability_id,
         actor_role,
         boundary,
         consequence_class,
         subject_ref,
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
    |> snapshot_observations()
    |> field("check_ins", [])
    |> Enum.map(&field(&1, "person_ref"))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> length()
  end

  defp observation_count(snapshot, key) do
    snapshot
    |> snapshot_observations()
    |> field(key, [])
    |> length()
  end

  defp snapshot_observations(snapshot), do: field(snapshot, "observations", %{})

  defp event_ref(snapshot) do
    snapshot
    |> field("event", %{})
    |> field("ref")
  end

  defp field(map, key, default \\ nil)

  defp field(map, key, default) when is_map(map) and is_binary(key) do
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
