defmodule Xaas.Ocel.Ocpm do
  @moduledoc """
  Object-centric process mining (OCPM) primitives over an OCEL 2.0
  document map -- the exact shape `Xaas.Ultracode.OcelEgress.build_document/3`
  emits (the four top-level keys `ocel:objectTypes`, `ocel:eventTypes`,
  `ocel:events`, `ocel:objects`; each event carries a `relationships` list
  of `{"objectId", "qualifier"}` maps). Pure: no IO, no clock, no DB.

  Ported from the beam4pm reference (`BeamPM.Pro.OcpmDiscovery`'s
  `object_type_interactions/2` and `object_type_activity_frequency/3`),
  re-based from raw event/object link lists onto the document map: the
  document-level `/1` functions extract the event-to-object links (from
  `ocel:events`' `relationships` -- never the object-to-object
  relationships inside `ocel:objects`), events and objects, then delegate
  to the same semantics as the reference. The `/2` and `/3` kernels are
  exposed too, so callers holding raw links/lists get the reference
  arities directly.

  Two real, bounded primitives:

    * `object_type_interactions/1` -- for each event, which distinct
      object types co-occur (an event referencing both an `Epoch` and a
      `Worker` object is a real cross-object-type interaction, the
      structural signal downstream OCPM algorithms are built from).
      Returns a map from a sorted list of object-type names to the count
      of events exhibiting exactly that combination.
    * `object_type_activity_frequency/1` -- how often each object type
      participates in each activity (event type), counted in DISTINCT
      events, the OCPM analogue of a single-case activity frequency
      table. Returns a map from `{object_type, event_type}` tuples to
      counts (tuples are not JSON-encodable -- `report/1` and
      `mix xaas.ocel.ocpm` project them into entry lists).

  ## Bound (stated honestly, per the no-overclaiming discipline)

  This module does NOT implement object-centric Petri net synthesis,
  divergence-free log transformation, multi-instance DFG construction, or
  convergence detection -- those remain real, named future work (see
  `gaps/0`), not silently omitted. This is interaction/frequency analysis
  only.
  """

  @type document :: map()

  @type ocel_event :: %{required(:event_id) => String.t(), required(:event_type) => String.t()}
  @type ocel_object :: %{required(:object_id) => String.t(), required(:object_type) => String.t()}
  @type event_object_link :: {event_id :: String.t(), object_id :: String.t()}

  @doc """
  Document-level object-type interactions: counts how many events of the
  OCEL 2.0 `document` involve each SET of co-occurring object types.
  Event-to-object links come from each event's `relationships`; a
  relationship whose `objectId` does not resolve to a declared object in
  `ocel:objects` is rejected (never a nil type, never a fabricated
  interaction), and an event left with no resolvable object contributes
  nothing at all (not an empty-set bucket).
  """
  @spec object_type_interactions(document()) :: %{[String.t()] => non_neg_integer()}
  def object_type_interactions(document) when is_map(document) do
    document
    |> doc_links()
    |> object_type_interactions(doc_objects(document))
  end

  @doc """
  Link-list kernel (the beam4pm reference arity): `links` is a list of
  `{event_id, object_id}` pairs, `objects` a list of
  `%{object_id: _, object_type: _}` maps.
  """
  @spec object_type_interactions([event_object_link()], [ocel_object()]) :: %{
          [String.t()] => non_neg_integer()
        }
  def object_type_interactions(links, objects) when is_list(links) and is_list(objects) do
    object_type_by_id = object_type_by_id(objects)

    links
    |> Enum.group_by(fn {event_id, _object_id} -> event_id end)
    |> Enum.map(fn {_event_id, event_links} ->
      event_links
      |> Enum.map(fn {_event_id, object_id} -> Map.get(object_type_by_id, object_id) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()
    end)
    |> Enum.reject(&(&1 == []))
    |> Enum.frequencies()
  end

  @doc """
  Document-level per-object-type activity frequency: for each
  `{object_type, event_type}` pair, how many distinct events of that type
  in the OCEL 2.0 `document` touched at least one object of that type.
  Unresolvable links are rejected exactly as in `object_type_interactions/1`.
  """
  @spec object_type_activity_frequency(document()) :: %{
          {String.t(), String.t()} => non_neg_integer()
        }
  def object_type_activity_frequency(document) when is_map(document) do
    document
    |> doc_links()
    |> object_type_activity_frequency(doc_events(document), doc_objects(document))
  end

  @doc """
  Link-list kernel (the beam4pm reference arity): `links` plus
  `%{event_id: _, event_type: _}` events and `%{object_id: _,
  object_type: _}` objects.
  """
  @spec object_type_activity_frequency([event_object_link()], [ocel_event()], [ocel_object()]) ::
          %{{String.t(), String.t()} => non_neg_integer()}
  def object_type_activity_frequency(links, events, objects)
      when is_list(links) and is_list(events) and is_list(objects) do
    object_type_by_id = object_type_by_id(objects)
    event_type_by_id = Map.new(events, fn %{event_id: id, event_type: t} -> {id, t} end)

    links
    |> Enum.map(fn {event_id, object_id} ->
      {Map.get(object_type_by_id, object_id), Map.get(event_type_by_id, event_id), event_id}
    end)
    |> Enum.reject(fn {ot, et, _} -> is_nil(ot) or is_nil(et) end)
    |> Enum.uniq_by(fn {ot, et, event_id} -> {ot, et, event_id} end)
    |> Enum.map(fn {ot, et, _event_id} -> {ot, et} end)
    |> Enum.frequencies()
  end

  @doc """
  Deterministic, JSON-encodable projection of both primitives over one
  document -- the exact shape `mix xaas.ocel.ocpm` prints. Interactions
  become `{"types" => [...], "count" => n}` entries sorted by their type
  list; frequency tuples become
  `{"object_type" => ot, "event_type" => et, "count" => n}` entries
  sorted by `{object_type, event_type}` (tuple keys cannot survive
  `JSON.encode!/1`).
  """
  @spec report(document()) :: map()
  def report(document) when is_map(document) do
    %{
      "object_type_interactions" =>
        document
        |> object_type_interactions()
        |> Enum.map(fn {types, count} -> %{"types" => types, "count" => count} end)
        |> Enum.sort_by(& &1["types"]),
      "object_type_activity_frequency" =>
        document
        |> object_type_activity_frequency()
        |> Enum.map(fn {{object_type, event_type}, count} ->
          %{"object_type" => object_type, "event_type" => event_type, "count" => count}
        end)
        |> Enum.sort_by(&{&1["object_type"], &1["event_type"]})
    }
  end

  @doc """
  Named, honest list of OCPM capabilities this module deliberately does
  NOT implement -- called out rather than left for a reader to discover
  by absence.
  """
  @spec gaps() :: [atom()]
  def gaps do
    [
      :object_centric_petri_net_synthesis,
      :divergence_free_log_transformation,
      :multi_instance_dfg,
      :convergence_detection
    ]
  end

  # --------------------------------------------------------------------------------
  # Document extraction (event-to-object links ONLY; the relationships
  # inside `ocel:objects` entries are object-to-object facts and are
  # deliberately not links). An event without an id, a relationship
  # without an objectId, an event without a type, or an object without an
  # id/type contributes nothing -- the fallback is nothing, never a
  # fabricated link (the OcelEgress law for unpersisted facts).
  # --------------------------------------------------------------------------------

  defp doc_links(document) do
    document
    |> Map.get("ocel:events", [])
    |> Enum.flat_map(fn event ->
      case Map.get(event, "id") do
        nil ->
          []

        event_id ->
          event
          |> Map.get("relationships", [])
          |> Enum.flat_map(fn relationship ->
            case Map.get(relationship, "objectId") do
              nil -> []
              object_id -> [{event_id, object_id}]
            end
          end)
      end
    end)
  end

  defp doc_events(document) do
    document
    |> Map.get("ocel:events", [])
    |> Enum.flat_map(fn event ->
      case {Map.get(event, "id"), Map.get(event, "type")} do
        {id, type} when is_binary(id) and is_binary(type) ->
          [%{event_id: id, event_type: type}]

        _ ->
          []
      end
    end)
  end

  defp doc_objects(document) do
    document
    |> Map.get("ocel:objects", [])
    |> Enum.flat_map(fn object ->
      case {Map.get(object, "id"), Map.get(object, "type")} do
        {id, type} when is_binary(id) and is_binary(type) ->
          [%{object_id: id, object_type: type}]

        _ ->
          []
      end
    end)
  end

  defp object_type_by_id(objects) do
    Map.new(objects, fn %{object_id: id, object_type: t} -> {id, t} end)
  end
end
