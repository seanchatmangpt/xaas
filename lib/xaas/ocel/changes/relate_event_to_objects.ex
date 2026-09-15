defmodule Xaas.Ocel.Changes.RelateEventToObjects do
  @moduledoc """
  The real admission path enforcing this ticket's key invariant --
  docs/jira/v26.9.11/object-centric-event-projection.md: "An event relates
  to a set of objects, not a single case: `event -> {o_1, ..., o_n}`".

  This is deliberately structural, not a fabricated causal-discovery or
  planning step: the `:object_relations` argument is required and validated
  non-empty *before* the event row is even written (`{:error, ...}` here
  aborts the whole `Ash.create/2` call, per real Ash `Ash.Changeset.Change`
  semantics), and each accepted `%{object_id: ..., qualifier: ...}` entry
  becomes one `Xaas.Ocel.EventObject` row created inside the same DB
  transaction via `after_action/2` -- same in-transaction-write convention
  as `Xaas.Library.Changes.IncrementBookInventory`
  (`lib/xaas/library/changes/increment_book_inventory.ex`): a real
  `EventObject` creation failure here returns `{:error, error}` from the
  hook, which rolls back the whole action, so an event can never end up
  persisted with zero real object relations.
  """

  use Ash.Resource.Change

  alias Xaas.Ocel.EventObject

  @impl true
  def change(changeset, _opts, _context) do
    object_relations = Ash.Changeset.get_argument(changeset, :object_relations) || []

    cond do
      object_relations == [] ->
        Ash.Changeset.add_error(changeset,
          field: :object_relations,
          message:
            "an event must relate to at least one object (ticket invariant: " <>
              "event -> {o_1, ..., o_n}, never a single artificial case id)"
        )

      not Enum.all?(object_relations, &valid_relation?/1) ->
        Ash.Changeset.add_error(changeset,
          field: :object_relations,
          message: "each object relation must be a map with a non-nil :object_id"
        )

      true ->
        Ash.Changeset.after_action(changeset, fn _changeset, event ->
          create_relations(event, object_relations)
        end)
    end
  end

  defp valid_relation?(%{object_id: object_id}) when not is_nil(object_id), do: true
  defp valid_relation?(%{"object_id" => object_id}) when not is_nil(object_id), do: true
  defp valid_relation?(_), do: false

  defp create_relations(event, object_relations) do
    Enum.reduce_while(object_relations, {:ok, event}, fn relation, {:ok, event} ->
      object_id = Map.get(relation, :object_id) || Map.get(relation, "object_id")
      qualifier = Map.get(relation, :qualifier) || Map.get(relation, "qualifier") || "related"

      params = %{event_id: event.id, object_id: object_id, qualifier: qualifier}

      case EventObject |> Ash.Changeset.for_create(:relate, params) |> Ash.create(authorize?: false) do
        {:ok, _event_object} -> {:cont, {:ok, event}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end
end
