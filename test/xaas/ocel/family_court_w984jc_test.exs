defmodule Xaas.Ocel.FamilyCourtW984jcTest do
  @moduledoc """
  Lane W984jc unclaimed-family probe on `lib/xaas/ocel/`.

  Census: 11 modules. All are covered by
  `test/xaas/ocel/object_centric_event_projection_test.exs`,
  `test/xaas/ocel/w983e_ocel_log_courts_test.exs`,
  `test/xaas/ocel/ocpm_test.exs`, `test/xaas/ocel_deepening_test.exs`, and
  `test/xaas/changes/family_court_w984ie_test.exs` — except two state-bearing
  branches, courted here:

  1. `Xaas.Ocel.CaseView.derive_for_object/2` with `include_related_objects?: true`
     — the `related_object_ids/1` ObjectObject one-hop walk (both edge
     directions, self-rejection, event dedup) has zero test references anywhere
     in the tree.
  2. `Xaas.Ocel.Projection.import/1`'s shape-refusal head clause
     (`{:error, :malformed_ocel_map}` for a value that is not an
     `{"objects", "events"}` map — existing tests only hit `:malformed` via a
     well-shaped map with invalid values, not the clause head itself).
  """

  use ExUnit.Case, async: true

  alias Xaas.Ocel.{CaseView, Event, Object, ObjectObject, Projection}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp register_object!(type, id) do
    Object
    |> Ash.Changeset.for_create(:register, %{object_type: type, ocel_id: id})
    |> Ash.create!(authorize?: false)
  end

  defp record_event!(type, id, occurred_at, relations) do
    Event
    |> Ash.Changeset.for_create(:record, %{
      event_type: type,
      ocel_id: id,
      occurred_at: occurred_at,
      object_relations: relations
    })
    |> Ash.create!(authorize?: false)
  end

  defp relate!(source, target, qualifier) do
    ObjectObject
    |> Ash.Changeset.for_create(:relate, %{
      source_object_id: source.id,
      target_object_id: target.id,
      qualifier: qualifier
    })
    |> Ash.create!(authorize?: false)
  end

  describe "CaseView.derive_for_object/2 include_related_objects? one-hop walk" do
    test "folds in events of directly related objects in occurred_at order" do
      order = register_object!("Order", "jc-order-1")
      item = register_object!("Item", "jc-item-1")

      relate!(order, item, "contains")

      t0 = DateTime.add(DateTime.utc_now(), -3600)
      t1 = DateTime.add(DateTime.utc_now(), -1800)

      ev_order = record_event!("create", "jc-ev-order-1", t0, [%{object_id: order.id, qualifier: "subject"}])
      ev_item = record_event!("ship", "jc-ev-item-1", t1, [%{object_id: item.id, qualifier: "resource"}])

      assert {:ok, events} = CaseView.derive_for_object(order.id, include_related_objects?: true)

      assert Enum.map(events, & &1.id) == [ev_order.id, ev_item.id]

      # mutation rationale: without the ObjectObject walk (related_object_ids/1),
      # ev_item would be missing and this union assertion fails.
      assert ev_item.id in Enum.map(events, & &1.id)
    end

    test "without the opt-in flag, related-object events stay out" do
      order = register_object!("Order", "jc-order-2")
      item = register_object!("Item", "jc-item-2")

      relate!(order, item, "contains")

      t0 = DateTime.add(DateTime.utc_now(), -600)
      ev_order = record_event!("create", "jc-ev-order-2", t0, [%{object_id: order.id, qualifier: "subject"}])
      _ev_item = record_event!("ship", "jc-ev-item-2", t0, [%{object_id: item.id, qualifier: "resource"}])

      assert {:ok, events} = CaseView.derive_for_object(order.id)
      assert Enum.map(events, & &1.id) == [ev_order.id]
    end

    test "dedups an event related to both root and related object" do
      order = register_object!("Order", "jc-order-3")
      item = register_object!("Item", "jc-item-3")

      relate!(order, item, "contains")

      t0 = DateTime.add(DateTime.utc_now(), -600)

      shared =
        record_event!("inspect", "jc-ev-shared-3", t0, [
          %{object_id: order.id, qualifier: "subject"},
          %{object_id: item.id, qualifier: "resource"}
        ])

      assert {:ok, events} = CaseView.derive_for_object(order.id, include_related_objects?: true)
      assert Enum.map(events, & &1.id) == [shared.id]
    end

    test "walks both edge directions and folds in both sides' events" do
      order = register_object!("Order", "jc-order-4")
      item = register_object!("Item", "jc-item-4")
      other = register_object!("Site", "jc-site-4")

      relate!(item, order, "part_of")
      relate!(order, other, "located_at")

      t0 = DateTime.add(DateTime.utc_now(), -900)
      t1 = DateTime.add(DateTime.utc_now(), -450)

      ev_item = record_event!("load", "jc-ev-item-4", t0, [%{object_id: item.id, qualifier: "part_of"}])
      ev_other = record_event!("dock", "jc-ev-site-4", t1, [%{object_id: other.id, qualifier: "located_at"}])

      assert {:ok, events} = CaseView.derive_for_object(order.id, include_related_objects?: true)

      ids = Enum.map(events, & &1.id)
      assert Enum.sort(ids) == Enum.sort([ev_item.id, ev_other.id])
    end

    test "the transitive general case stays a typed UNSUPPORTED" do
      assert {:error, :unsupported} = CaseView.derive_transitive_case_view(Ash.UUID.generate())
    end
  end

  describe "Projection.import/1 shape-refusal head clause" do
    test "refuses non-OCEL-shaped inputs with :malformed_ocel_map" do
      # mutation rationale: deleting the `import(_other)` clause head makes each
      # of these raise FunctionClauseError instead of returning the typed refusal.
      assert {:error, :malformed_ocel_map} = Projection.import("not a map")
      assert {:error, :malformed_ocel_map} = Projection.import([1, 2, 3])
      assert {:error, :malformed_ocel_map} = Projection.import(%{"events" => []})
      assert {:error, :malformed_ocel_map} = Projection.import(%{"objects" => []})
    end
  end
end
