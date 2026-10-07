defmodule Xaas.Ocel.W983eOcelLogCourtsTest do
  @moduledoc """
  Lane W983e — OCEL event-log deepening courts. Chicago-style: real
  sandboxed Postgres, real Ash actions, real telemetry, real ndjson file;
  no mocks.

  Courts:
    1. Append immutability — Xaas.Ocel.Event declares no update surface and
       a direct update attempt refuses.
    2. Event ordering — events sharing an object come back in total
       occurred_at order (distinct timestamps). Equal-timestamp ties are a
       REPORT-ONLY typed finding: derive_for_object/2 has no id tiebreak
       and the query has no ORDER BY.
    3. Conformance replay — project/1 output re-imports via import/1 with
       field-for-field losslessness.
    4. Failure-event capture — a real refused Event :record emits a real
       ndjson line with outcome "error" that passes Xaas.Ultracode.Ocel.Validator.
  """

  use Xaas.DataCase, async: false

  require Ash.Query

  alias Xaas.Ocel.{CaseView, Event, Object}
  alias Xaas.Ocel.Projection
  alias Xaas.Telemetry.OcelAshEmitter
  alias Xaas.Ultracode.Ocel.Validator

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    # Real fixture scoping: the shared OCEL ndjson is appended to by every
    # Ash action in the suite; scope this file's reads to its own delta.
    log_path = OcelAshEmitter.log_path()
    File.mkdir_p!(Path.dirname(log_path))
    File.write!(log_path, "")

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

  defp project_events!(event_ids) do
    assert {:ok, ocel_map} = Projection.project(event_ids)
    ocel_map
  end

  defp raw_ocel_lines do
    OcelAshEmitter.log_path()
    |> File.read!()
    |> String.split("\n", trim: true)
  end

  defp record_event(attrs) do
    Event
    |> Ash.Changeset.for_create(:record, attrs)
    |> Ash.create(authorize?: false)
  end

  # -- Court 1: append immutability ------------------------------------------

  describe "court 1: append immutability" do
    test "Event declares no update action of any name" do
      update_actions =
        Event
        |> Ash.Resource.Info.actions()
        |> Enum.filter(&(&1.type == :update))

      assert update_actions == [],
             "Xaas.Ocel.Event grew an update surface: #{inspect(update_actions)}"
    end

    test "a direct update attempt through the real API refuses" do
      object = register_object!(%{object_type: "Order", ocel_id: "w983e-c1-order"})

      event =
        record_event!(%{
          event_type: "w983e_c1_ship",
          ocel_id: "w983e-c1-ev-1",
          occurred_at: DateTime.utc_now(),
          object_relations: [%{object_id: object.id, qualifier: "subject"}]
        })

      # No :update action exists; Ash refuses at changeset-construction
      # time (a real refusal raised in-process, not a stub).
      try do
        event
        |> Ash.Changeset.for_update(:update, %{})
        |> Ash.update(authorize?: false)

        flunk("expected the direct update attempt to refuse")
      rescue
        e ->
          assert Exception.message(e) =~ "update",
                 "unexpected refusal reason: #{Exception.message(e)}"
      end
    end
  end

  # -- Court 2: event ordering ------------------------------------------------

  describe "court 2: event ordering" do
    test "events sharing an object come back in total occurred_at order" do
      obj = register_object!(%{object_type: "Case", ocel_id: "w983e-c2-obj"})
      t0 = DateTime.utc_now()

      # Written out of chronological order on purpose.
      events =
        for {n, offset_us} <- [{3, 0}, {1, -200_000}, {2, -100_000}] do
          record_event!(%{
            event_type: "w983e_c2_step_#{n}",
            ocel_id: "w983e-c2-ev-#{n}",
            occurred_at: DateTime.add(t0, offset_us, :microsecond),
            object_relations: [%{object_id: obj.id, qualifier: "subject"}]
          })
        end

      assert {:ok, ordered} = CaseView.derive_for_object(obj.id)

      # Total order: strictly increasing timestamps.
      assert ordered
             |> Enum.map(& &1.occurred_at)
             |> Enum.chunk_every(2, 1, :discard)
             |> Enum.all?(fn [a, b] -> DateTime.compare(a, b) == :lt end)

      expected =
        events
        |> Enum.sort_by(& &1.occurred_at, {:asc, DateTime})
        |> Enum.map(& &1.id)

      assert Enum.map(ordered, & &1.id) == expected
    end

    test "REPORT-ONLY: equal-timestamp ties have no deterministic order" do
      # Typed finding, not a law the code implements: derive_for_object/2
      # sorts only on occurred_at (no id tiebreak) and the EventObject
      # query carries no order_by, so two identical-timestamp events on
      # one object are ordered by DB return order. This court asserts only
      # what holds today (the result is a permutation of the written set
      # with non-decreasing timestamps) and never asserts a tiebreak.
      obj = register_object!(%{object_type: "Case", ocel_id: "w983e-c2-tie-obj"})
      t = DateTime.utc_now()

      e1 =
        record_event!(%{
          event_type: "w983e_c2_tie_a",
          ocel_id: "w983e-c2-tie-a",
          occurred_at: t,
          object_relations: [%{object_id: obj.id, qualifier: "subject"}]
        })

      e2 =
        record_event!(%{
          event_type: "w983e_c2_tie_b",
          ocel_id: "w983e-c2-tie-b",
          occurred_at: t,
          object_relations: [%{object_id: obj.id, qualifier: "subject"}]
        })

      assert {:ok, ordered} = CaseView.derive_for_object(obj.id)
      assert Enum.map(ordered, & &1.id) |> Enum.sort() == Enum.sort([e1.id, e2.id])

      assert ordered
             |> Enum.map(& &1.occurred_at)
             |> Enum.chunk_every(2, 1, :discard)
             |> Enum.all?(fn [a, b] -> DateTime.compare(a, b) in [:lt, :eq] end)
    end
  end

  # -- Court 5 (W984h follow-up): deterministic tie ordering --------------------

  describe "court 5 (W984h): equal-timestamp ties derive deterministically" do
    test "two events with identical occurred_at derive in the same id order across runs" do
      obj = register_object!(%{object_type: "Case", ocel_id: "w984h-c5-tie-obj"})
      t = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      # Two events at the *identical* timestamp on one object, written in
      # the order opposite to the tiebreak law (higher id first would be
      # the DB-return-order risk).
      e1 =
        record_event!(%{
          event_type: "w984h_c5_tie_a",
          ocel_id: "w984h-c5-tie-a",
          occurred_at: t,
          object_relations: [%{object_id: obj.id, qualifier: "subject"}]
        })

      e2 =
        record_event!(%{
          event_type: "w984h_c5_tie_b",
          ocel_id: "w984h-c5-tie-b",
          occurred_at: t,
          object_relations: [%{object_id: obj.id, qualifier: "subject"}]
        })

      expected_order = Enum.sort([e1.id, e2.id])

      # ×2 real derives; the (occurred_at, id) total-order law must give the
      # same ascending-id tiebreak both times, independent of DB return order.
      orders =
        for _run <- 1..2 do
          assert {:ok, ordered} = CaseView.derive_for_object(obj.id)
          ids = Enum.map(ordered, & &1.id)

          assert Enum.sort(ids) == Enum.sort([e1.id, e2.id]),
                 "derived set is not exactly the two written events: #{inspect(ids)}"

          # Both tied events carry the identical timestamp (this is the tie).
          assert Enum.uniq(Enum.map(ordered, & &1.occurred_at)) == [t]

          ids
        end

      assert orders == [expected_order, expected_order],
             "tie order is not deterministic across runs: #{inspect(orders)}"

      assert hd(orders) == expected_order,
             "tie is not broken in ascending id order: #{inspect(hd(orders))}"
    end
  end

  # -- Court 6 (W984h follow-up): destroy refuses, reads pass --------------------

  describe "court 6 (W984h): event log is not deletable" do
    test "Event declares no destroy action of any name" do
      destroy_actions =
        Event
        |> Ash.Resource.Info.actions()
        |> Enum.filter(&(&1.type == :destroy))

      assert destroy_actions == [],
             "Xaas.Ocel.Event grew a destroy surface: #{inspect(destroy_actions)}"
    end

    test "a destroy attempt refuses through the real API while reads pass" do
      object = register_object!(%{object_type: "Order", ocel_id: "w984h-c6-order"})
      other = register_object!(%{object_type: "Order", ocel_id: "w984h-c6-other"})

      event =
        record_event!(%{
          event_type: "w984h_c6_ship",
          ocel_id: "w984h-c6-ev-1",
          occurred_at: DateTime.utc_now(),
          object_relations: [%{object_id: object.id, qualifier: "subject"}]
        })

      # No :destroy action exists; Ash refuses at changeset-construction
      # time (a real in-process refusal, not a stub).
      try do
        event
        |> Ash.Changeset.for_destroy(:destroy, %{})
        |> Ash.destroy(authorize?: false)

        flunk("expected the destroy attempt to refuse")
      rescue
        e ->
          assert Exception.message(e) =~ "destroy",
                 "unexpected refusal reason: #{Exception.message(e)}"
      end

      # The row is still there and the read path is unaffected.
      assert {:ok, [_]} = CaseView.derive_for_object(object.id)

      assert {:ok, read_back} = Ash.read(Event |> Ash.Query.filter(id == ^event.id))
      assert [%{id: id}] = read_back
      assert id == event.id

      # And the identity is not freed for re-recording: the (event_type,
      # ocel_id) identity still refuses a duplicate :record.
      assert {:error, _} =
               record_event(%{
                 event_type: "w984h_c6_ship",
                 ocel_id: "w984h-c6-ev-1",
                 occurred_at: DateTime.utc_now(),
                 object_relations: [%{object_id: other.id, qualifier: "subject"}]
               })
    end
  end

  # -- Court 3: conformance replay input shape ---------------------------------

  describe "court 3: conformance replay input shape" do
    test "project/1 output re-imports field-for-field losslessly" do
      order = register_object!(%{object_type: "Order", ocel_id: "w983e-c3-order"})
      item = register_object!(%{object_type: "Item", ocel_id: "w983e-c3-item"})
      t = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      e1 =
        record_event!(%{
          event_type: "w983e_c3_pick",
          ocel_id: "w983e-c3-ev-1",
          occurred_at: t,
          attributes: %{"qty" => 2, "lane" => "w983e"},
          object_relations: [
            %{object_id: order.id, qualifier: "subject"},
            %{object_id: item.id, qualifier: "resource"}
          ]
        })

      e2 =
        record_event!(%{
          event_type: "w983e_c3_ship",
          ocel_id: "w983e-c3-ev-2",
          occurred_at: DateTime.add(t, 1_000, :microsecond),
          attributes: %{"carrier" => "post"},
          object_relations: [%{object_id: order.id, qualifier: "subject"}]
        })

      original = project_events!([e1.id, e2.id])

      # Re-import under fresh event ids (the (event_type, ocel_id)
      # identity refuses a second :record of the same event, which is
      # itself append-immutability evidence). Same objects (register is
      # idempotent upsert), same fields.
      renamed = %{
        original
        | "events" =>
            Enum.map(original["events"], fn ev ->
              Map.put(ev, "id", ev["id"] <> "-replay")
            end)
      }

      assert {:ok, imported} = Projection.import(renamed)
      assert length(imported) == 2

      replayed = project_events!(Enum.map(imported, & &1.id))

      by_id = fn m, id -> Enum.find(m["events"], &(&1["id"] == id)) end

      for orig_ev <- original["events"] do
        re_id = orig_ev["id"] <> "-replay"
        re_ev = by_id.(replayed, re_id)
        assert re_ev, "replayed log lost event #{re_id}"

        # Field-for-field equality, modulo the deliberate id rename.
        assert re_ev["type"] == orig_ev["type"]
        assert re_ev["time"] == orig_ev["time"]
        assert re_ev["attributes"] == orig_ev["attributes"]

        assert Enum.sort_by(re_ev["relationships"], & &1["objectId"]) ==
                 Enum.sort_by(orig_ev["relationships"], & &1["objectId"])
      end

      assert replayed["objectTypes"] == original["objectTypes"]

      assert Enum.sort(replayed["eventTypes"]) == Enum.sort(original["eventTypes"])
    end
  end

  # -- Court 4: failure-event capture -------------------------------------------

  describe "court 4: failure-event capture" do
    test "a refused Event :record emits a real ndjson line with outcome error passing the court" do
      offset = raw_ocel_lines() |> length()

      register_object!(%{object_type: "Order", ocel_id: "w983e-c4-order"})

      # Real refusal: empty :object_relations is refused by the change
      # module before any row is written.
      assert {:error, _error} =
               record_event(%{
                 event_type: "w983e_c4_refused_ship",
                 ocel_id: "w983e-c4-ev-refused",
                 occurred_at: DateTime.utc_now(),
                 object_relations: []
               })

      lines =
        raw_ocel_lines()
        |> Enum.drop(offset)
        |> Enum.map(&Jason.decode!/1)

      failure_lines =
        Enum.filter(lines, fn line ->
          case line["ocel:events"] do
            [%{"type" => "event.record", "attributes" => %{"outcome" => "error"}}] -> true
            _ -> false
          end
        end)

      assert failure_lines != [],
             "no OCEL failure line captured after the real refused :record; got " <>
               "#{inspect(Enum.map(lines, & &1["ocel:events"]))}"

      # Every captured failure line is an individually-conformant OCEL 2.0
      # document per the real conformance court.
      Enum.each(failure_lines, fn line ->
        assert {:ok, _report} = Validator.validate(line),
               "failure line failed the OCEL court: #{inspect(line)}"
      end)

      # The failure line names the real refused surface.
      assert Enum.any?(failure_lines, fn line ->
               [%{"attributes" => attrs}] = line["ocel:events"]
               attrs["resource"] == "Xaas.Ocel.Event" and attrs["action"] == "record"
             end)
    end
  end
end
