defmodule Xaas.Ultracode.SemanticDrive.Ocel do
  @moduledoc """
  OCEL 2.0 projections of one semantic drive's observations (ARD section 13).

  The drive records what it OBSERVED -- each event with its observed time,
  attributes and object relationships, each object with its type and
  attributes -- and this module renders that one observation set twice:

    * `court_form/1` -- the vocabulary `Xaas.Ultracode.Ocel.Validator`
      (`mix xaas.ocel_validate`) admits: exactly the four top-level keys
      `ocel:objectTypes` / `ocel:eventTypes` / `ocel:events` /
      `ocel:objects`, type declarations as names, attributes as a JSON
      object;
    * `standard_form/1` -- the OCEL 2.0 standard JSON that
      `pm4py.read_ocel2_json/1` reads: `objectTypes` / `eventTypes` with
      typed attribute declarations, `events` / `objects`, attributes as
      `[{name, value}]` lists.

  The two vocabularies are disjoint at the top level (the court's is closed,
  so no single document satisfies both); `equivalent?/2` proves the two
  renderings carry the same events (id, type, time, attributes,
  relationships) and objects. OCEL records observation; it manufactures no
  authority.
  """

  @event_classes ~w(WorkOrderCreated CapabilityResolved LeaseAcquired ActuationStarted
                    ActuationCompleted VerificationCompleted ReceiptSealed StandingChanged
                    FrontierChanged MachineExperienceAdmitted)
  @object_types ~w(GoalCheckpoint WorkOrder Subject Provider Capability Lease Receipt
                   Repository Commit MachineExperience)
  # Classes beyond the ARD section 13 minimum, observed only by the
  # MachineExperience episodes (lane V23-M, PRD PR-014/PR-016, ARD section
  # 15): the router's decision and the bounded UNKNOWN exploration. A drive
  # renders them only when its caller declares them (`court_form/2`).
  @extension_classes ~w(RouteDecided ExplorationStarted ExplorationCompleted)
  @epoch_time "1970-01-01T00:00:00Z"

  @typedoc "One observed event."
  @type event :: %{
          required(:type) => String.t(),
          required(:time) => DateTime.t(),
          required(:attributes) => map(),
          required(:relationships) => [{String.t(), String.t()}]
        }

  @typedoc "Observed objects keyed by object id."
  @type objects :: %{String.t() => %{type: String.t(), attributes: map(), relationships: list()}}

  @doc "The ARD section 13 event classes, in lifecycle order."
  @spec event_classes() :: [String.t()]
  def event_classes, do: @event_classes

  @doc "The ARD section 13 object types."
  @spec object_types() :: [String.t()]
  def object_types, do: @object_types

  @doc """
  The event classes beyond the ARD section 13 minimum (ARD section 13 names
  a minimum set): `RouteDecided`, `ExplorationStarted`,
  `ExplorationCompleted` (the MachineExperience episodes, lane V23-M).
  """
  @spec extension_classes() :: [String.t()]
  def extension_classes, do: @extension_classes

  @doc "The distinct event classes present in `events`, in lifecycle order."
  @spec reached([event()]) :: [String.t()]
  def reached(events) do
    present = MapSet.new(events, & &1.type)
    Enum.filter(@event_classes, &MapSet.member?(present, &1))
  end

  @doc """
  The court-vocabulary rendering (`mix xaas.ocel_validate`). `event_types`
  declares the event classes (default: the ARD section 13 classes;
  `event_classes() ++ extension_classes()` for a MachineExperience episode).
  """
  @spec court_form({[event()], objects()}, [String.t()]) :: map()
  def court_form({events, objects}, event_types \\ @event_classes) do
    %{
      "ocel:objectTypes" => @object_types,
      "ocel:eventTypes" => event_types,
      "ocel:objects" =>
        Enum.map(sorted_objects(objects), fn {id, object} ->
          %{
            "id" => id,
            "type" => object.type,
            "attributes" => stringify(object.attributes),
            "relationships" => relationships(object.relationships)
          }
        end),
      "ocel:events" =>
        events
        |> numbered()
        |> Enum.map(fn {id, event} ->
          %{
            "id" => id,
            "type" => event.type,
            "time" => time(event.time),
            "attributes" => stringify(event.attributes),
            "relationships" => relationships(event.relationships)
          }
        end)
    }
  end

  @doc "The OCEL 2.0 standard JSON rendering (`pm4py.read_ocel2_json/1`); `event_types` as in `court_form/2`."
  @spec standard_form({[event()], objects()}, [String.t()]) :: map()
  def standard_form({events, objects}, event_types \\ @event_classes) do
    %{
      "objectTypes" =>
        Enum.map(@object_types, fn type ->
          %{"name" => type, "attributes" => declared(objects |> Map.values(), type)}
        end),
      "eventTypes" =>
        Enum.map(event_types, fn type ->
          %{"name" => type, "attributes" => declared(events, type)}
        end),
      "objects" =>
        Enum.map(sorted_objects(objects), fn {id, object} ->
          %{
            "id" => id,
            "type" => object.type,
            "attributes" =>
              object.attributes
              |> stringify()
              |> Enum.sort()
              |> Enum.map(fn {name, value} ->
                %{"name" => name, "value" => value, "time" => @epoch_time}
              end),
            "relationships" => relationships(object.relationships)
          }
        end),
      "events" =>
        events
        |> numbered()
        |> Enum.map(fn {id, event} ->
          %{
            "id" => id,
            "type" => event.type,
            "time" => time(event.time),
            "attributes" =>
              event.attributes
              |> stringify()
              |> Enum.sort()
              |> Enum.map(fn {name, value} -> %{"name" => name, "value" => value} end),
            "relationships" => relationships(event.relationships)
          }
        end)
    }
  end

  @doc """
  True iff a court-form and a standard-form document carry the same events
  (id, type, time, attributes, relationships) and objects (id, type,
  attributes, relationships).
  """
  @spec equivalent?(map(), map()) :: boolean()
  def equivalent?(court, standard) do
    court_events =
      Enum.map(court["ocel:events"] || [], fn e ->
        {e["id"], e["type"], e["time"], e["attributes"], e["relationships"]}
      end)

    standard_events =
      Enum.map(standard["events"] || [], fn e ->
        {e["id"], e["type"], e["time"], Map.new(e["attributes"], &{&1["name"], &1["value"]}),
         e["relationships"]}
      end)

    court_objects =
      Enum.map(court["ocel:objects"] || [], fn o ->
        {o["id"], o["type"], o["attributes"], o["relationships"]}
      end)

    standard_objects =
      Enum.map(standard["objects"] || [], fn o ->
        {o["id"], o["type"], Map.new(o["attributes"], &{&1["name"], &1["value"]}),
         o["relationships"]}
      end)

    court_events == standard_events and court_objects == standard_objects
  end

  @doc """
  The observations a court-form document renders (the inverse of
  `court_form/2`): events in document order with their parsed UTC times,
  attributes and relationships; objects keyed by id. Re-rendering the result
  with the same event types yields the same document (event ids are the
  document order and type), so an episode can compose one drive's recorded
  log with its own observations without re-describing them.
  """
  @spec from_court_form(map()) :: {:ok, {[event()], objects()}} | {:error, term()}
  def from_court_form(%{"ocel:events" => events, "ocel:objects" => objects})
      when is_list(events) and is_list(objects) do
    with {:ok, events} <- parse_events(events) do
      {:ok, {events, Map.new(objects, &parse_object/1)}}
    end
  end

  def from_court_form(_other), do: {:error, :not_a_court_form_document}

  defp parse_events(events) do
    Enum.reduce_while(events, {:ok, []}, fn event, {:ok, acc} ->
      case DateTime.from_iso8601(event["time"] || "") do
        {:ok, time, 0} ->
          entry = %{
            type: event["type"],
            time: time,
            attributes: event["attributes"] || %{},
            relationships: parse_relationships(event["relationships"])
          }

          {:cont, {:ok, [entry | acc]}}

        _ ->
          {:halt, {:error, {:unparseable_time, event["id"], event["time"]}}}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      error -> error
    end
  end

  defp parse_object(object) do
    {object["id"],
     %{
       type: object["type"],
       attributes: object["attributes"] || %{},
       relationships: parse_relationships(object["relationships"])
     }}
  end

  defp parse_relationships(relationships),
    do: Enum.map(relationships || [], &{&1["objectId"], &1["qualifier"]})

  # -- helpers ----------------------------------------------------------------

  defp numbered(events) do
    events
    |> Enum.with_index(1)
    |> Enum.map(fn {event, n} ->
      {"e" <> String.pad_leading(Integer.to_string(n), 3, "0") <> "-" <> event.type, event}
    end)
  end

  defp sorted_objects(objects), do: Enum.sort_by(objects, &elem(&1, 0))

  defp relationships(relationships) do
    relationships
    |> Enum.uniq()
    |> Enum.map(fn {object_id, qualifier} ->
      %{"objectId" => object_id, "qualifier" => qualifier}
    end)
  end

  defp declared(items, type) do
    items
    |> Enum.filter(&(&1.type == type))
    |> Enum.flat_map(&Map.keys(stringify(&1.attributes)))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(&%{"name" => &1, "type" => "string"})
  end

  defp stringify(attributes) do
    Map.new(attributes, fn {key, value} -> {to_string(key), value_string(value)} end)
  end

  defp value_string(value) when is_binary(value), do: value
  defp value_string(value) when is_integer(value) or is_float(value), do: to_string(value)
  defp value_string(value) when is_boolean(value), do: to_string(value)
  defp value_string(nil), do: ""
  defp value_string(value) when is_atom(value), do: Atom.to_string(value)
  defp value_string(value), do: Jason.encode!(value)

  defp time(%DateTime{} = time),
    do: time |> DateTime.shift_zone!("Etc/UTC") |> DateTime.to_iso8601()
end
