defmodule Xaas.Ultracode.RunValidation do
  # Module attributes precede the moduledoc: the doc text interpolates
  # @default_capacity, and attributes are only visible to code that
  # lexically follows their definition.
  @default_capacity 5

  @moduledoc """
  The results-validation law for Ultracode runs, closed over OCEL 2.0:
  a run's RESULTS are validated if and only if its OCEL 2.0 log

    (a) passes structural conformance to the OCEL 2.0 JSON shape, and
    (b) accounts for every epoch of the run with terminal, receipt-backed
        evidence -- each epoch appears via an appearance event
        (`epoch_claimed`, or the emitter's `epoch_started` /
        `epoch_scheduled`), reaches exactly one VERIFIED `receipt_closed`
        (verified by a `verification` attribute of `passed`/`failed`/
        `refused`, or by a sibling `verification_passed` /
        `verification_failed` / `refused` event bound to the same epoch),
        and the number of workers in flight (appearance-to-close
        intervals, derivable purely from event times) never exceeds the
        run's capacity law (5 by default -- the operator-ordered standing
        wave size pinned in `Xaas.Ultracode.Run`'s `:autonomic_wave`
        action).

  The verdict is `:validated` or `:not_validated` and every
  `:not_validated` verdict carries a violation list naming the offending
  epoch ids, so a red verdict is traceable to named events, never an
  unexplained boolean.

  ## Log shape -- the bridge between the two in-repo OCEL dialects

  This module is the results-to-OCEL bridge, so it accepts BOTH in-repo
  OCEL 2.0 serializations and judges them under one law:

    * `Xaas.Ocel.Projection.to_ocel_map/1` (persisted-OCEL projection):
      top-level `"objectTypes"` / `"eventTypes"` / `"objects"` /
      `"events"`, events `{"id", "type", "time", "attributes",
      "relationships"}`, objects `{"id", "type"}`.
    * `Xaas.Ultracode.OcelEgress.build_document/3` (Run/Epoch/Receipt
      egress, landed 2026-09-20): the same four collections under the
      standards' `"ocel:"`-prefixed key names, capitalized object types
      (`"Run"`, `"Epoch"`, ...), verification as SIBLING EVENTS
      (`verification_passed` / `verification_failed` / `refused`) rather
      than a `receipt_closed` attribute, and appearance facts carried by
      `epoch_scheduled` / `epoch_started` (`epoch_claimed` is declared
      but never emitted -- `Lease.claim_next/3` persists no bind
      timestamp, and the egress refuses to fabricate one).

  Concretely: each required top-level collection is resolved as
  `"ocel:<key>"` first, then the unprefixed key; object-type role
  matching (run/epoch) is case-insensitive. Everything else -- unique
  ids, declared types, non-dangling relationships, parseable ISO8601
  times -- is dialect-independent law.

  ## Terminal, receipt-backed evidence (what "(b)" means precisely)

  An epoch is receipt-accounted iff it has EXACTLY ONE `receipt_closed`
  event that is VERIFIED, where verified means either:

    * the event's `attributes["verification"]` is `"passed"`,
      `"failed"`, or `"refused"` (the projection-side dialect), or
    * the log contains at least one sibling event of type
      `verification_passed`, `verification_failed`, or `refused` bound
      to the same epoch (the egress-side dialect).

  A `receipt_closed` with a `verification` attribute outside that set is
  named as `:invalid_verification` and does not close the epoch. The
  appearance set is, in slot-holding priority order, `epoch_claimed`
  (best: an actual claim), then `epoch_started` (worker began; a real
  persisted `started_at`), then `epoch_scheduled` (weakest: planned, no
  worker proof yet). A duplicate WITHIN one appearance type is a
  `:duplicate_claim`; one epoch having several appearance TYPES is
  normal (scheduled AND started) and lawful.

  ## Capacity

  In-flight interval per epoch = [first available appearance event time
  in the priority order above, earliest `receipt_closed` time); an epoch
  with no close stays in flight for the rest of the log (a stuck worker
  never freed its slot). At identical timestamps a closing worker frees
  its slot before a new appearance takes it. Max overlap is compared
  against the run's capacity (`:capacity` option, default
  #{@default_capacity}).

  ## Wiring: where the log comes from

  The deterministic run-to-OCEL-log projection is
  `Xaas.Ultracode.OcelEgress.derive_run/1` (persisted Run/Epoch/Receipt
  state, `{:ok, document} | {:error, :run_not_found}`). Run-id input
  resolves through the configurable emitter module
  (`config :xaas, :ultracode_ocel_log_emitter`, default
  `Xaas.Ultracode.OcelEgress`, exporting `derive_run/1`); the mix task
  therefore accepts a bare run id end-to-end. Path input validates the
  JSON file directly. The derivation itself is NOT duplicated here.

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

  @terminal_verifications ~w(passed failed refused)

  # Appearance events, in slot-holding priority order (best first).
  @claim_events ~w(epoch_claimed epoch_started epoch_scheduled)

  @terminal_event "receipt_closed"
  @verification_events ~w(verification_passed verification_failed refused)

  # All event types that carry per-epoch semantic weight.
  @epoch_lifecycle_events ~w(epoch_claimed epoch_started epoch_scheduled receipt_closed verification_passed verification_failed refused)

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
  Resolves the OCEL log for `run_id` through the configured emitter
  module (`config :xaas, :ultracode_ocel_log_emitter`, default
  `Xaas.Ultracode.OcelEgress`, exporting `derive_run/1` returning
  `{:ok, document}`). Returns the emitter's own result, or
  `{:error, :no_emitter}` when the module is not loaded on this branch
  (typed refusal -- the derivation is the emitter's owned mutation and
  is never re-derived here).
  """
  @spec emit_log(String.t()) :: {:ok, map()} | {:error, :no_emitter | :run_not_found | term()}
  def emit_log(run_id) do
    emitter = Application.get_env(:xaas, :ultracode_ocel_log_emitter, Xaas.Ultracode.OcelEgress)

    if Code.ensure_loaded?(emitter) and function_exported?(emitter, :derive_run, 1) do
      emitter.derive_run(run_id)
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

  # A log that is not a map, or whose event/object collections cannot be
  # read as lists in either key dialect, cannot be semantically judged.
  defp fatal_structure?(log) when not is_map(log), do: true

  defp fatal_structure?(log) do
    not (is_list(coll(log, "events")) and is_list(coll(log, "objects")))
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
  # Key-dialect bridge (ocel:-prefixed egress vs unprefixed projection)
  # ------------------------------------------------------------------

  defp coll(log, key) do
    Map.get(log, "ocel:" <> key) || Map.get(log, key)
  end

  # Object-type ROLE matching: the egress capitalizes ("Run", "Epoch"),
  # the projection lowercases. Roles, not spellings, are the law.
  defp role_object?(nil, _role), do: false
  defp role_object?(type, role) when is_binary(type), do: String.downcase(type) == role

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
    |> Enum.reject(&is_list(coll(log, &1)))
    |> Enum.map(fn key ->
      %{
        code: :missing_collection,
        epoch_id: nil,
        message:
          "OCEL 2.0 JSON requires top-level #{inspect(key)} to be a list (either the " <>
            "\"ocel:#{key}\" or \"#{key}\" form); got #{inspect(coll(log, key))}"
      }
    end)
  end

  # eventTypes/objectTypes elements: the OCEL 2.0 serialization emits maps
  # with a "name" (or "type") field; the in-repo projection emits plain
  # strings. Both accepted; anything else declares nothing.
  defp declared_types(log, key) do
    case coll(log, key) do
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
    objects = coll(log, "objects") |> List.wrap()

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
    events = coll(log, "events") |> List.wrap()
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
  # (b) Completeness -- every epoch claimed, exactly one verified
  #     terminal, capacity law honored, run binding correct
  # ------------------------------------------------------------------

  defp semantic_checks(events, objects, requested_run_id, capacity) do
    epoch_object_ids =
      objects |> Enum.filter(&role_object?(&1["type"], "epoch")) |> MapSet.new(& &1["id"])

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

  # Run binding: run-role object ids + event attributes["run_id"] +
  # relationships to run-role objects. A requested run_id must be the
  # log's ONLY run binding.
  defp run_binding_violations(_events, _objects, nil), do: []

  defp run_binding_violations(events, objects, requested_run_id) do
    run_object_ids =
      objects |> Enum.filter(&role_object?(&1["type"], "run")) |> Enum.map(& &1["id"])

    attribute_run_ids =
      events
      |> Enum.map(&get_in(&1, ["attributes", "run_id"]))
      |> Enum.reject(&is_nil/1)

    relationship_run_ids =
      events
      |> Enum.flat_map(& &1["relationships"])
      |> Enum.filter(&role_object?(&1["__object_type"], "run"))
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
  # attributes["epoch_id"] if present, else exactly one relationship to
  # an epoch-role object. Unattributable lifecycle events group under a
  # tuple key and become violations in their own right.
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
             |> Enum.filter(&role_object?(&1["__object_type"], "epoch"))
             |> Enum.uniq_by(& &1["objectId"]) do
          [%{"objectId" => epoch_id}] -> {:ok, epoch_id}
          [] -> :unbound
          _ambiguous -> :unbound
        end
    end
  end

  # A receipt_closed is VERIFIED (terminal evidence) when its own
  # attributes carry a lawful verification value, or when the log carries
  # a sibling verification event for the same epoch.
  defp verified?(terminal_event, sibling_events) do
    case terminal_event["attributes"]["verification"] do
      v when is_binary(v) -> v in @terminal_verifications
      _absent -> Enum.any?(sibling_events, &(&1["type"] in @verification_events))
    end
  end

  defp epoch_violations(epoch_id, epoch_events) do
    claims = Enum.filter(epoch_events, &(&1["type"] in @claim_events))
    terminals = Enum.filter(epoch_events, &(&1["type"] == @terminal_event))
    siblings = Enum.filter(epoch_events, &(&1["type"] in @verification_events))

    verified_terminals = Enum.filter(terminals, &verified?(&1, siblings))

    invalid_terminals =
      Enum.filter(terminals, fn t ->
        case t["attributes"]["verification"] do
          v when is_binary(v) -> v not in @terminal_verifications
          _absent -> false
        end
      end)

    claim_violations =
      cond do
        claims == [] and verified_terminals != [] ->
          [
            %{
              code: :unclaimed_receipt_closed,
              epoch_id: epoch_id,
              event_id: hd(verified_terminals)["id"],
              message:
                "#{@terminal_event} event #{inspect(hd(verified_terminals)["id"])} references epoch " <>
                  "#{inspect(epoch_id)} which was never claimed"
            }
          ]

        claims == [] ->
          [
            %{
              code: :missing_claim,
              epoch_id: epoch_id,
              message:
                "epoch #{inspect(epoch_id)} never appears via an appearance event " <>
                  "(#{Enum.join(@claim_events, " | ")})"
            }
          ]

        true ->
          # Duplicate WITHIN one appearance type is the lie; several
          # appearance TYPES on one epoch (scheduled + started + claimed)
          # is the normal lifecycle.
          case Enum.find(@claim_events, fn type ->
                 claims |> Enum.filter(&(&1["type"] == type)) |> length() > 1
               end) do
            nil ->
              []

            type ->
              dups = Enum.filter(claims, &(&1["type"] == type))

              [
                %{
                  code: :duplicate_claim,
                  epoch_id: epoch_id,
                  event_id: hd(dups)["id"],
                  message:
                    "epoch #{inspect(epoch_id)} has #{length(dups)} #{type} events " <>
                      "#{inspect(Enum.map(dups, & &1["id"]))}; exactly one per appearance type is lawful"
                }
              ]
          end
      end

    terminal_violations =
      cond do
        verified_terminals == [] and claims != [] ->
          [
            %{
              code: :missing_terminal,
              epoch_id: epoch_id,
              message:
                "epoch #{inspect(epoch_id)} is claimed but has no VERIFIED terminal " <>
                  "#{@terminal_event} (verification passed/failed/refused attribute, or a sibling " <>
                  "#{Enum.join(@verification_events, " / ")} event) -- stuck, not receipt-accounted"
            }
          ]

        length(verified_terminals) > 1 ->
          [
            %{
              code: :duplicate_terminal,
              epoch_id: epoch_id,
              message:
                "epoch #{inspect(epoch_id)} has #{length(verified_terminals)} verified terminal " <>
                  "#{@terminal_event} events #{inspect(Enum.map(verified_terminals, & &1["id"]))}; " <>
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
      if length(claims) >= 1 and length(verified_terminals) == 1 do
        first_claim = claims |> Enum.map(& &1["__parsed_time"]) |> Enum.min(DateTime)
        terminal = hd(verified_terminals)

        if DateTime.compare(terminal["__parsed_time"], first_claim) == :lt do
          [
            %{
              code: :terminal_before_claim,
              epoch_id: epoch_id,
              event_id: terminal["id"],
              message:
                "epoch #{inspect(epoch_id)}'s terminal event #{inspect(terminal["id"])} precedes " <>
                  "its earliest appearance event in time"
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
  # In-flight interval = [first available appearance event in priority
  # order (claimed > started > scheduled), earliest receipt_closed);
  # an epoch with no close stays in flight for the rest of the log (a
  # stuck worker never freed its slot). At identical timestamps a closing
  # worker frees its slot before a new appearance takes it (-1 sorts
  # before +1).
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
    close_times_by_epoch =
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
      events
      |> Enum.filter(&(&1["type"] in @claim_events))
      |> Enum.flat_map(fn event ->
        case epoch_of_event(event) do
          {:ok, epoch_id} -> [{epoch_id, event}]
          :unbound -> []
        end
      end)
      |> Enum.group_by(fn {epoch_id, _} -> epoch_id end, fn {_, event} -> event end)
      |> Enum.flat_map(fn {epoch_id, epoch_claims} ->
        with {:ok, hold_start} <- hold_start(epoch_claims) do
          close =
            case Map.get(close_times_by_epoch, epoch_id, []) do
              [] -> nil
              times -> Enum.min(times, DateTime)
            end

          claim_point = {hold_start, 1}

          case close do
            nil -> [claim_point]
            %DateTime{} = t -> [claim_point, {t, -1}]
          end
        else
          _unbound -> []
        end
      end)
      # At equal timestamps, -1 (a worker freeing its slot) sorts before +1.
      |> Enum.sort(fn {t1, d1}, {t2, d2} ->
        case DateTime.compare(t1, t2) do
          :lt -> true
          :gt -> false
          :eq -> d1 < d2
        end
      end)

    sweep(deltas, 0, nil)
  end

  # First available appearance event in priority order -- the moment a
  # slot became held by a worker (or, weakest, was scheduled).
  defp hold_start(epoch_claims) do
    priority_type =
      Enum.find(@claim_events, fn type -> Enum.any?(epoch_claims, &(&1["type"] == type)) end)

    case priority_type do
      nil ->
        :unbound

      type ->
        time =
          epoch_claims
          |> Enum.filter(&(&1["type"] == type))
          |> Enum.map(& &1["__parsed_time"])
          |> Enum.min(DateTime)

        {:ok, time}
    end
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
    epoch_object_ids =
      objects |> Enum.filter(&role_object?(&1["type"], "epoch")) |> Enum.map(& &1["id"])

    grouped = group_events_by_epoch(events)

    epoch_object_ids
    |> Kernel.++(grouped |> Map.keys() |> Enum.filter(&is_binary/1))
    |> Enum.uniq()
    |> Map.new(fn epoch_id ->
      epoch_events = Map.get(grouped, epoch_id, [])

      claims = Enum.filter(epoch_events, &(&1["type"] in @claim_events))

      terminals =
        epoch_events
        |> Enum.filter(&(&1["type"] == @terminal_event))
        |> Enum.sort_by(& &1["__parsed_time"], {:asc, DateTime})

      siblings = Enum.filter(epoch_events, &(&1["type"] in @verification_events))

      # Same priority rule as the capacity interval: the appearance that
      # first held the slot (claimed > started > scheduled).
      hold_event = priority_claim(claims)

      {epoch_id,
       %{
         claimed_at: event_time(hold_event),
         appearance_type: appearance_type(hold_event),
         terminal:
           case Enum.at(terminals, 0) do
             nil ->
               nil

             t ->
               verification =
                 case t["attributes"]["verification"] do
                   v when is_binary(v) -> v
                   _absent -> sibling_verification(siblings)
                 end

               %{event_id: t["id"], verification: verification}
           end
       }}
    end)
  end

  defp appearance_type(nil), do: nil
  defp appearance_type(event) when is_map(event), do: event["type"]

  # The appearance event that first held the slot: the highest-priority
  # type present (claimed > started > scheduled), earliest within it.
  defp priority_claim(claims) do
    priority_type =
      Enum.find(@claim_events, fn type -> Enum.any?(claims, &(&1["type"] == type)) end)

    case priority_type do
      nil ->
        nil

      type ->
        claims
        |> Enum.filter(&(&1["type"] == type))
        |> Enum.min_by(& &1["__parsed_time"])
    end
  end

  defp sibling_verification(siblings) do
    case Enum.find(@verification_events, fn type -> Enum.any?(siblings, &(&1["type"] == type)) end) do
      nil -> nil
      type -> type
    end
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
