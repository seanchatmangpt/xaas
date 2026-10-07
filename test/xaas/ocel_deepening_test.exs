defmodule Xaas.Ocel.DeepeningTest do
  @moduledoc """
  Lane W721 deepening tests for the Xaas.Ocel domain
  (docs/jira/v26.9.11/object-centric-event-projection.md surfaces).

  Chicago-style: real Ecto.Adapters.SQL.Sandbox-backed Postgres, real Ash
  actions against the real ocel_* tables, assertions on real row state.
  No mocks, no stubs.

  The append-only fold law (object state = fold of ObjectStateDelta rows in
  occurred_at order) is shipped as `Xaas.Ocel.fold_object_state/2`; the fold
  assertions target the real module. One dual assertion against a test-local
  reference implementation is retained during the W758 transition lane to
  pin the module's semantics to the originally documented convention.
  NOT tagged :eu_ai_act: nothing in this file
  touches the EU-AI-Act admission surface; an Art 12 record-keeping docket
  would need its own in-file justification, which this domain does not
  supply.
  """
  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Ocel.{
    Event,
    EventObject,
    Object,
    ObjectObject,
    ObjectStateDelta
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

  defp record_delta!(attrs) do
    ObjectStateDelta
    |> Ash.Changeset.for_create(:record_delta, attrs)
    |> Ash.create!(authorize?: false)
  end

  defp relate_objects!(attrs) do
    ObjectObject
    |> Ash.Changeset.for_create(:relate, attrs)
    |> Ash.create!(authorize?: false)
  end

  defp read_event_objects!(event_id) do
    EventObject
    |> Ash.Query.filter(event_id == ^event_id)
    |> Ash.read!(authorize?: false)
  end

  defp read_deltas!(object_id) do
    ObjectStateDelta
    |> Ash.Query.filter(object_id == ^object_id)
    |> Ash.read!(authorize?: false)
  end

  # W758 transition dual: reference implementation of the documented fold
  # convention, kept so the shipped `Xaas.Ocel.fold_object_state/2` stays
  # pinned to the originally asserted semantics. See moduledoc.
  defp fold_deltas(deltas) do
    deltas
    |> Enum.sort_by(& &1.occurred_at, DateTime)
    |> Enum.reduce(%{}, fn delta, state ->
      Map.put(state, delta.attribute, delta.new_value)
    end)
  end

  describe "event -> multi-object correlation (set semantics)" do
    test "one event correlates multiple typed objects; read-back is the written set" do
      order = register_object!(%{object_type: "Order", ocel_id: "w721-order-1"})
      item = register_object!(%{object_type: "Item", ocel_id: "w721-item-1"})
      carrier = register_object!(%{object_type: "Carrier", ocel_id: "w721-carrier-1"})

      event =
        record_event!(%{
          event_type: "w721_ship",
          ocel_id: "w721-ev-1",
          occurred_at: DateTime.utc_now(),
          object_relations: [
            %{object_id: order.id, qualifier: "subject"},
            %{object_id: item.id, qualifier: "resource"},
            %{object_id: carrier.id, qualifier: "resource"}
          ]
        })

      rows = read_event_objects!(event.id)

      assert length(rows) == 3

      assert rows
             |> MapSet.new(&{&1.event_id, &1.object_id, &1.qualifier})
             |> Enum.sort() ==
               [
                 {event.id, order.id, "subject"},
                 {event.id, item.id, "resource"},
                 {event.id, carrier.id, "resource"}
               ]
               |> Enum.sort()
    end

    test "two events sharing an object each hold exactly one join row for it" do
      obj = register_object!(%{object_type: "Site", ocel_id: "w721-site-1"})

      e1 =
        record_event!(%{
          event_type: "w721_inspect",
          ocel_id: "w721-ev-2a",
          occurred_at: DateTime.utc_now(),
          object_relations: [%{object_id: obj.id, qualifier: "subject"}]
        })

      e2 =
        record_event!(%{
          event_type: "w721_inspect",
          ocel_id: "w721-ev-2b",
          occurred_at: DateTime.utc_now(),
          object_relations: [%{object_id: obj.id, qualifier: "subject"}]
        })

      assert length(read_event_objects!(e1.id)) == 1
      assert length(read_event_objects!(e2.id)) == 1
    end

    test "an event with zero object relations is refused before any row is written" do
      assert_raise Ash.Error.Invalid, fn ->
        record_event!(%{
          event_type: "w721_orphan",
          ocel_id: "w721-ev-orphan",
          occurred_at: DateTime.utc_now(),
          object_relations: []
        })
      end

      assert Event
             |> Ash.Query.filter(ocel_id == "w721-ev-orphan")
             |> Ash.read!(authorize?: false) == []
    end
  end

  describe "append-only fold law (ObjectStateDelta)" do
    test "object state is the fold of its deltas in occurred_at order" do
      obj = register_object!(%{object_type: "Order", ocel_id: "w721-fold-obj"})

      t0 = DateTime.utc_now() |> DateTime.truncate(:second)

      record_delta!(%{
        object_id: obj.id,
        attribute: "status",
        previous_value: nil,
        new_value: "created",
        occurred_at: t0
      })

      record_delta!(%{
        object_id: obj.id,
        attribute: "status",
        previous_value: "created",
        new_value: "paid",
        occurred_at: DateTime.add(t0, 10, :second)
      })

      record_delta!(%{
        object_id: obj.id,
        attribute: "status",
        previous_value: "paid",
        new_value: "shipped",
        occurred_at: DateTime.add(t0, 20, :second)
      })

      deltas = read_deltas!(obj.id)

      assert length(deltas) == 3
      # No separately-mutated state column exists anywhere in the model:
      # the only state surface is the fold of these rows.
      assert Xaas.Ocel.fold_object_state(deltas) == %{"status" => "shipped"}
      # W758 transition dual: real module pinned to the reference semantics.
      assert Xaas.Ocel.fold_object_state(deltas) == fold_deltas(deltas)
    end

    test "the fold is order-deterministic: same delta sequence yields identical state regardless of insertion order" do
      t0 = DateTime.utc_now() |> DateTime.truncate(:second)

      deltas_spec = [
        {"amount", nil, "100", 0},
        {"amount", "100", "250", 5},
        {"amount", "250", "999", 10},
        {"status", nil, "created", 2},
        {"status", "created", "shipped", 7}
      ]

      obj_a = register_object!(%{object_type: "Order", ocel_id: "w721-det-obj-a"})

      for {attr, prev, new, offset} <- deltas_spec do
        record_delta!(%{
          object_id: obj_a.id,
          attribute: attr,
          previous_value: prev,
          new_value: new,
          occurred_at: DateTime.add(t0, offset, :second)
        })
      end

      obj_b = register_object!(%{object_type: "Order", ocel_id: "w721-det-obj-b"})

      # Same delta sequence, rows inserted in reverse wall-clock order.
      for {attr, prev, new, offset} <- Enum.reverse(deltas_spec) do
        record_delta!(%{
          object_id: obj_b.id,
          attribute: attr,
          previous_value: prev,
          new_value: new,
          occurred_at: DateTime.add(t0, offset, :second)
        })
      end

      folded_a = obj_a.id |> read_deltas!() |> Xaas.Ocel.fold_object_state()
      folded_b = obj_b.id |> read_deltas!() |> Xaas.Ocel.fold_object_state()

      assert folded_a == folded_b
      assert folded_a == %{"amount" => "999", "status" => "shipped"}
    end

    test "a recorded delta cannot be mutated: no :update action exists, the row is unchanged" do
      obj = register_object!(%{object_type: "Order", ocel_id: "w721-immutable-obj"})

      delta =
        record_delta!(%{
          object_id: obj.id,
          attribute: "status",
          previous_value: nil,
          new_value: "created",
          occurred_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      # Append-only by contract: the resource declares no :update action,
      # so there is no admitted mutation path at the action layer itself.
      # The behavioral gate below is the real assertion: nothing changed.
      refute Enum.any?(Ash.Resource.Info.actions(ObjectStateDelta), &(&1.type == :update))

      # Ash raises (no such action) rather than offering an update path.
      attempt =
        try do
          delta
          |> Ash.Changeset.for_update(:update, %{new_value: "tampered"})
          |> Ash.update!(authorize?: false)

          :updated
        rescue
          _ -> :refused
        end

      assert attempt == :refused

      stored =
        ObjectStateDelta
        |> Ash.Query.filter(id == ^delta.id)
        |> Ash.read_one!(authorize?: false)

      assert stored.new_value == "created"
      assert stored.attribute == "status"
    end
  end

  describe "object-object relation graph" do
    test "relations form a graph; closing a cycle is allowed (no DAG enforcement)" do
      a = register_object!(%{object_type: "Site", ocel_id: "w721-g-a"})
      b = register_object!(%{object_type: "Site", ocel_id: "w721-g-b"})
      c = register_object!(%{object_type: "Site", ocel_id: "w721-g-c"})

      relate_objects!(%{source_object_id: a.id, target_object_id: b.id, qualifier: "feeds"})
      relate_objects!(%{source_object_id: b.id, target_object_id: c.id, qualifier: "feeds"})
      # Cycle: c -> a closes the loop; the real contract has no DAG check.
      relate_objects!(%{source_object_id: c.id, target_object_id: a.id, qualifier: "feeds"})

      edges =
        ObjectObject
        |> Ash.read!(authorize?: false)
        |> MapSet.new(&{&1.source_object_id, &1.target_object_id, &1.qualifier})

      assert MapSet.size(edges) == 3
      assert MapSet.member?(edges, {c.id, a.id, "feeds"})
    end

    test "self-relation is refused by the NotSelfReferential validation" do
      a = register_object!(%{object_type: "Site", ocel_id: "w721-self-a"})

      assert_raise Ash.Error.Invalid, fn ->
        relate_objects!(%{
          source_object_id: a.id,
          target_object_id: a.id,
          qualifier: "feeds"
        })
      end

      # No row was written by the refused attempt.
      assert ObjectObject
             |> Ash.read!(authorize?: false) == []
    end
  end
end
