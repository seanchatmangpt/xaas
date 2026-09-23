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

  @doc "The distinct event classes present in `events`, in lifecycle order."
  @spec reached([event()]) :: [String.t()]
  def reached(events) do
    present = MapSet.new(events, & &1.type)
    Enum.filter(@event_classes, &MapSet.member?(present, &1))
  end

  @doc "The court-vocabulary rendering (`mix xaas.ocel_validate`)."
  @spec court_form({[event()], objects()}) :: map()
  def court_form({events, objects}) do
    %{
      "ocel:objectTypes" => @object_types,
      "ocel:eventTypes" => @event_classes,
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

  @doc "The OCEL 2.0 standard JSON rendering (`pm4py.read_ocel2_json/1`)."
  @spec standard_form({[event()], objects()}) :: map()
  def standard_form({events, objects}) do
    %{
      "objectTypes" =>
        Enum.map(@object_types, fn type ->
          %{"name" => type, "attributes" => declared(objects |> Map.values(), type)}
        end),
      "eventTypes" =>
        Enum.map(@event_classes, fn type ->
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
