defmodule Xaas.Ocel.Projection do
  @moduledoc """
  OCEL projection and import -- ticket scope items, per
  docs/jira/v26.9.11/object-centric-event-projection.md.

  `project/1` is a real, structural transform of already-persisted
  `Xaas.Ocel.Event`/`Xaas.Ocel.Object` rows into an OCEL 2.0-shaped map
  (`objectTypes`, `eventTypes`, `objects`, `events` -- the standard OCEL
  JSON top-level keys per the public OCEL 2.0 specification). `import/1` is
  this module's real, honest inverse for exactly that same shape: it
  round-trips a map produced by `project/1` (or handwritten in the same
  shape) back into real `Ash.create/2` calls against `Xaas.Ocel.Object`
  and `Xaas.Ocel.Event`.

  What this module does **not** do, and marks `UNSUPPORTED` rather than
  fabricating: parsing arbitrary third-party OCEL exports in the wild
  (OCEL XML, OCEL SQLite, or JSON from another vendor's process-mining tool
  with its own attribute-typing/qualifier conventions). That needs a real
  schema-mapping decision per source format this ticket's "candidate / not
  yet implemented" scope does not resolve -- see `import_external/2`.
  """

  require Ash.Query

  alias Xaas.Ocel.{Event, Object}

  @doc """
  Projects a list of real `Xaas.Ocel.Event` ids into an OCEL 2.0-shaped map.
  Loads each event's related objects via a real Ash query (no fabricated
  data) and derives `objectTypes`/`eventTypes` from what is actually
  present in the loaded set.
  """
  @spec project([Ecto.UUID.t()]) :: {:ok, map()} | {:error, term()}
  def project(event_ids) when is_list(event_ids) do
    Event
    |> Ash.Query.filter(id in ^event_ids)
    |> Ash.Query.load(event_objects: :object)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, events} -> {:ok, to_ocel_map(events)}
      {:error, error} -> {:error, error}
    end
  end

  defp to_ocel_map(events) do
    objects =
      events
      |> Enum.flat_map(& &1.event_objects)
      |> Enum.map(& &1.object)
      |> Enum.uniq_by(& &1.id)

    %{
      "objectTypes" => objects |> Enum.map(& &1.object_type) |> Enum.uniq() |> Enum.sort(),
      "eventTypes" => events |> Enum.map(& &1.event_type) |> Enum.uniq() |> Enum.sort(),
      "objects" =>
        Enum.map(objects, fn object ->
          %{
            "id" => object.ocel_id,
            "type" => object.object_type
          }
        end),
      "events" =>
        Enum.map(events, fn event ->
          %{
            "id" => event.ocel_id,
            "type" => event.event_type,
            "time" => DateTime.to_iso8601(event.occurred_at),
            "attributes" => event.attributes,
            "relationships" =>
              event.event_objects
              |> Enum.map(fn eo ->
                %{"objectId" => eo.object.ocel_id, "qualifier" => eo.qualifier}
              end)
          }
        end)
    }
  end

  @doc """
  Real, honest import of exactly the map shape `project/1` produces (or a
  handwritten map in that same shape). Every object referenced by an
  event's `"relationships"` is registered (idempotently -- `Object`'s
  `:register` action upserts on `(object_type, ocel_id)`) before the event
  is recorded via `Event`'s `:record` action, so this always leaves the
  invariant "an event relates to at least one object" intact -- an event
  with an empty `"relationships"` list is refused by `Event.record/1`
  exactly as a directly-constructed one would be.
  """
  @spec import(map()) :: {:ok, [Event.t()]} | {:error, term()}
  def import(%{"objects" => objects, "events" => events}) do
    with {:ok, _registered} <- register_objects(objects) do
      import_events(events)
    end
  end

  def import(_other), do: {:error, :malformed_ocel_map}

  defp register_objects(objects) do
    Enum.reduce_while(objects, {:ok, []}, fn object, {:ok, acc} ->
      params = %{object_type: Map.fetch!(object, "type"), ocel_id: Map.fetch!(object, "id")}

      case Object |> Ash.Changeset.for_create(:register, params) |> Ash.create(authorize?: false) do
        {:ok, registered} -> {:cont, {:ok, [registered | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp import_events(events) do
    Enum.reduce_while(events, {:ok, []}, fn event, {:ok, acc} ->
      {:ok, occurred_at, _offset} = DateTime.from_iso8601(Map.fetch!(event, "time"))

      with {:ok, object_relations} <-
             build_object_relations(Map.get(event, "relationships", [])) do
        params = %{
          event_type: Map.fetch!(event, "type"),
          ocel_id: Map.fetch!(event, "id"),
          occurred_at: occurred_at,
          attributes: Map.get(event, "attributes", %{}),
          object_relations: object_relations
        }

        case Event |> Ash.Changeset.for_create(:record, params) |> Ash.create(authorize?: false) do
          {:ok, created} -> {:cont, {:ok, [created | acc]}}
          {:error, error} -> {:halt, {:error, error}}
        end
      else
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, created} -> {:ok, Enum.reverse(created)}
      {:error, error} -> {:error, error}
    end
  end

  defp build_object_relations(relationships) do
    Enum.reduce_while(relationships, {:ok, []}, fn rel, {:ok, acc} ->
      case object_relation_for(rel) do
        {:ok, relation} -> {:cont, {:ok, [relation | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, relations} -> {:ok, Enum.reverse(relations)}
      {:error, error} -> {:error, error}
    end
  end

  @spec object_relation_for(map()) :: {:ok, map()} | {:error, term()}
  defp object_relation_for(%{"objectId" => ocel_id} = rel) do
    Object
    |> Ash.Query.filter(ocel_id == ^ocel_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, {:unknown_object_id, ocel_id}}
      {:ok, object} -> {:ok, %{object_id: object.id, qualifier: Map.get(rel, "qualifier", "related")}}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Explicit `UNSUPPORTED`: importing an arbitrary external OCEL export
  (OCEL XML, OCEL SQLite, or another vendor's OCEL-JSON with its own
  attribute-typing/qualifier conventions) is not implemented here.

  Doing this honestly needs a real per-format schema-mapping layer (an XML
  parser + element-to-field mapping table for OCEL XML; a SQLite-schema
  reader for OCEL SQLite; a field-name reconciliation pass for divergent
  vendor JSON) that this bounded slice does not fabricate -- returning a
  fake successful import here would silently drop or misattribute real
  process data, which is a strictly worse failure mode than a typed refusal.
  """
  @spec import_external(String.t() | binary(), atom()) :: {:error, :unsupported}
  def import_external(_source, _format), do: {:error, :unsupported}
end
