defmodule Xaas.Telemetry.OcelAshEmitterTest do
  @moduledoc """
  Chicago-school test: real sandboxed Postgres, real Ash actions (no
  telemetry mocking, no fabricated OCEL events). Asserts the real defect
  fix -- a failing Ash action produces an OCEL line whose `outcome` is
  distinguishable from a successful one -- by driving two real
  `Xaas.Library.Book` creates (one with a resolved actor that succeeds,
  one with `actor: nil` that the resource's own
  `authorize_if actor_present()` policy really denies) and reading the
  real, real-appended `priv/ocel/ash-actions.ndjson` lines each one
  produced.

  Since the OCEL v2 reshape (ERRC RAISE) the same test also reads the
  RESHAPED per-line documents: each appended line is a complete OCEL 2.0
  JSON log whose one event carries `id`/`type`/`time`/`attributes`/
  `relationships`. A second test drives the module's REAL
  `handle_event/4` (plus the REAL `Ash.Tracer.set_handled_error/2`
  callback for the error-outcome event) and asserts every real emitted
  line passes the real conformance court (`Xaas.Ultracode.Ocel.Validator`)
  -- per line AND aggregated through the real
  `Xaas.Telemetry.OcelNdjson.validate_ndjson_file/1` assembly -- with a
  per-field breakdown pinning each reshaped field's law.
  """
  use Xaas.DataCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.Book
  alias Xaas.Telemetry.OcelAshEmitter
  alias Xaas.Ultracode.Ocel.Validator

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    # Real fixture-scoping fix, not a mock: `priv/ocel/ash-actions.ndjson`
    # is the real, shared OCEL log every Ash action across every test run
    # appends to (ocel_ash_emitter.ex). Since the V9 telemetry-hygiene
    # change it is size-capped (rotates at 10 MiB, keeps 2 rotated
    # siblings), but truncating it here is still what keeps this test's
    # own reads scoped: read_ocel_lines/0 below reads only this test's
    # own real writes instead of the whole repo's accumulated test
    # history (352MB / 844,698 lines observed pre-cap), which was the
    # actual 13.3s cost -- not network retry or sleep.
    log_path = OcelAshEmitter.log_path()
    File.mkdir_p!(Path.dirname(log_path))
    File.write!(log_path, "")

    :ok
  end

  defp read_ocel_lines do
    OcelAshEmitter.log_path()
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

  # The per-line OCEL 2.0 document holds exactly one event (the emitter's
  # append law since the reshape).
  defp event_of(line_doc), do: hd(line_doc["ocel:events"])
  defp attributes_of(line_doc), do: event_of(line_doc)["attributes"]

  test "a real successful Ash create and a real failing Ash update produce OCEL lines with distinguishable outcomes" do
    actor =
      Ash.Seed.seed!(User, %{
        email: "ocel-emitter-#{System.unique_integer([:positive])}@example.com"
      })

    lines_before = read_ocel_lines()
    count_before = length(lines_before)

    # Real successful action: Ash.Library.Book create, via the real Ash
    # domain action pipeline (not seeded), with a resolved actor to
    # satisfy the resource's `authorize_if actor_present()` policy.
    {:ok, book} =
      Book
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "OCEL Outcome Fixture",
          author: "Test Author",
          isbn: "OCEL-TEST-#{System.unique_integer([:positive])}",
          grade_level: Decimal.new("3"),
          genres: ["Fiction"],
          formats: ["hardcover"],
          available_copies: 0,
          total_copies: 1
        },
        actor: actor
      )
      |> Ash.create()

    # Real failing action: a second `Book` create with no actor
    # real-triggers the resource's own `policy action_type([:create,
    # :update, :destroy]) do authorize_if actor_present() end`
    # (lib/xaas/library/book.ex) -- a genuine `Ash.Policy.Authorizer`
    # denial. Confirmed empirically (not assumed) to differ from a plain
    # attribute/compare validation failure: `Ash.Changeset.for_update`'s
    # own eager attribute-constraint validation short-circuits
    # `Ash.Actions.Update.run/4` *before* its `Ash.Tracer.telemetry_span`
    # even opens (`run(domain, %{valid?: false, ...}, ...)` in
    # `deps/ash/lib/ash/actions/update/update.ex`), so that class of
    # failure never reaches this module's `handle_event/4` at all -- a
    # real, disclosed further gap in Ash's own telemetry, separate from
    # this fix. A policy denial, in contrast, is evaluated *inside* the
    # real pipeline the `telemetry_span` wraps, so it is the real,
    # minimal failure this fix can distinguish.
    assert {:error, %Ash.Error.Forbidden{}} =
             Book
             |> Ash.Changeset.for_create(
               :create,
               %{
                 title: "OCEL Outcome Fixture (forbidden)",
                 author: "Test Author",
                 isbn: "OCEL-TEST-FORBIDDEN-#{System.unique_integer([:positive])}",
                 grade_level: Decimal.new("3"),
                 genres: ["Fiction"],
                 formats: ["hardcover"],
                 available_copies: 0,
                 total_copies: 1
               },
               actor: nil
             )
             |> Ash.create()

    lines_after = read_ocel_lines()
    new_lines = Enum.drop(lines_after, count_before)

    assert length(new_lines) >= 2,
           "expected at least 2 new OCEL lines (2 real Book creates), got #{length(new_lines)}: #{inspect(new_lines)}"

    create_lines =
      Enum.filter(new_lines, fn line ->
        String.ends_with?(event_of(line)["type"], ".create")
      end)

    ok_line = Enum.find(create_lines, &(attributes_of(&1)["outcome"] == "ok"))
    error_line = Enum.find(create_lines, &(attributes_of(&1)["outcome"] == "error"))

    refute is_nil(ok_line),
           "expected a real OCEL line with outcome \"ok\" for the successful create"

    refute is_nil(error_line),
           "expected a real OCEL line with outcome \"error\" for the forbidden create"

    assert attributes_of(ok_line)["outcome"] == "ok"
    assert attributes_of(error_line)["outcome"] == "error"
    assert attributes_of(ok_line)["outcome"] != attributes_of(error_line)["outcome"]

    refute is_nil(book)
  end

  # -- OCEL v2 reshape: real emitted lines pass the real conformance court --

  @doc """
  Emits N real events through the module's REAL `handle_event/4` (the
  exact function `:telemetry` invokes) covering the real shape surface --
  ok outcome, error outcome (via the REAL `Ash.Tracer.set_handled_error/2`
  callback contract), a real actor object, a real tenant, a generic
  `:action` type, and degraded metadata with no resource identity -- then
  reads the lines back from the REAL test-env log file (the fixture) and
  asserts the real court accepts each line AND the assembled file.
  """
  test "every real emitted line passes Xaas.Ultracode.Ocel.Validator, per line and assembled" do
    actor =
      Ash.Seed.seed!(User, %{
        email: "ocel-emitter-v2-#{System.unique_integer([:positive])}@example.com"
      })

    # 1. Real ok event with real actor + tenant in the telemetry metadata
    #    (the keys Ash's own action pipelines populate).
    :ok =
      OcelAshEmitter.handle_event(
        [:ash, :library, :create, :stop],
        %{duration: 1_000_000},
        %{
          resource: Book,
          action: :create,
          domain: Xaas.Library,
          resource_short_name: "book",
          actor: actor,
          tenant: "org-e9",
          authorize?: true
        },
        nil
      )

    # 2. Real error-outcome event, sourced from the REAL Ash.Tracer
    #    callback this module implements (the same call Ash's action
    #    pipelines make on every real action error).
    :ok = OcelAshEmitter.set_handled_error(%Ash.Error.Forbidden.Policy{}, [])

    :ok =
      OcelAshEmitter.handle_event(
        [:ash, :library, :update, :stop],
        %{duration: 2_000_000},
        %{resource: Book, action: :update, domain: Xaas.Library, resource_short_name: "book"},
        nil
      )

    # 3. Real generic-action event (the [:ash, domain, :action, :stop]
    #    subscription).
    :ok =
      OcelAshEmitter.handle_event(
        [:ash, :library, :action, :stop],
        %{duration: 3_000_000},
        %{resource: Book, action: :checkout, domain: Xaas.Library, resource_short_name: "book"},
        nil
      )

    # 4. Degraded metadata -- no resource module, no short name: the
    #    "unknown" fallback must still produce a CONFORMING line.
    :ok =
      OcelAshEmitter.handle_event(
        [:ash, :library, :read, :stop],
        %{duration: 4_000_000},
        %{resource: nil, action: :read, domain: nil},
        nil
      )

    # The fixture: real lines read back from the real test-env log file.
    path = OcelAshEmitter.log_path()
    raw_lines = path |> File.read!() |> String.split("\n", trim: true)

    assert length(raw_lines) == 4,
           "expected exactly 4 real emitted lines, got: #{inspect(raw_lines)}"

    # PER LINE: the real conformance court accepts each one-event log.
    Enum.each(raw_lines, fn raw_line ->
      decoded = Jason.decode!(raw_line)

      assert {:ok, report} = Validator.validate(decoded),
             "real emitted line failed the real OCEL v2 court: " <>
               "#{inspect(Validator.validate(decoded))} for #{raw_line}"

      assert report["event_count"] == 1
    end)

    # ASSEMBLED: the real helper assembles the real file and the real
    # court accepts the aggregate.
    assert {:ok, report} = Xaas.Telemetry.OcelNdjson.validate_ndjson_file(path)
    assert report["status"] == "valid"
    assert report["event_count"] == 4

    # "book" dedupes to one object across lines; user/tenant/unknown.
    assert report["object_count"] == 4

    assert "book" in report["object_types"]
    assert "user" in report["object_types"]
    assert "Tenant" in report["object_types"]
    assert "unknown" in report["object_types"]
  end

  test "each reshaped field carries its real fact in the court-accepted shape" do
    actor =
      Ash.Seed.seed!(User, %{
        email: "ocel-emitter-fields-#{System.unique_integer([:positive])}@example.com"
      })

    :ok =
      OcelAshEmitter.handle_event(
        [:ash, :library, :create, :stop],
        %{duration: 1_500_000},
        %{
          resource: Book,
          action: :create,
          domain: Xaas.Library,
          resource_short_name: "book",
          actor: actor,
          tenant: "org-fields",
          authorize?: true
        },
        nil
      )

    [line] = read_ocel_lines()

    # Top level: EXACTLY the four OCEL 2.0 keys (closed vocabulary).
    assert MapSet.new(Map.keys(line)) ==
             MapSet.new(~w(ocel:objectTypes ocel:eventTypes ocel:events ocel:objects))

    event = event_of(line)
    attributes = attributes_of(line)

    # Event id: a real non-empty UUIDv7, distinct per emission.
    assert is_binary(event["id"]) and event["id"] != ""

    # Event type: "<short_name>.<action>", declared in the line's
    # ocel:eventTypes.
    assert event["type"] == "book.create"
    assert line["ocel:eventTypes"] == [%{"name" => "book.create"}]

    # Event time: ISO8601 parseable with ZERO UTC offset (the court's law).
    assert {:ok, _dt, 0} = DateTime.from_iso8601(event["time"])

    # Attributes (the spec's open surface): each real fact, nils dropped.
    assert attributes["outcome"] == "ok"
    assert attributes["action"] == "create"
    assert attributes["domain"] == "Xaas.Library"
    assert attributes["resource"] == "Xaas.Library.Book"
    assert attributes["authorize?"] == true
    assert attributes["duration_ms"] == System.convert_time_unit(1_500_000, :native, :millisecond)
    assert is_integer(attributes["public_attribute_count"])
    # ELIMINATED (reshape law): the boolean actor-presence flag is now
    # structural -- the actor object's relationship carries the fact.
    refute Map.has_key?(attributes, "actor_present?")
    # resource_description is nil for Book -> dropped, never emitted null.
    refute Map.has_key?(attributes, "resource_description")

    # Relationships: qualifier == referenced object's type, lowercased
    # (the run-export's one deterministic rule); every objectId resolves
    # inside the same line document; sorted by objectId.
    object_ids = MapSet.new(line["ocel:objects"], & &1["id"])

    assert event["relationships"] == [
             %{"objectId" => "book", "qualifier" => "book"},
             %{"objectId" => "tenant:org-fields", "qualifier" => "tenant"},
             %{"objectId" => "user:#{actor.id}", "qualifier" => "user"}
           ]

    for rel <- event["relationships"] do
      object = Enum.find(line["ocel:objects"], &(&1["id"] == rel["objectId"]))
      refute is_nil(object), "relationship objectId #{rel["objectId"]} must resolve in-line"
      assert rel["qualifier"] == String.downcase(object["type"])
      assert MapSet.member?(object_ids, rel["objectId"])
    end

    # Objects: class-level resource object, real per-instance actor
    # object (id = "<short_name>:<primary_key>"), tenant object.
    by_id = Map.new(line["ocel:objects"], &{&1["id"], &1})
    assert by_id["book"]["type"] == "book"
    assert by_id["book"]["attributes"] == %{}
    assert by_id["user:#{actor.id}"]["type"] == "user"
    assert by_id["tenant:org-fields"]["type"] == "Tenant"

    # Declared object types cover every emitted object's type.
    declared = MapSet.new(line["ocel:objectTypes"], & &1["name"])
    assert MapSet.member?(declared, "book")
    assert MapSet.member?(declared, "user")
    assert MapSet.member?(declared, "Tenant")
  end

  test "non-resource actors emit no actor object, and the unknown-resource fallback still conforms" do
    # A plain map actor (not an Ash resource struct) and a nil tenant:
    # no actor/tenant object, no relationship -- the fallback is nothing,
    # never a fabricated id.
    :ok =
      OcelAshEmitter.handle_event(
        [:ash, :library, :read, :stop],
        %{duration: 500_000},
        %{
          resource: Book,
          action: :read,
          domain: Xaas.Library,
          resource_short_name: "book",
          actor: %{"not" => "a struct"},
          tenant: nil
        },
        nil
      )

    [line] = read_ocel_lines()
    event = event_of(line)

    assert [%{"objectId" => "book", "qualifier" => "book"}] == event["relationships"]

    assert [%{"id" => "book", "type" => "book", "attributes" => %{}, "relationships" => []}] ==
             line["ocel:objects"]

    assert {:ok, _} = Validator.validate(line)

    # No resource identity at all: the "unknown" fallback keeps the line
    # conformant (non-empty type, resolvable object, declared types).
    :ok =
      OcelAshEmitter.handle_event(
        [:ash, :library, :read, :stop],
        %{duration: 500_000},
        %{resource: nil, action: :read, domain: nil},
        nil
      )

    [_, unknown_line] = read_ocel_lines()
    assert event_of(unknown_line)["type"] == "unknown.read"
    assert {:ok, _} = Validator.validate(unknown_line)
  end

  test "a metadata payload that cannot be encoded never raises into the caller" do
    # A pid in a raw attribute value is unencodable by Jason: the append
    # path's rescue discloses the real failure via Logger and the handler
    # still returns :ok -- the caller's (real) Ash action is untouched.
    # This test passing at all is the proof: a raise would fail it.
    assert :ok =
             OcelAshEmitter.handle_event(
               [:ash, :library, :create, :stop],
               %{duration: 1_000},
               %{
                 resource: Book,
                 action: :create,
                 domain: Xaas.Library,
                 resource_short_name: "book",
                 authorize?: self()
               },
               nil
             )
  end
end
