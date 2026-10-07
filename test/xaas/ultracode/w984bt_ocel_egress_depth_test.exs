defmodule Xaas.Ultracode.W984btOcelEgressDepthTest do
  @moduledoc """
  Lane W984bt — one 5-test depth court on the OCEL telemetry-egress surface
  (`Xaas.Telemetry.OcelAshEmitter` + `Xaas.Telemetry.OcelNdjson` +
  `Xaas.Ultracode.Ocel.Validator` over the real
  `priv/ocel/ash-actions.ndjson` line protocol), MINUS already-covered
  slices: W983e courts 4/6 (refusal capture, destroy floor), the existing
  emitter courts (outcome discrimination, per-field laws, unknown fallback,
  unencodable-payload `:ok` return), the rotation courts, and
  `ocel_egress_deepening` (aggregate-across-rotation, malformed fail-closed,
  legacy-shape refusal, disk bound).

  The five UNCOVERED invariants, each with its mutation rationale:

    1. **Batch N/0 line-format contract** — emitting N events through the
       REAL `handle_event/4` lands exactly N new lines; every line is
       individually `{:ok, _}` under the court, and the WHOLE batch
       assembles through the real `OcelNdjson` bridge into one aggregate
       the court accepts with `event_count == N`. Mutations killed: a
       per-line shape regression (extra key, undeclared type, dangling
       relationship, non-UTC time) flips a per-line verdict; an
       assembly-law regression (dropping declarations, double-counting
       deduped objects) flips the aggregate verdict/counts.
    2. **Time/monotonic law** — every emitted event `"time"` parses
       `{:ok, _, 0}` (ISO8601, ZERO offset), event times are
       non-decreasing in append order, strictly increasing across a real
       clock advance, and event ids are unique per emission. Mutations
       killed: a local-time (non-zero-offset) or naive time source fails
       the parse law; a per-test frozen time fails the strictly-increasing
       probe; id reuse fails uniqueness.
    3. **Nil-drop payload-minimality law** — one emission whose every
       nullable enrichment (actor, tenant, `authorize?`, duration,
       description, attribute count) is nil produces a line whose raw
       bytes contain NO null and whose attributes carry exactly the
       minimal fact set (domain/resource/action/outcome). Mutations
       killed: reintroducing `"key": null` entries (lost `drop_nils`)
       or a fabricated default fact fails the exact-attribute assertion.
    4. **Concurrent emission interleaving** — 12 processes x 3 emissions
       append concurrently; the file delta is exactly 36 lines, every one
       JSON-decodable (no torn/interleaved bytes), every one
       court-conformant, the aggregate valid with `event_count == 36`,
       and every observed event type belongs to the emitted multiset.
       Mutation killed: a non-atomic append or shared-handle corruption
       produces an undecodable line and the count/decode assertions fail.
    5. **Egress failure isolation across a batch** — an unencodable
       emission in the middle of a batch (1) returns `:ok` (never raises
       into the traced action), (2) fabricates NO line, and (3) leaves
       the egress consistent for the AFTER emissions: exactly the 2 valid
       lines, no torn bytes, aggregate court-valid. Mutation killed: a
       regression that lets the append `rescue` leak, writes a partial
       line, or mis-orders subsequent appends fails the exact line
       content/aggregate assertions.
  """

  use ExUnit.Case, async: false

  @moduletag :ultracode

  alias Xaas.Telemetry.OcelAshEmitter
  alias Xaas.Telemetry.OcelNdjson
  alias Xaas.Ultracode.Ocel.Validator

  @book_meta %{
    resource: Xaas.Library.Book,
    domain: Xaas.Library,
    resource_short_name: "book"
  }

  setup do
    # Real fixture scoping, same discipline as the existing emitter courts:
    # the shared egress file is appended to by every Ash action in the
    # suite, so scope this file's reads to its own delta after a truncate.
    log_path = OcelAshEmitter.log_path()
    File.mkdir_p!(Path.dirname(log_path))
    File.write!(log_path, "")

    :ok
  end

  defp raw_lines do
    OcelAshEmitter.log_path()
    |> File.read!()
    |> String.split("\n", trim: true)
  end

  defp emit!(action, measurements, extra_meta) do
    :ok =
      OcelAshEmitter.handle_event(
        [:ash, :library, :create, :stop],
        measurements,
        Map.merge(%{action: action}, extra_meta),
        nil
      )
  end

  defp event_of(line_doc), do: hd(line_doc["ocel:events"])

  defp decode_line!(raw), do: Jason.decode!(raw)

  # -- 1. batch N/0 line-format contract -------------------------------------

  test "1. batch of 8 emissions: exactly 8 lines, each court-valid, aggregate court-valid at N/0" do
    actor_free = Map.take(@book_meta, [:resource, :domain, :resource_short_name])

    emissions = [
      {:create, %{duration: 1_000_000}, Map.put(actor_free, :tenant, "org-bt-1")},
      {:create, %{duration: 2_000_000}, actor_free},
      {:read, %{duration: 3_000_000}, actor_free},
      {:update, %{duration: 4_000_000}, Map.put(actor_free, :authorize?, true)},
      {:destroy, %{duration: 5_000_000}, actor_free},
      {:checkout, %{duration: 6_000_000}, actor_free},
      {:index, %{duration: 7_000_000}, actor_free},
      {:read, %{}, actor_free}
    ]

    for {action, measurements, meta} <- emissions, do: emit!(action, measurements, meta)

    lines = raw_lines()

    assert length(lines) == 8,
           "expected exactly 8 lines for 8 emissions, got #{length(lines)}"

    decoded = Enum.map(lines, &decode_line!/1)

    # Per line: the real court accepts each one-event log, N/0.
    verdicts = Enum.map(decoded, &Validator.validate/1)

    Enum.each(Enum.with_index(verdicts, 1), fn {verdict, i} ->
      assert {:ok, report} = verdict,
             "line #{i} failed the court: #{inspect(verdict)}"

      assert report["event_count"] == 1
      assert report["status"] == "valid"
    end)

    # Aggregate: the real assembly bridge + court over the whole batch.
    assert {:ok, report} = OcelNdjson.validate_ndjson_file(OcelAshEmitter.log_path())
    assert report["status"] == "valid"
    assert report["event_count"] == 8

    # Assembly deduplicates the repeated class-level objects: 8 lines each
    # re-stating {"book", "tenant:org-bt-1"} aggregate to exactly TWO
    # objects (one emission carries a tenant; the other seven do not).
    assert report["object_count"] == 2

    # Every emitted event type is declared in the aggregate (union law).
    declared = MapSet.new(report["event_types"])
    assert MapSet.subset?(
             MapSet.new(~w(book.create book.read book.update book.destroy book.checkout book.index)),
             declared
           )
  end

  # -- 2. time/monotonic law ---------------------------------------------------

  test "2. event times are ISO8601 UTC-zero, non-decreasing, strictly increasing across a clock advance; ids unique" do
    emit!(:read, %{duration: 1_000}, @book_meta)
    emit!(:read, %{duration: 2_000}, @book_meta)

    # Real clock advance so the third emission's timestamp is strictly
    # greater -- the probe that kills a frozen/per-test-constant time.
    Process.sleep(2)
    emit!(:read, %{duration: 3_000}, @book_meta)

    assert [line1, line2, line3] = Enum.map(raw_lines(), &decode_line!/1)

    times =
      Enum.map([line1, line2, line3], fn line ->
        event = event_of(line)
        assert {:ok, dt, 0} = DateTime.from_iso8601(event["time"]),
               "event time #{inspect(event["time"])} must be ISO8601 with ZERO UTC offset"

        dt
      end)

    # Append order == chronological order for this sink (non-decreasing).
    assert [t1, t2, t3] = times
    assert DateTime.compare(t1, t2) in [:lt, :eq]
    assert DateTime.compare(t2, t3) == :lt

    # Ids: unique per emission (UUIDv7 source), non-empty strings.
    ids = Enum.map([line1, line2, line3], &(event_of(&1)["id"]))
    assert length(Enum.uniq(ids)) == 3
    assert Enum.all?(ids, &(is_binary(&1) and &1 != ""))

    # duration_ms: exact native->millisecond conversion, including 0.
    assert event_of(line1)["attributes"]["duration_ms"] ==
             System.convert_time_unit(1_000, :native, :millisecond)

    assert event_of(line3)["attributes"]["duration_ms"] ==
             System.convert_time_unit(3_000, :native, :millisecond)
  end

  # -- 3. nil-drop payload minimality -----------------------------------------

  test "3. an all-nullable emission drops every null: raw bytes carry no null and attributes are exactly the minimal fact set" do
    # No actor, no tenant, no authorize?, and a measurements map with no
    # :duration key -- every nullable enrichment nil.
    emit!(:read, %{}, @book_meta)

    assert [raw] = raw_lines()
    decoded = Jason.decode!(raw)

    refute String.contains?(raw, "null"),
           "raw line must contain no null bytes: #{inspect(raw)}"

    # Exactly the minimal fact set: the real introspected
    # public_attribute_count survives (it is a non-nil real fact for a
    # real resource); every TRULY nullable enrichment (authorize?,
    # duration_ms, resource_description, actor, tenant) is absent.
    event = event_of(decoded)

    expected_attribute_count =
      Xaas.Library.Book |> Ash.Resource.Info.public_attributes() |> length()

    assert event["attributes"] == %{
             "domain" => "Xaas.Library",
             "resource" => "Xaas.Library.Book",
             "action" => "read",
             "outcome" => "ok",
             "public_attribute_count" => expected_attribute_count
           }

    # Only the resource object + its one relationship (no fabricated
    # actor/tenant ids).
    assert decoded["ocel:objects"] == [
             %{"id" => "book", "type" => "book", "attributes" => %{}, "relationships" => []}
           ]

    assert event_of(decoded)["relationships"] == [
             %{"objectId" => "book", "qualifier" => "book"}
           ]

    assert {:ok, _} = Validator.validate(decoded)
  end

  # -- 4. concurrent emission interleaving ------------------------------------

  test "4. 12x3 concurrent emissions interleave into 36 whole, court-valid lines" do
    actions = Enum.map(1..12, &String.to_atom("w984bt_action_#{&1}"))

    tasks =
      Task.async_stream(actions, fn action ->
        for ms <- 1..3 do
          :ok = OcelAshEmitter.handle_event([:ash, :library, :create, :stop], %{duration: ms},
                   Map.merge(@book_meta, %{action: action}),
                   nil
                 )
        end
      end)

    Stream.run(tasks)

    lines = raw_lines()

    assert length(lines) == 36,
           "expected exactly 36 whole lines for 36 concurrent emissions, got #{length(lines)}"

    decoded =
      Enum.map(lines, fn raw ->
        assert {:ok, doc} = Jason.decode(raw),
               "concurrent appends must never tear a line: #{inspect(raw)}"

        doc
      end)

    # Every line individually conformant.
    Enum.each(decoded, fn doc ->
      assert {:ok, %{ "event_count" => 1, "status" => "valid"}} = Validator.validate(doc)
    end)

    # Aggregate valid at exactly 36 events; object dedup collapses the
    # 36 repeated "book" objects to one.
    assert {:ok, report} = OcelNdjson.validate_ndjson_file(OcelAshEmitter.log_path())
    assert report["status"] == "valid"
    assert report["event_count"] == 36
    assert report["object_count"] == 1

    # Every observed event type belongs to the emitted multiset.
    observed_types = decoded |> Enum.map(&event_of(&1)["type"]) |> Enum.uniq() |> Enum.sort()

    assert observed_types ==
             Enum.map(actions, &"book.#{&1}") |> Enum.sort()
  end

  # -- 5. egress failure isolation across a batch -----------------------------

  test "5. an unencodable emission mid-batch returns :ok, fabricates no line, and leaves the egress consistent for after-emissions" do
    emit!(:create, %{duration: 1_000_000}, @book_meta)

    # Middle emission: a pid in a raw attribute value is unencodable by
    # Jason -- the append rescue discloses via Logger, returns :ok, and
    # writes no line.
    assert :ok =
             OcelAshEmitter.handle_event(
               [:ash, :library, :create, :stop],
               %{duration: 2_000_000},
               Map.put(@book_meta, :action, :update) |> Map.put(:authorize?, self()),
               nil
             )

    emit!(:destroy, %{duration: 3_000_000}, @book_meta)

    lines = raw_lines()

    assert length(lines) == 2,
           "the failed emission must fabricate no line and leave no torn bytes, got: #{inspect(lines)}"

    decoded = Enum.map(lines, &Jason.decode!/1)

    assert [event_of(decoded |> hd())["type"], event_of(List.last(decoded))["type"]] ==
             ["book.create", "book.destroy"]

    Enum.each(decoded, fn doc ->
      assert {:ok, _} = Validator.validate(doc)
    end)

    assert {:ok, report} = OcelNdjson.validate_ndjson_file(OcelAshEmitter.log_path())
    assert report["event_count"] == 2
  end
end
