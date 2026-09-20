defmodule Xaas.Ultracode.RunValidation do
  @moduledoc """
  The results-validation law for Ultracode runs, closed over OCEL 2.0:
  a run's RESULTS are validated if and only if its OCEL 2.0 log

    (a) passes structural conformance to the OCEL 2.0 JSON shape, and
    (b) accounts for every epoch of the run with terminal, receipt-backed
        evidence -- each epoch appears via exactly one `epoch_claimed`
        event and reaches exactly one `receipt_closed` event whose
        `verification` attribute is `passed`, `failed`, or `refused`, and
        the number of workers in flight (claimed-but-not-yet-closed
        epochs, derivable purely from event times) never exceeds the
        run's capacity law (5 by default -- the operator-ordered standing
        wave size pinned in `Xaas.Ultracode.Run`'s `:autonomic_wave`
        action).

  The verdict is `:validated` or `:not_validated` and every
  `:not_validated` verdict carries a violation list naming the offending
  epoch ids, so a red verdict is traceable to named events, never an
  unexplained boolean.

  ## Log shape (the W3-A5 emitter contract)

  The OCEL 2.0 JSON shape accepted here is exactly what this repo's own
  OCEL 2.0 producer emits (`Xaas.Ocel.Projection.to_ocel_map/1`): top-level
  `"objectTypes"`, `"eventTypes"`, `"objects"`, `"events"`, with events
  `{"id", "type", "time", "attributes", "relationships"}` and objects
  `{"id", "type"}`. This is the OCEL 2.0 information model without the
  serialization's `"ocel:"` key-prefix dialect; the prefixes are notation,
  the four top-level collections and the five event fields are the law,
  and binding to the in-repo projection (not to a foreign tool's export)
  is deliberate -- this validator and the emitter must agree byte-for-byte
  on shape, and the projection is that agreement's only in-repo source.

  Ultracode event vocabulary expected by the semantic checks:

    * `"epoch_claimed"` -- a worker claimed the epoch. Binds to its epoch
      via `attributes["epoch_id"]` or a relationship to an object whose
      `"type"` is `"epoch"`; binds to the run via `attributes["run_id"]`
      or a relationship to an object whose `"type"` is `"run"`.
    * `"receipt_closed"` -- the epoch's sealed receipt (`Xaas.Ultracode.
      Receipt`) was closed. Same epoch binding, plus
      `attributes["verification"]` in `"passed" | "failed" | "refused"`.
      A `receipt_closed` without one of those three verification values
      is not terminal evidence.

  ## Wiring: why this accepts a log, not persistence

  Run/Epoch/Receipt state IS persisted (`Xaas.Ultracode.Run`/`Epoch`/
  `Receipt`), but the deterministic run-to-OCEL-log projection is the
  OCEL emitter's owned mutation (W3-A5), and `Xaas.Ocel.Projection`
  already owns the persisted-OCEL projection. Deriving a log from
  Ultracode persistence here too would be a second, hand-maintained
  projection of the same facts -- exactly the duplication the repo's
  source-hierarchy law forbids. So this module validates a LOG (map or
  path), and run-id input resolves the log through the configurable
  emitter module (`config :xaas, :ultracode_ocel_log_emitter`, default
  `Xaas.Ultracode.OcelLog`, exporting `emit/1` returning `{:ok, log}`).
  When the emitter lands, `Mix.Tasks.Xaas.RunValidate` accepts a bare
  run id end-to-end; until then it refuses with a typed message instead
  of fabricating a log.

  ## Conformance-court dedup (W3-A6 interface, disclosed)

  W3-A6 owns the general OCEL conformance court. Until that lands on
  this branch, the structural checks in `conformance/1` are the
  in-family implementation of the same spec checks. When the court
  lands, set `config :xaas, :ultracode_ocel_conformance_court, Mod`
  (module exporting `check/1`, taking the decoded log map, returning a
  list of violation maps) and `validate/2` delegates the structural
  half to it instead of these local checks -- one court, not two.

  This module is pure: no database, no process, no clock. The same log
  bytes always produce the same verdict.
  """

  @default_capacity 5

  @terminal_verifications ~w(passed failed refused)
  @claim_event "epoch_claimed"
  @terminal_event "receipt_closed"
  @epoch_lifecycle_events [@claim_event, @terminal_event]

  @type violation :: %{
          required(:code) => atom(),
          required(:message) => String.t(),
          optional(:epoch_id) => String.t() | nil,
          optional(:event_id) => String.t() | nil
        }

  @type verdict :: :validated | :not_validated

  @doc """
  Validates one run's OCEL 2.0 log.

  `log_or_path` is either an already-decoded OCEL log map or a path to a
  JSON file containing one. Options:

    * `:run_id` -- the run whose log this is claimed to be. When given,
      the log must carry this run id as its ONLY run binding
      (`:wrong_run` otherwise). Omit to validate a log standalone.
    * `:capacity` -- max workers in flight (default #{@default_capacity},
      the standing wave capacity).

  Returns a map with `:verdict`, `:violations` (empty iff `:validated`),
  `:conformance` (`:ok | :failed`), the per-epoch accounting, and the
  observed `:max_in_flight`.
  """
  @spec validate(map() | String.t(), keyword()) :: map()
  def validate(log_or_path, opts \\ [])

  def validate(log, opts) when is_map(log), do: run_validation(log, opts)

  def validate(path, opts) when is_binary(path) do
    case load_log(path) do
      {:ok, log} -> run_validation(log, opts)
      {:error, reason} -> log_unreadable(path, reason)
    end
  end

  @doc """
  Validates the log at `log_or_path` as the log of `run_id` -- the exact
  judgment the results-validation law asks for: this run, this log,
  validated or not.
  """
  @spec validate_run(String.t(), map() | String.t(), keyword()) :: map()
  def validate_run(run_id, log_or_path, opts \\ []) when is_binary(run_id) do
    validate(log_or_path, Keyword.put(opts, :run_id, run_id))
  end

  @doc """
  Resolves the OCEL log emitter module configured for run-id input
  (`config :xaas, :ultracode_ocel_log_emitter`, default
  `Xaas.Ultracode.OcelLog`). Returns `{:ok, log}` via the emitter's
  `emit/1`, or `{:error, :no_emitter}` when the module is not loaded on
  this branch (typed refusal -- the emitter is W3-A5's owned mutation).
  """
  @spec emit_log(String.t()) :: {:ok, map()} | {:error, :no_emitter | term()}
  def emit_log(run_id) do
    emitter = Application.get_env(:xaas, :ultracode_ocel_log_emitter, Xaas.Ultracode.OcelLog)

    if Code.ensure_loaded?(emitter) and function_exported?(emitter, :emit, 1) do
      emitter.emit(run_id)
    else
      {:error, :no_emitter}
    end
  end

  # ------------------------------------------------------------------
  # Law core
  # ------------------------------------------------------------------

  defp run_validation(log, opts) do
    run_id = Keyword.get(opts, :run_id)
    capacity = Keyword.get(opts, :capacity, @default_capacity)

    {structural_violations, events, objects} = conformance(log)

    fatal = fatal_structure?(log)

    # The conformance court (W3-A6, when it lands) replaces the local
    # structural violation list wholesale -- it is never layered on top,
    # so its verdict cannot double-count the local checks' findings.
    structural_violations =
      with false <- fatal,
           court when not is_nil(court) <-
             Application.get_env(:xaas, :ultracode_ocel_conformance_court) do
        Enum.map(court.check(log), &Map.put_new(&1, :epoch_id, nil))
      else
        _ -> structural_violations
      end

    semantic_violations =
      if fatal do
        # The event collection could not be enumerated; the semantic
        # checks have no subject. The structural list is the whole verdict.
        []
      else
        semantic_checks(events, objects, run_id, capacity)
      end

    violations = structural_violations ++ semantic_violations

    %{
      verdict: if(violations == [], do: :validated, else: :not_validated),
      run_id: run_id,
      violations: violations,
      conformance: if(structural_violations == [], do: :ok, else: :failed),
      epochs: epoch_accounting(events, objects),
      max_in_flight: max_in_flight_count(events),
      capacity: capacity
    }
  end

  # A log that is not a map, or whose "events"/"objects" are not lists,
  # cannot be semantically judged at all.
  defp fatal_structure?(log) when not is_map(log), do: true

  defp fatal_structure?(log) do
    not (is_list(Map.get(log, "events")) and is_list(Map.get(log, "objects")))
  end

  defp log_unreadable(path, reason) do
    %{
      verdict: :not_validated,
      run_id: nil,
      violations: [
        %{
          code: :log_unreadable,
          epoch_id: nil,
          message: "log #{inspect(path)} could not be loaded: #{inspect(reason)}"
        }
      ],
      conformance: :failed,
      epochs: %{},
      max_in_flight: nil,
      capacity: @default_capacity
    }
  end

  # ------------------------------------------------------------------
  # (a) Structural conformance -- OCEL 2.0 JSON shape
  # ------------------------------------------------------------------

  # Returns {violations, events, objects}: the normalized (parseable
  # subset) event and object lists for the semantic checks to consume.
  @doc false
  def conformance(log) when is_map(log) do
    declared_event_types = declared_types(log, "eventTypes")
    declared_object_types = declared_types(log, "objectTypes")

    {object_violations, objects} = check_objects(log, declared_object_types)
    {event_violations, events} = check_events(log, objects, declared_event_types)

    {collection_violations(log) ++ object_violations ++ event_violations, events, objects}
  end

  def conformance(log) do
    {[
       %{
         code: :not_an_ocel_log,
         epoch_id: nil,
         message:
           "log is not an OCEL 2.0 JSON object (expected a top-level map, got #{inspect(log)})"
       }
     ], [], []}
  end

  @required_collections ~w(objectTypes eventTypes events objects)

  defp collection_violations(log) do
    @required_collections
    |> Enum.reject(&is_list(Map.get(log, &1)))
    |> Enum.map(fn key ->
      %{
        code: :missing_collection,
        epoch_id: nil,
        message:
          "OCEL 2.0 JSON requires top-level #{inspect(key)} to be a list; " <>
            "got #{inspect(Map.get(log, key))}"
      }
    end)
  end

  # eventTypes/objectTypes elements: the OCEL 2.0 serialization emits maps
  # with a "name" (or "type") field; the in-repo projection emits plain
  # strings. Both accepted; anything else declares nothing.
  defp declared_types(log, key) do
    case Map.get(log, key) do
      types when is_list(types) ->
        Enum.flat_map(types, fn
          type when is_binary(type) -> [type]
          %{"name" => name} when is_binary(name) -> [name]
          %{"type" => type} when is_binary(type) -> [type]
          _other -> []
        end)

      _missing_or_not_list ->
        []
    end
  end

  defp check_objects(log, declared_object_types) do
    objects = List.wrap(Map.get(log, "objects"))

    objects
    |> Enum.reduce({[], [], MapSet.new()}, fn object, {violations, ok_objects, seen_ids} ->
      case normalize_object(object) do
        {:ok, normalized} ->
          violations =
            violations
            |> Kernel.++(duplicate_id_violation(normalized["id"], seen_ids))
            |> Kernel.++(
              undeclared_type_violation(
                normalized["type"],
                declared_object_types,
                "object",
                normalized["id"]
              )
            )

          {violations, ok_objects ++ [normalized], MapSet.put(seen_ids, normalized["id"])}

        {:error, message} ->
          {violations ++ [%{code: :malformed_object, epoch_id: nil, message: message}],
           ok_objects, seen_ids}
      end
    end)
    |> then(fn {violations, ok_objects, _seen} -> {violations, ok_objects} end)
  end

  defp normalize_object(%{"id" => id, "type" => type} = object)
       when is_binary(id) and is_binary(type) do
    {:ok, Map.take(object, ["id", "type"])}
  end

  defp normalize_object(other) do
    {:error, "OCEL object must be a map with string \"id\" and \"type\"; got #{inspect(other)}"}
  end

  defp check_events(log, objects, declared_event_types) do
    events = List.wrap(Map.get(log, "events"))
    object_types = objects |> Map.new(fn %{"id" => id, "type" => type} -> {id, type} end)

    events
    |> Enum.reduce({[], [], MapSet.new()}, fn event, {violations, ok_events, seen_ids} ->
      case normalize_event(event) do
        {:ok, normalized} ->
          violations =
            violations
            |> Kernel.++(duplicate_id_violation(normalized["id"], seen_ids))
            |> Kernel.++(
              undeclared_type_violation(
                normalized["type"],
                declared_event_types,
                "event",
                normalized["id"]
              )
            )
            |> Kernel.++(relationships_violations(normalized, object_types))

          {violations, ok_events ++ [normalized], MapSet.put(seen_ids, normalized["id"])}

        {:error, message} ->
          {violations ++ [%{code: :malformed_event, epoch_id: nil, message: message}], ok_events,
           seen_ids}
      end
    end)
    |> then(fn {violations, ok_events, _seen} ->
      {violations, Enum.map(ok_events, &tag_relationship_object_types(&1, object_types))}
    end)
  end

  # Attach each relationship's target object type so epoch-binding
  # resolution downstream never re-scans the object list.
  defp tag_relationship_object_types(event, object_types) do
    relationships =
      Enum.map(event["relationships"], fn rel ->
        Map.put(rel, "__object_type", Map.get(object_types, rel["objectId"]))
      end)

    Map.put(event, "relationships", relationships)
  end

  defp normalize_event(%{"id" => id, "type" => type, "time" => time} = event)
       when is_binary(id) and is_binary(type) and is_binary(time) do
    case DateTime.from_iso8601(time) do
      {:ok, parsed, _offset} ->
        attributes = Map.get(event, "attributes", %{})
        relationships = Map.get(event, "relationships", [])

        cond do
          not is_map(attributes) ->
            {:error,
             "event #{inspect(id)}: \"attributes\" must be a map; got #{inspect(attributes)}"}

          not is_list(relationships) ->
            {:error,
             "event #{inspect(id)}: \"relationships\" must be a list; got #{inspect(relationships)}"}

          true ->
            {:ok,
             %{
               "id" => id,
               "type" => type,
               "time" => time,
               "__parsed_time" => parsed,
               "attributes" => attributes,
               "relationships" => relationships
             }}
        end

      {:error, _} ->
        {:error,
         "event #{inspect(id)}: \"time\" #{inspect(time)} is not a parseable ISO8601 timestamp"}
    end
  end

  defp normalize_event(other) do
    {:error,
     "OCEL event must be a map with string \"id\", \"type\", and ISO8601 \"time\"; got #{inspect(other)}"}
  end

  defp duplicate_id_violation(id, seen_ids) do
    if MapSet.member?(seen_ids, id) do
      [
        %{
          code: :duplicate_id,
          epoch_id: nil,
          event_id: id,
          message: "duplicate id #{inspect(id)}"
        }
      ]
    else
      []
    end
  end

  defp undeclared_type_violation(type, declared, kind, id) do
    if type in declared do
      []
    else
      [
        %{
          code: :undeclared_type,
          epoch_id: nil,
          message:
            "#{kind} #{inspect(id)} has undeclared type #{inspect(type)} " <>
              "(not in the log's declared types)"
        }
      ]
    end
  end

  defp relationships_violations(event, object_types) do
    event["relationships"]
    |> Enum.flat_map(fn
      %{"objectId" => object_id} = rel when is_binary(object_id) ->
        if Map.has_key?(object_types, object_id) do
          []
        else
          [
            %{
              code: :dangling_relationship,
              epoch_id: nil,
              event_id: event["id"],
              message:
                "event #{inspect(event["id"])} relates to undeclared object #{inspect(object_id)}" <>
                  qualifier_suffix(rel)
            }
          ]
        end

      other ->
        [
          %{
            code: :malformed_relationship,
            epoch_id: nil,
            event_id: event["id"],
            message:
              "event #{inspect(event["id"])} has a relationship without a string \"objectId\": " <>
                "#{inspect(other)}"
          }
        ]
    end)
  end

  defp qualifier_suffix(%{"qualifier" => q}) when is_binary(q), do: " (qualifier #{inspect(q)})"
  defp qualifier_suffix(_), do: ""

  # ------------------------------------------------------------------
  # (b) Completeness -- every epoch claimed, exactly one terminal,
  #     capacity law honored, run binding correct
  # ------------------------------------------------------------------

  defp semantic_checks(events, objects, requested_run_id, capacity) do
    epoch_object_ids =
      objects |> Enum.filter(&(&1["type"] == "epoch")) |> MapSet.new(& &1["id"])

    grouped = group_events_by_epoch(events)

    {unattributable_groups, epoch_groups} =
      Map.split_with(grouped, fn {key, _} -> is_tuple(key) end)

    universe =
      epoch_object_ids
      |> MapSet.union(MapSet.new(Map.keys(epoch_groups)))
      |> Enum.sort()

    run_binding_violations(events, objects, requested_run_id) ++
      Enum.flat_map(universe, fn epoch_id ->
        epoch_violations(epoch_id, Map.get(epoch_groups, epoch_id, []))
      end) ++
      Enum.map(unattributable_groups, fn {_key, [event | _]} ->
        unattributable_violation(event)
      end) ++
      capacity_violation(events, capacity)
  end

  defp unattributable_violation(event) do
    %{
      code: :unattributable_event,
      epoch_id: nil,
      event_id: event["id"],
      message:
        "#{event["type"]} event #{inspect(event["id"])} binds to no epoch (no epoch_id attribute, " <>
          "no epoch-object relationship) -- its receipt can never be traced to a claimed epoch"
    }
  end

  # Run binding: run-type object ids + event attributes["run_id"] +
  # relationships to run-type objects. A requested run_id must be the log's
  # ONLY run binding.
  defp run_binding_violations(_events, _objects, nil), do: []

  defp run_binding_violations(events, objects, requested_run_id) do
    run_object_ids = objects |> Enum.filter(&(&1["type"] == "run")) |> Enum.map(& &1["id"])

    attribute_run_ids =
      events
      |> Enum.map(&get_in(&1, ["attributes", "run_id"]))
      |> Enum.reject(&is_nil/1)

    relationship_run_ids =
      events
      |> Enum.flat_map(& &1["relationships"])
      |> Enum.filter(&(&1["__object_type"] == "run"))
      |> Enum.map(& &1["objectId"])

    bound_runs = Enum.uniq(run_object_ids ++ attribute_run_ids ++ relationship_run_ids)

    if bound_runs == [requested_run_id] do
      []
    else
      detail =
        if bound_runs == [] do
          "log carries no run binding (no run object, no run_id attribute, no run relationship)"
        else
          "log is for run(s) #{inspect(Enum.sort(bound_runs))}"
        end

      [
        %{
          code: :wrong_run,
          epoch_id: nil,
          message: "#{detail}; cannot validate it as run #{inspect(requested_run_id)}"
        }
      ]
    end
  end

  # Groups epoch-bound lifecycle events by epoch id. Binding:
  # attributes["epoch_id"] if present, else exactly one relationship to an
  # epoch-type object. Unattributable lifecycle events group under a tuple
  # key and become violations in their own right.
  defp group_events_by_epoch(events) do
    Enum.reduce(events, %{}, fn event, acc ->
      if event["type"] in @epoch_lifecycle_events do
        case epoch_of_event(event) do
          {:ok, epoch_id} -> Map.update(acc, epoch_id, [event], &[event | &1])
          :unbound -> Map.update(acc, {:unattributable, event["id"]}, [event], &[event | &1])
        end
      else
        acc
      end
    end)
  end

  defp epoch_of_event(event) do
    case event["attributes"]["epoch_id"] do
      epoch_id when is_binary(epoch_id) ->
        {:ok, epoch_id}

      _absent ->
        case event["relationships"]
             |> Enum.filter(&(&1["__object_type"] == "epoch"))
             |> Enum.uniq_by(& &1["objectId"]) do
          [%{"objectId" => epoch_id}] -> {:ok, epoch_id}
          [] -> :unbound
          _ambiguous -> :unbound
        end
    end
  end

  defp epoch_violations(epoch_id, epoch_events) do
    claims = Enum.filter(epoch_events, &(&1["type"] == @claim_event))
    terminals = Enum.filter(epoch_events, &(&1["type"] == @terminal_event))

    closed_terminals =
      Enum.filter(terminals, fn t ->
        verification = t["attributes"]["verification"]
        is_binary(verification) and verification in @terminal_verifications
      end)

    invalid_terminals = terminals -- closed_terminals

    claim_violations =
      cond do
        claims == [] and closed_terminals != [] ->
          [
            %{
              code: :unclaimed_receipt_closed,
              epoch_id: epoch_id,
              event_id: hd(closed_terminals)["id"],
              message:
                "#{@terminal_event} event #{inspect(hd(closed_terminals)["id"])} references epoch " <>
                  "#{inspect(epoch_id)} which was never claimed"
            }
          ]

        length(claims) > 1 ->
          [
            %{
              code: :duplicate_claim,
              epoch_id: epoch_id,
              event_id: hd(claims)["id"],
              message:
                "epoch #{inspect(epoch_id)} has #{length(claims)} #{@claim_event} events " <>
                  "#{inspect(Enum.map(claims, & &1["id"]))}; exactly one is lawful"
            }
          ]

        claims == [] ->
          [
            %{
              code: :missing_claim,
              epoch_id: epoch_id,
              message: "epoch #{inspect(epoch_id)} never appears via an #{@claim_event} event"
            }
          ]

        true ->
          []
      end

    terminal_violations =
      cond do
        claims != [] and closed_terminals == [] ->
          [
            %{
              code: :missing_terminal,
              epoch_id: epoch_id,
              message:
                "epoch #{inspect(epoch_id)} is claimed but has no terminal #{@terminal_event} " <>
                  "with verification passed/failed/refused -- stuck, not receipt-accounted"
            }
          ]

        length(closed_terminals) > 1 ->
          [
            %{
              code: :duplicate_terminal,
              epoch_id: epoch_id,
              message:
                "epoch #{inspect(epoch_id)} has #{length(closed_terminals)} terminal " <>
                  "#{@terminal_event} events #{inspect(Enum.map(closed_terminals, & &1["id"]))}; " <>
                  "exactly one is lawful"
            }
          ]

        true ->
          []
      end

    invalid_verification_violations =
      Enum.map(invalid_terminals, fn t ->
        %{
          code: :invalid_verification,
          epoch_id: epoch_id,
          event_id: t["id"],
          message:
            "#{@terminal_event} event #{inspect(t["id"])} on epoch #{inspect(epoch_id)} has verification " <>
              "#{inspect(t["attributes"]["verification"])}; only " <>
              "#{Enum.join(@terminal_verifications, " | ")} is terminal evidence"
        }
      end)

    ordering_violations =
      if length(claims) == 1 and length(closed_terminals) == 1 do
        claim = hd(claims)
        terminal = hd(closed_terminals)

        if DateTime.compare(terminal["__parsed_time"], claim["__parsed_time"]) == :lt do
          [
            %{
              code: :terminal_before_claim,
              epoch_id: epoch_id,
              event_id: terminal["id"],
              message:
                "epoch #{inspect(epoch_id)}'s terminal event #{inspect(terminal["id"])} precedes its " <>
                  "claim #{inspect(claim["id"])} in time"
            }
          ]
        else
          []
        end
      else
        []
      end

    claim_violations ++
      terminal_violations ++ invalid_verification_violations ++ ordering_violations
  end

  # Capacity: at every instant, at most `capacity` workers in flight.
  # In-flight interval = [claim, terminal); a claimed-but-never-terminated
  # epoch stays in flight for the rest of the log (a stuck worker never
  # freed its slot). At identical timestamps a closing worker frees its
  # slot before a new claim takes it (-1 sorts before +1).
  defp capacity_violation(events, capacity) when is_integer(capacity) and capacity >= 0 do
    case max_in_flight(events) do
      nil ->
        []

      %{count: count, at: at} when count > capacity ->
        [
          %{
            code: :capacity_breach,
            epoch_id: nil,
            message:
              "#{count} workers in flight at #{DateTime.to_iso8601(at)}; " <>
                "the run's capacity law allows at most #{capacity}"
          }
        ]

      _within_capacity ->
        []
    end
  end

  defp max_in_flight(events) do
    claims = Enum.filter(events, &(&1["type"] == @claim_event))

    terminal_times_by_epoch =
      events
      |> Enum.filter(&(&1["type"] == @terminal_event))
      |> Enum.flat_map(fn event ->
        case epoch_of_event(event) do
          {:ok, epoch_id} -> [{epoch_id, event["__parsed_time"]}]
          :unbound -> []
        end
      end)
      |> Enum.group_by(fn {epoch_id, _} -> epoch_id end, fn {_, time} -> time end)

    deltas =
      Enum.flat_map(claims, fn claim ->
        with {:ok, epoch_id} <- epoch_of_event(claim) do
          claim_point = {claim["__parsed_time"], 1}

          case Map.get(terminal_times_by_epoch, epoch_id, []) do
            [] -> [claim_point]
            times -> [claim_point, {Enum.min(times, DateTime), -1}]
          end
        else
          _unbound -> []
        end
      end)
      |> Enum.sort(fn {t1, d1}, {t2, d2} ->
        case DateTime.compare(t1, t2) do
          :lt -> true
          :gt -> false
          :eq -> d1 < d2
        end
      end)

    sweep(deltas, 0, nil)
  end

  defp max_in_flight_count(events) do
    case max_in_flight(events) do
      nil -> nil
      %{count: count} -> count
    end
  end

  defp sweep([], _in_flight, max), do: max

  defp sweep([{time, delta} | rest], in_flight, max) do
    now = in_flight + delta
    max = if max == nil or now > max.count, do: %{count: now, at: time}, else: max
    sweep(rest, now, max)
  end

  # ------------------------------------------------------------------
  # Per-epoch accounting in the result map
  # ------------------------------------------------------------------

  defp epoch_accounting(events, objects) do
    epoch_object_ids = objects |> Enum.filter(&(&1["type"] == "epoch")) |> Enum.map(& &1["id"])
    grouped = group_events_by_epoch(events)

    epoch_object_ids
    |> Kernel.++(grouped |> Map.keys() |> Enum.filter(&is_binary/1))
    |> Enum.uniq()
    |> Map.new(fn epoch_id ->
      epoch_events = Map.get(grouped, epoch_id, [])

      claims =
        epoch_events
        |> Enum.filter(&(&1["type"] == @claim_event))
        |> Enum.sort_by(& &1["__parsed_time"], {:asc, DateTime})

      terminals =
        epoch_events
        |> Enum.filter(&(&1["type"] == @terminal_event))
        |> Enum.sort_by(& &1["__parsed_time"], {:asc, DateTime})

      {epoch_id,
       %{
         claimed_at: event_time(Enum.at(claims, 0)),
         terminal:
           case Enum.at(terminals, 0) do
             nil -> nil
             t -> %{event_id: t["id"], verification: t["attributes"]["verification"]}
           end
       }}
    end)
  end

  defp event_time(nil), do: nil
  defp event_time(event), do: DateTime.to_iso8601(event["__parsed_time"])

  # ------------------------------------------------------------------
  # Load
  # ------------------------------------------------------------------

  defp load_log(path) do
    with {:ok, body} <- File.read(path),
         {:ok, log} <- Jason.decode(body) do
      {:ok, log}
    end
  end
end
