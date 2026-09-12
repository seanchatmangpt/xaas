defmodule Xaas.Ocel.ObjectCentricEventProjectionTest do
  @moduledoc """
  Real Chicago-style tests for docs/jira/v26.9.11/object-centric-event-projection.md.

  Real Ecto.Adapters.SQL.Sandbox-backed Postgres (Xaas.Repo), real
  Ash.create!/Ash.read! calls against the real ocel_objects/ocel_events/
  ocel_event_objects/ocel_object_objects/ocel_object_state_deltas tables.
  No mocks/stubs of any collaborator.
  """
  use ExUnit.Case, async: true

  alias Xaas.Ocel.{
    AshIdentity,
    CaseView,
    Event,
    EventObject,
    Object,
    ObjectObject,
    ObjectStateDelta,
    Projection
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp register_object!(attrs) do
    Object
    |> Ash.Changeset.for_create(:register, attrs)
    |> Ash.create!(authorize?: false)
  end

  defp record_event!(attrs) do
    Event
    |> Ash.Changeset.for_create(:record, attrs)
    |> Ash.create!(authorize?: false)
  end

  describe "the key invariant: event -> {o_1, ..., o_n}" do
    test "an event can relate to multiple typed objects, not a single case id" do
      order = register_object!(%{object_type: "Order", ocel_id: "order-1"})
      item = register_object!(%{object_type: "Item", ocel_id: "item-1"})

      event =
        record_event!(%{
          event_type: "ship",
          ocel_id: "ev-1",
          occurred_at: DateTime.utc_now(),
          object_relations: [
            %{object_id: order.id, qualifier: "subject"},
            %{object_id: item.id, qualifier: "resource"}
          ]
        })

      event_objects =
        EventObject
        |> Ash.Query.filter(event_id == ^event.id)
        |> Ash.read!(authorize?: false)

      related_object_ids = event_objects |> Enum.map(& &1.object_id) |> Enum.sort()

      assert Enum.sort([order.id, item.id]) == related_object_ids
      assert length(event_objects) == 2
    end

    test "an event with zero object relations is refused before any row is written" do
      result =
        Event
        |> Ash.Changeset.for_create(:record, %{
          event_type: "orphan",
          ocel_id: "ev-orphan",
          occurred_at: DateTime.utc_now(),
          object_relations: []
        })
        |> Ash.create(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} = result

      assert [] =
               Event
               |> Ash.Query.filter(ocel_id == "ev-orphan")
               |> Ash.read!(authorize?: false)
    end

    test "an event with an object relation missing an object_id is refused" do
      order = register_object!(%{object_type: "Order", ocel_id: "order-bad"})
      _ = order

      result =
        Event
        |> Ash.Changeset.for_create(:record, %{
          event_type: "bad",
          ocel_id: "ev-bad",
          occurred_at: DateTime.utc_now(),
          object_relations: [%{qualifier: "resource"}]
        })
        |> Ash.create(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} = result
    end

    test "a failed event-object relation write rolls back the whole event (real transactional atomicity)" do
      object = register_object!(%{object_type: "Order", ocel_id: "order-atomic"})

      event =
        record_event!(%{
          event_type: "created",
          ocel_id: "ev-atomic",
          occurred_at: DateTime.utc_now(),
          object_relations: [%{object_id: object.id, qualifier: "subject"}]
        })

      # Re-recording the *same* (event_type, ocel_id) with an object relation
      # that references a real but different object must not silently
      # duplicate the event -- the event_type_ocel_id identity forbids it,
      # and the whole create (including any partial EventObject writes)
      # must roll back together.
      other_object = register_object!(%{object_type: "Order", ocel_id: "order-atomic-2"})

      result =
        Event
        |> Ash.Changeset.for_create(:record, %{
          event_type: "created",
          ocel_id: "ev-atomic",
          occurred_at: DateTime.utc_now(),
          object_relations: [%{object_id: other_object.id, qualifier: "subject"}]
        })
        |> Ash.create(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} = result

      # Original event's relations are untouched by the failed re-attempt.
      event_objects =
        EventObject
        |> Ash.Query.filter(event_id == ^event.id)
        |> Ash.read!(authorize?: false)

      assert [%{object_id: object_id}] = event_objects
      assert object_id == object.id

      # The failed attempt's own EventObject row (if the hook had run before
      # the identity conflict) must not exist orphaned in the table either.
      refute EventObject
             |> Ash.Query.filter(object_id == ^other_object.id)
             |> Ash.read!(authorize?: false)
             |> Enum.any?()
    end
  end

  describe "object-object relations" do
    test "two distinct objects can be related with a qualifier" do
      order = register_object!(%{object_type: "Order", ocel_id: "order-rel-1"})
      item = register_object!(%{object_type: "Item", ocel_id: "item-rel-1"})

      relation =
        ObjectObject
        |> Ash.Changeset.for_create(:relate, %{
          source_object_id: order.id,
          target_object_id: item.id,
          qualifier: "contains"
        })
        |> Ash.create!(authorize?: false)

      assert relation.source_object_id == order.id
      assert relation.target_object_id == item.id
      assert relation.qualifier == "contains"
    end

    test "an object cannot be related to itself" do
      order = register_object!(%{object_type: "Order", ocel_id: "order-self"})

      result =
        ObjectObject
        |> Ash.Changeset.for_create(:relate, %{
          source_object_id: order.id,
          target_object_id: order.id,
          qualifier: "contains"
        })
        |> Ash.create(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} = result
    end
  end

  describe "object state deltas (real, append-only)" do
    test "recording a delta persists a real row without mutating any Object column" do
      object = register_object!(%{object_type: "Device", ocel_id: "device-1"})

      delta =
        ObjectStateDelta
        |> Ash.Changeset.for_create(:record_delta, %{
          object_id: object.id,
          attribute: "status",
          previous_value: "off",
          new_value: "on",
          occurred_at: DateTime.utc_now()
        })
        |> Ash.create!(authorize?: false)

      assert delta.attribute == "status"
      assert delta.previous_value == "off"
      assert delta.new_value == "on"

      # Object itself has no mutable "status" column -- current state is
      # the fold of its deltas, never a persisted column.
      reloaded = Object |> Ash.get!(object.id, authorize?: false)
      refute Map.has_key?(reloaded, :status)
    end
  end

  describe "case-view derivation (never a persisted case record)" do
    test "derives a case view for an object as its ordered related events" do
      order = register_object!(%{object_type: "Order", ocel_id: "order-case-1"})

      t0 = DateTime.utc_now()
      t1 = DateTime.add(t0, 60, :second)

      _created =
        record_event!(%{
          event_type: "created",
          ocel_id: "ev-case-created",
          occurred_at: t0,
          object_relations: [%{object_id: order.id}]
        })

      _shipped =
        record_event!(%{
          event_type: "shipped",
          ocel_id: "ev-case-shipped",
          occurred_at: t1,
          object_relations: [%{object_id: order.id}]
        })

      assert {:ok, [first, second]} = CaseView.derive_for_object(order.id)
      assert first.event_type == "created"
      assert second.event_type == "shipped"
    end

    test "the case view reflects new events on demand -- nothing persisted in between" do
      order = register_object!(%{object_type: "Order", ocel_id: "order-case-2"})

      assert {:ok, []} = CaseView.derive_for_object(order.id)

      record_event!(%{
        event_type: "created",
        ocel_id: "ev-case-2-created",
        occurred_at: DateTime.utc_now(),
        object_relations: [%{object_id: order.id}]
      })

      assert {:ok, [event]} = CaseView.derive_for_object(order.id)
      assert event.event_type == "created"
    end

    test "the unbounded transitive walk is explicitly UNSUPPORTED, not fabricated" do
      assert {:error, :unsupported} = CaseView.derive_transitive_case_view(Ash.UUID.generate())
    end
  end

  describe "Ash-resource identity mapping" do
    test "maps a real Ash resource module + primary key to a deterministic object ref" do
      assert {:ok, %{object_type: "Xaas.Ocel.Object", ocel_id: ocel_id}} =
               AshIdentity.object_ref(Object, "abc-123")

      assert ocel_id == "abc-123"
    end

    test "refuses a module that is not a real Ash resource" do
      assert {:error, :not_an_ash_resource} = AshIdentity.object_ref(Enum, "x")
    end

    test "resolves an object_type string back to the real Ash resource module" do
      assert {:ok, Object} = AshIdentity.resolve_object_type("Xaas.Ocel.Object")
    end

    test "refuses an unresolvable object_type string" do
      assert {:error, :unresolvable} = AshIdentity.resolve_object_type("Not.A.Real.Module")
    end
  end

  describe "OCEL projection and import (real round trip)" do
    test "projecting and re-importing events produces the same real object relations" do
      order = register_object!(%{object_type: "Order", ocel_id: "order-proj-1"})
      item = register_object!(%{object_type: "Item", ocel_id: "item-proj-1"})

      event =
        record_event!(%{
          event_type: "ship",
          ocel_id: "ev-proj-1",
          occurred_at: DateTime.utc_now(),
          attributes: %{"carrier" => "ups"},
          object_relations: [
            %{object_id: order.id, qualifier: "subject"},
            %{object_id: item.id, qualifier: "resource"}
          ]
        })

      assert {:ok, ocel_map} = Projection.project([event.id])
      assert ocel_map["objectTypes"] == ["Item", "Order"]
      assert ocel_map["eventTypes"] == ["ship"]
      assert [projected_event] = ocel_map["events"]
      assert projected_event["id"] == "ev-proj-1"
      assert length(projected_event["relationships"]) == 2

      # Re-import into a fresh set of ocel ids (distinct from the originals,
      # since object_type_ocel_id/event_type_ocel_id are unique identities)
      # by relabeling ids -- proves import/1 is a real, executing code path,
      # not merely inspected.
      relabeled_map =
        ocel_map
        |> Map.put("objects", relabel(ocel_map["objects"], "id", "-import"))
        |> Map.put(
          "events",
          Enum.map(ocel_map["events"], fn ev ->
            ev
            |> Map.put("id", ev["id"] <> "-import")
            |> Map.put(
              "relationships",
              Enum.map(ev["relationships"], fn rel ->
                Map.put(rel, "objectId", rel["objectId"] <> "-import")
              end)
            )
          end)
        )

      assert {:ok, [imported_event]} = Projection.import(relabeled_map)
      assert imported_event.ocel_id == "ev-proj-1-import"

      imported_event_objects =
        EventObject
        |> Ash.Query.filter(event_id == ^imported_event.id)
        |> Ash.Query.load(:object)
        |> Ash.read!(authorize?: false)

      assert length(imported_event_objects) == 2
      assert Enum.all?(imported_event_objects, &String.ends_with?(&1.object.ocel_id, "-import"))
    end

    test "importing an event with zero relationships is refused (invariant preserved through import)" do
      malformed_map = %{
        "objects" => [],
        "events" => [
          %{
            "id" => "ev-malformed",
            "type" => "orphan",
            "time" => DateTime.to_iso8601(DateTime.utc_now()),
            "attributes" => %{},
            "relationships" => []
          }
        ]
      }

      assert {:error, %Ash.Error.Invalid{}} = Projection.import(malformed_map)
    end

    test "importing an arbitrary external OCEL export format is explicitly UNSUPPORTED" do
      assert {:error, :unsupported} = Projection.import_external("<ocel/>", :xml)
    end
  end

  defp relabel(items, key, suffix) do
    Enum.map(items, fn item -> Map.put(item, key, item[key] <> suffix) end)
  end
end
