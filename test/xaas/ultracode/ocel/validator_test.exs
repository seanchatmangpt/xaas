defmodule Xaas.Ultracode.Ocel.ValidatorTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Adversarial qualification of the OCEL 2.0 conformance court
  (`Xaas.Ultracode.Ocel.Validator`), in the house adversarial style.

  Every violation class in the enforced law is proven by a REAL mutation of a
  real valid log, and each single mutation must produce EXACTLY that one
  violation and nothing else -- a court that fails a log for the wrong reason
  is worse than no court. Nothing mocked: validation is pure, file tests use
  real files decoded by the built-in JSON module.
  """

  alias Xaas.Ultracode.Ocel.Validator

  # -- the valid fixture ----------------------------------------------------

  defp valid_log do
    %{
      "ocel:objectTypes" => ["order", "item"],
      "ocel:eventTypes" => ["order_placed", "item_picked"],
      "ocel:events" => [
        %{
          "id" => "e1",
          "type" => "order_placed",
          "time" => "2026-09-19T09:00:00Z",
          "attributes" => %{"channel" => "web"},
          "relationships" => [%{"objectId" => "o1", "qualifier" => "places"}]
        },
        %{
          "id" => "e2",
          "type" => "item_picked",
          "time" => "2026-09-19T09:05:00.250Z",
          "attributes" => %{},
          "relationships" => [
            %{"objectId" => "o1", "qualifier" => "belongs_to"},
            %{"objectId" => "i1", "qualifier" => "picks"}
          ]
        }
      ],
      "ocel:objects" => [
        %{"id" => "o1", "type" => "order", "attributes" => %{"total" => 42}},
        %{"id" => "i1", "type" => "item", "attributes" => %{}}
      ]
    }
  end

  defp minimal_log do
    %{
      "ocel:objectTypes" => [],
      "ocel:eventTypes" => [],
      "ocel:events" => [],
      "ocel:objects" => []
    }
  end

  # -- mutation helpers (each negative test mutates exactly one thing) ------

  defp mutate_event(index, fun),
    do: update_in(valid_log(), ["ocel:events", Access.at(index)], fun)

  defp mutate_object(index, fun),
    do: update_in(valid_log(), ["ocel:objects", Access.at(index)], fun)

  defp mutate_relationship(event_index, rel_index, fun) do
    update_in(
      valid_log(),
      ["ocel:events", Access.at(event_index), "relationships", Access.at(rel_index)],
      fun
    )
  end

  defp assert_single_violation(log, expected_path, expected_reason_pattern) do
    assert {:error, [violation]} = Validator.validate(log)
    assert violation.path == expected_path
    assert violation.reason =~ expected_reason_pattern
    violation
  end

  # -- happy paths ----------------------------------------------------------

  test "a fully-populated valid log passes with a JSON-safe report" do
    assert {:ok, report} = Validator.validate(valid_log())
    assert report["status"] == "valid"
    assert report["event_count"] == 2
    assert report["object_count"] == 2
    assert report["event_types"] == ["item_picked", "order_placed"]
    assert report["object_types"] == ["item", "order"]
  end

  test "a valid minimal log (explicitly empty collections) passes" do
    assert {:ok, report} = Validator.validate(minimal_log())
    assert report["event_count"] == 0
    assert report["object_count"] == 0
  end

  test "absence is not emptiness: a missing ocel:events key is a violation, never an implicit []" do
    log = Map.delete(minimal_log(), "ocel:events")

    assert_single_violation(log, "ocel:events", "missing required top-level key")
  end

  test "a zero-offset +00:00 time is valid UTC" do
    log =
      mutate_event(0, fn e -> Map.put(e, "time", "2026-09-19T09:00:00.000+00:00") end)

    assert {:ok, _report} = Validator.validate(log)
  end

  test "attribute VALUES are open: deeply nested values are legal" do
    log =
      mutate_event(0, fn e ->
        Map.put(e, "attributes", %{"nested" => %{"list" => [1, 2, %{"deep" => true}]}})
      end)

    assert {:ok, _report} = Validator.validate(log)
  end

  test "type declarations may be map-form ({name: ...}) as well as bare strings" do
    log = %{
      valid_log()
      | "ocel:eventTypes" => [%{"name" => "order_placed"}, %{"name" => "item_picked"}],
        "ocel:objectTypes" => [%{"name" => "order"}, %{"name" => "item"}]
    }

    assert {:ok, _report} = Validator.validate(log)
  end

  test "event ids and object ids are separate namespaces (per-collection uniqueness, spec letter)" do
    log = mutate_event(0, fn e -> Map.put(e, "id", "o1") end)
    assert {:ok, _report} = Validator.validate(log)
  end

  test "objects may carry relationships that resolve" do
    log =
      mutate_object(0, fn o ->
        Map.put(o, "relationships", [%{"objectId" => "i1", "qualifier" => "contains"}])
      end)

    assert {:ok, _report} = Validator.validate(log)
  end

  # -- top-level law --------------------------------------------------------

  test "each missing required top-level key is exactly one violation (and cascades are suppressed)" do
    for key <- ~w(ocel:objectTypes ocel:eventTypes ocel:events ocel:objects) do
      log = Map.delete(valid_log(), key)

      # Deleting ocel:objects or ocel:eventTypes also corrupts a registry the
      # downstream checks depend on; the court suppresses those knock-on
      # checks, so the corrupt parent is STILL exactly one violation.
      assert_single_violation(log, key, "missing required top-level key")
    end
  end

  test "an extra top-level key is rejected (closed vocabulary)" do
    log = Map.put(valid_log(), "ocel:provenance", %{"tool" => "something"})

    assert_single_violation(
      log,
      "ocel:provenance",
      "unexpected top-level key (closed vocabulary)"
    )
  end

  test "a non-object top level fails closed at path $" do
    for bad <- [nil, [1, 2], "log", 42] do
      assert {:error, [violation]} = Validator.validate(bad)
      assert violation.path == "$"
      assert violation.reason =~ "top level must be a JSON object"
    end
  end

  # -- collection-level law -------------------------------------------------

  test "ocel:events that is not an array is exactly one violation" do
    log = Map.put(valid_log(), "ocel:events", %{"id" => "e1"})

    assert_single_violation(log, "ocel:events", "must be an array")
  end

  test "ocel:eventTypes that is not an array is exactly one violation, with no undeclared-type cascade" do
    log = Map.put(valid_log(), "ocel:eventTypes", "order_placed")

    assert_single_violation(log, "ocel:eventTypes", "must be an array of type declarations")
  end

  test "ocel:objects that is not an array is exactly one violation, with dangling checks inadmissible" do
    log = Map.put(valid_log(), "ocel:objects", 42)

    assert_single_violation(log, "ocel:objects", "must be an array")
  end

  # -- event law ------------------------------------------------------------

  test "an event that is not an object is exactly one violation" do
    log = mutate_event(0, fn _e -> "worker was here" end)

    assert_single_violation(log, "ocel:events[0]", "must be a JSON object")
  end

  test "each missing required event key is exactly one violation" do
    for key <- ~w(id type time attributes) do
      log = mutate_event(0, fn e -> Map.delete(e, key) end)

      assert_single_violation(log, "ocel:events[0].#{key}", "missing required key")
    end
  end

  test "an empty event id is a violation" do
    log = mutate_event(0, fn e -> Map.put(e, "id", "") end)

    assert_single_violation(log, "ocel:events[0].id", "must be a non-empty string")
  end

  test "a non-string event id is a violation" do
    log = mutate_event(0, fn e -> Map.put(e, "id", 42) end)

    assert_single_violation(log, "ocel:events[0].id", "must be a string")
  end

  test "a duplicate event id is a violation at the second occurrence" do
    log = mutate_event(1, fn e -> Map.put(e, "id", "e1") end)

    assert_single_violation(log, "ocel:events[1].id", "duplicate event id 'e1'")
  end

  test "an undeclared event type is a violation with the exact spec-example reason" do
    log = mutate_event(0, fn e -> Map.put(e, "type", "worker_launched") end)

    violation =
      assert_single_violation(
        log,
        "ocel:events[0].type",
        "'worker_launched' not declared in ocel:eventTypes"
      )

    assert violation.reason == "'worker_launched' not declared in ocel:eventTypes"
  end

  test "a non-string event type is a violation" do
    log = mutate_event(0, fn e -> Map.put(e, "type", 42) end)

    assert_single_violation(log, "ocel:events[0].type", "must be a string")
  end

  test "a non-ISO8601 time is a violation naming the offending value" do
    log = mutate_event(0, fn e -> Map.put(e, "time", "19/09/2026 09:00") end)

    assert_single_violation(
      log,
      "ocel:events[0].time",
      "'19/09/2026 09:00' is not parseable ISO8601 UTC"
    )
  end

  test "an ISO8601 time with a non-zero offset is a violation (UTC law)" do
    log = mutate_event(0, fn e -> Map.put(e, "time", "2026-09-19T11:00:00+02:00") end)

    assert_single_violation(log, "ocel:events[0].time", "ISO8601 but not UTC")
  end

  test "a non-string time is a violation" do
    log = mutate_event(0, fn e -> Map.put(e, "time", 1_763_571_600) end)

    assert_single_violation(log, "ocel:events[0].time", "must be a string")
  end

  test "attributes that are not an object are a violation" do
    log = mutate_event(0, fn e -> Map.put(e, "attributes", ["web"]) end)

    assert_single_violation(log, "ocel:events[0].attributes", "must be a JSON object")
  end

  test "an extra key inside an event is rejected (closed vocabulary)" do
    log = mutate_event(0, fn e -> Map.put(e, "severity", "high") end)

    assert_single_violation(log, "ocel:events[0].severity", "unexpected key 'severity'")
  end

  # -- object law -----------------------------------------------------------

  test "an object that is not an object is a violation, and references to its now-unknown id dangle" do
    log = mutate_object(0, fn _o -> 42 end)

    assert {:error, violations} = Validator.validate(log)

    assert violations == [
             %{path: "ocel:objects[0]", reason: "must be a JSON object, got: 42"},
             %{
               path: "ocel:events[0].relationships[0].objectId",
               reason: "objectId 'o1' does not resolve to any object in ocel:objects"
             },
             %{
               path: "ocel:events[1].relationships[0].objectId",
               reason: "objectId 'o1' does not resolve to any object in ocel:objects"
             }
           ]
  end

  test "each missing required object key is exactly one violation (type, attributes)" do
    for key <- ~w(type attributes) do
      log = mutate_object(0, fn o -> Map.delete(o, key) end)

      assert_single_violation(log, "ocel:objects[0].#{key}", "missing required key")
    end
  end

  test "a missing object id is the missing-key violation plus REAL dangling references (all exact)" do
    # Unlike a corrupt type registry (undecidable, suppressed), a vanished
    # object id is decidable: every relationship that pointed at it now
    # genuinely dangles. One mutation, three exact spec-letter defects.
    log = mutate_object(0, fn o -> Map.delete(o, "id") end)

    dangling = %{
      path: "ocel:events[0].relationships[0].objectId",
      reason: "objectId 'o1' does not resolve to any object in ocel:objects"
    }

    assert {:error, violations} = Validator.validate(log)

    assert violations == [
             %{path: "ocel:objects[0].id", reason: "missing required key"},
             dangling,
             %{
               path: "ocel:events[1].relationships[0].objectId",
               reason: "objectId 'o1' does not resolve to any object in ocel:objects"
             }
           ]
  end

  test "a duplicate object id is a violation at the second occurrence" do
    log =
      update_in(valid_log(), ["ocel:objects"], fn objects ->
        objects ++ [%{"id" => "o1", "type" => "order", "attributes" => %{}}]
      end)

    assert_single_violation(log, "ocel:objects[2].id", "duplicate object id 'o1'")
  end

  test "an undeclared object type is a violation" do
    log = mutate_object(0, fn o -> Map.put(o, "type", "invoice") end)

    assert_single_violation(
      log,
      "ocel:objects[0].type",
      "'invoice' not declared in ocel:objectTypes"
    )
  end

  test "an extra key inside an object is rejected -- objects have no time key" do
    log = mutate_object(0, fn o -> Map.put(o, "time", "2026-09-19T09:00:00Z") end)

    assert_single_violation(log, "ocel:objects[0].time", "unexpected key 'time'")
  end

  # -- relationship law -----------------------------------------------------

  test "relationships that are not an array are a violation" do
    log = mutate_event(0, fn e -> Map.put(e, "relationships", %{"objectId" => "o1"}) end)

    assert_single_violation(log, "ocel:events[0].relationships", "must be an array")
  end

  test "a relationship that is not an object is a violation" do
    log = mutate_event(0, fn e -> Map.put(e, "relationships", ["o1"]) end)

    assert_single_violation(log, "ocel:events[0].relationships[0]", "must be a JSON object")
  end

  test "each missing relationship key is exactly one violation" do
    for key <- ~w(objectId qualifier) do
      log = mutate_relationship(0, 0, fn rel -> Map.delete(rel, key) end)

      assert_single_violation(
        log,
        "ocel:events[0].relationships[0].#{key}",
        "missing required key"
      )
    end
  end

  test "an extra key inside a relationship is rejected (closed vocabulary)" do
    log = mutate_relationship(0, 0, fn rel -> Map.put(rel, "since", "2026-09-19") end)

    assert_single_violation(
      log,
      "ocel:events[0].relationships[0].since",
      "unexpected key 'since'"
    )
  end

  test "a dangling objectId is a violation with the exact reason" do
    log = mutate_relationship(0, 0, fn rel -> Map.put(rel, "objectId", "ghost-object") end)

    violation =
      assert_single_violation(
        log,
        "ocel:events[0].relationships[0].objectId",
        "objectId 'ghost-object' does not resolve to any object in ocel:objects"
      )

    assert violation.reason ==
             "objectId 'ghost-object' does not resolve to any object in ocel:objects"
  end

  test "a dangling objectId on an object's relationship is a violation too" do
    log =
      update_in(valid_log(), ["ocel:objects", Access.at(0)], fn o ->
        Map.put(o, "relationships", [%{"objectId" => "ghost-object", "qualifier" => "refs"}])
      end)

    assert_single_violation(
      log,
      "ocel:objects[0].relationships[0].objectId",
      "objectId 'ghost-object' does not resolve"
    )
  end

  test "a non-string objectId is a violation" do
    log = mutate_relationship(0, 0, fn rel -> Map.put(rel, "objectId", 42) end)

    assert_single_violation(log, "ocel:events[0].relationships[0].objectId", "must be a string")
  end

  test "a non-string qualifier is a violation" do
    log = mutate_relationship(0, 0, fn rel -> Map.put(rel, "qualifier", 42) end)

    assert_single_violation(log, "ocel:events[0].relationships[0].qualifier", "must be a string")
  end

  # -- type-declaration law -------------------------------------------------

  test "a malformed type declaration is exactly one violation, with no undeclared-type cascade" do
    log = Map.put(valid_log(), "ocel:eventTypes", ["order_placed", 42, "item_picked"])

    assert_single_violation(log, "ocel:eventTypes[1]", "malformed type declaration 42")
  end

  test "a map-form declaration with extra keys is malformed (closed vocabulary)" do
    log = %{
      valid_log()
      | "ocel:eventTypes" => [%{"name" => "order_placed", "ocel:template" => []}]
    }

    assert_single_violation(log, "ocel:eventTypes[0]", "malformed type declaration")
  end

  test "map-form declarations with a bad name are malformed" do
    for bad_name <- ["", 42, nil] do
      log = %{valid_log() | "ocel:eventTypes" => [%{"name" => bad_name}]}

      assert_single_violation(log, "ocel:eventTypes[0]", "malformed type declaration")
    end
  end

  test "a map-form declaration without a name key is malformed" do
    log = %{valid_log() | "ocel:eventTypes" => [%{"nama" => "order_placed"}]}

    assert_single_violation(log, "ocel:eventTypes[0]", "malformed type declaration")
  end

  # -- validate_file (built-in JSON first) ----------------------------------

  defp write_tmp_log(name, body) do
    path =
      Path.join(System.tmp_dir!(), "w3_ocel_court_#{System.unique_integer([:positive])}_#{name}")

    File.write!(path, body)
    on_exit(fn -> File.rm(path) end)
    path
  end

  test "validate_file decodes with the built-in JSON first and passes a real valid file" do
    path = write_tmp_log("valid.json", JSON.encode!(valid_log()))

    assert {:ok, report} = Validator.validate_file(path)
    assert report["status"] == "valid"
    assert report["event_count"] == 2
    assert report["object_count"] == 2
  end

  test "validate_file fails closed on malformed JSON: exactly one violation at $" do
    path = write_tmp_log("broken.json", ~s({"ocel:events": [not json}))

    assert {:error, [violation]} = Validator.validate_file(path)
    assert violation.path == "$"
    assert violation.reason =~ "malformed JSON"
  end

  test "validate_file fails closed on an unreadable file" do
    missing =
      Path.join(
        System.tmp_dir!(),
        "w3_ocel_court_definitely_absent_#{System.unique_integer()}.json"
      )

    assert {:error, [violation]} = Validator.validate_file(missing)
    assert violation.path == "$"
    assert violation.reason =~ "cannot read file"
  end

  test "validate_file fails closed when the file's top level is not an object" do
    path = write_tmp_log("array.json", ~s([1, 2, 3]))

    assert {:error, [violation]} = Validator.validate_file(path)
    assert violation.path == "$"
    assert violation.reason =~ "top level must be a JSON object"
  end

  test "validate_file fails closed on a non-string path" do
    assert {:error, [violation]} = Validator.validate_file(42)
    assert violation.path == "$"
    assert violation.reason =~ "path must be a string"
  end

  # -- tampered-but-plausible logs fail for the RIGHT reason ----------------

  test "reordered keys are a semantic no-op; each real tamper is caught exactly once" do
    # Hand-written JSON: keys deliberately out of the natural order (a naive
    # textual court would flag the reordering itself). Two real tampers:
    # a rogue event whose type is undeclared, and a dangling relationship.
    tampered = ~s({
      "ocel:objects": [
        {"attributes": {"total": 42}, "type": "order", "id": "o1"},
        {"attributes": {}, "type": "item", "id": "i1"}
      ],
      "ocel:events": [
        {
          "relationships": [{"objectId": "o1", "qualifier": "places"}],
          "attributes": {"channel": "web"},
          "time": "2026-09-19T09:00:00Z",
          "type": "order_placed",
          "id": "e1"
        },
        {
          "relationships": [
            {"objectId": "o1", "qualifier": "belongs_to"},
            {"qualifier": "steals", "objectId": "ghost-object"}
          ],
          "attributes": {},
          "time": "2026-09-19T09:05:00Z",
          "type": "item_picked",
          "id": "e2"
        },
        {
          "attributes": {},
          "time": "2026-09-19T09:30:00Z",
          "type": "worker_launched",
          "id": "e9"
        }
      ],
      "ocel:eventTypes": ["order_placed", "item_picked"],
      "ocel:objectTypes": ["order", "item"]
    })

    path = write_tmp_log("tampered.json", tampered)

    assert {:error, [dangling, undeclared]} = Validator.validate_file(path)

    assert dangling == %{
             path: "ocel:events[1].relationships[1].objectId",
             reason: "objectId 'ghost-object' does not resolve to any object in ocel:objects"
           }

    assert undeclared == %{
             path: "ocel:events[2].type",
             reason: "'worker_launched' not declared in ocel:eventTypes"
           }
  end
end
