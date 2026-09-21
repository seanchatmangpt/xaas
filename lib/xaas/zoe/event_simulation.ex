defmodule Xaas.Zoe.EventSimulation do
  @moduledoc """
  Deterministic whole-event simulator for ZOE operational observations.

  The simulator is a DfCM SELECT/CONSTRUCT surface. It preserves candidate
  responses and emits SA2A-shaped obligations, but it never performs DO,
  claims authority, writes a provider, or manufactures execution receipts.
  """

  @phases ~w(pre_event arrival live_event closeout)a

  @type simulation :: map()

  @spec simulate(map(), map()) :: {:ok, simulation()} | {:error, term()}
  def simulate(event, policy) when is_map(event) and is_map(policy) do
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

  def simulate(_, _), do: {:error, :invalid_simulation}

  @spec digest(map()) :: String.t()
  def digest(value) when is_map(value) do
    value
    |> Map.delete("digest")
    |> canonical()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
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

  defp maybe_add_roster(acc, event_id, %{"phase" => "pre_event", "roster_complete" => false} = observation) do
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
end
