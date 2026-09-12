defmodule Xaas.Ocel.CaseView do
  @moduledoc """
  Case-view derivation -- ticket key invariant, per
  docs/jira/v26.9.11/object-centric-event-projection.md: "Case views are
  derived, not stored: `case_view = projection(events, objects)`, never a
  canonical persisted case record."

  `derive_for_object/2` is that projection function: given a root object id,
  it queries real `Xaas.Ocel.EventObject` rows for that object (a real Ash
  read, not a fabricated result) and returns the object's events ordered by
  `occurred_at` -- the "case", reconstructed on demand, with nothing
  persisted anywhere that a caller could mistake for a canonical case
  record. Calling this function twice for the same object after new events
  are recorded returns a different (correct, up to date) result, which is
  the falsifier this invariant names: if this ever needed a stored case row
  to stay correct, the invariant would be violated.
  """

  require Ash.Query

  alias Xaas.Ocel.{Event, EventObject}

  @doc """
  Derives the case view for one root object: every event related to it,
  ordered by `occurred_at` ascending. Set `include_related_objects?: true`
  (opt-in) to also walk one hop of `Xaas.Ocel.ObjectObject` and fold in
  events for directly related objects too -- the multi-hop, transitive-graph
  general case is explicit `UNSUPPORTED` (see below), since an unbounded
  object-relation walk needs real cycle handling this bounded slice does not
  attempt to fabricate.
  """
  @spec derive_for_object(Ecto.UUID.t(), keyword()) :: {:ok, [Event.t()]} | {:error, term()}
  def derive_for_object(object_id, opts \\ []) do
    object_ids =
      if opts[:include_related_objects?] do
        [object_id | related_object_ids(object_id)]
      else
        [object_id]
      end

    EventObject
    |> Ash.Query.filter(object_id in ^object_ids)
    |> Ash.Query.load(:event)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, event_objects} ->
        events =
          event_objects
          |> Enum.map(& &1.event)
          |> Enum.uniq_by(& &1.id)
          |> Enum.sort_by(& &1.occurred_at, DateTime)

        {:ok, events}

      {:error, error} ->
        {:error, error}
    end
  end

  defp related_object_ids(object_id) do
    Xaas.Ocel.ObjectObject
    |> Ash.Query.filter(source_object_id == ^object_id or target_object_id == ^object_id)
    |> Ash.read!(authorize?: false)
    |> Enum.flat_map(fn rel -> [rel.source_object_id, rel.target_object_id] end)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == object_id))
  end

  @doc """
  Explicit `UNSUPPORTED`: deriving the case view via unbounded transitive
  traversal of the object-object relation graph (arbitrary depth, real
  cycle detection, and a defensible notion of which relation qualifiers
  should even propagate case membership) is exactly the kind of
  architecturally-ambitious follow-on this ticket's own "candidate / not
  yet implemented" status anticipates. `derive_for_object/2`'s
  `include_related_objects?` option covers the single-hop case honestly;
  going further needs a real graph-traversal design decision (BFS with a
  visited-set and a depth/qualifier policy) this slice does not fabricate.
  """
  @spec derive_transitive_case_view(Ecto.UUID.t()) :: {:error, :unsupported}
  def derive_transitive_case_view(_object_id), do: {:error, :unsupported}
end
