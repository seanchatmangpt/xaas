defmodule Xaas.Telemetry.OcelNdjsonTest do
  @moduledoc """
  Tests for `Xaas.Telemetry.OcelNdjson`, the assembly bridge from the
  emitter's per-line OCEL 2.0 ndjson documents to the whole-document
  shape the real conformance court (`Xaas.Ultracode.Ocel.Validator`)
  adjudicates.

  The fail-closed laws are exercised against REAL files in a REAL
  sandbox directory (unique per test, removed on exit), including the
  permanent tripwire: a REAL legacy-shape line captured verbatim from
  the pre-reshape dev log (`_build/dev/lib/xaas/priv/ocel/
  ash-actions.ndjson`, first line of the file) must be REFUSED with a
  violation naming the legacy flat-event shape -- regressing the emitter
  to the non-conforming `ocel:eid`/`ocel:activity` shape can never
  silently validate again.
  """

  use ExUnit.Case, async: false

  alias Xaas.Telemetry.OcelNdjson
  alias Xaas.Ultracode.Ocel.Validator

  setup ctx do
    sandbox =
      Path.join(System.tmp_dir!(), "ocel-ndjson-test-#{ctx.test}-#{System.unique_integer()}")

    File.mkdir_p!(sandbox)
    on_exit(fn -> File.rm_rf(sandbox) end)

    %{sandbox: sandbox}
  end

  # One minimal, individually-conformant OCEL 2.0 document line in the
  # exact shape the reshaped emitter appends.
  defp conforming_line(event_id, object_id) do
    document = %{
      "ocel:objectTypes" => [%{"name" => "thing"}],
      "ocel:eventTypes" => [%{"name" => "thing.poke"}],
      "ocel:events" => [
        %{
          "id" => event_id,
          "type" => "thing.poke",
          "time" => "2026-09-21T00:00:00.000000Z",
          "attributes" => %{"outcome" => "ok"},
          "relationships" => [%{"objectId" => object_id, "qualifier" => "thing"}]
        }
      ],
      "ocel:objects" => [
        %{"id" => object_id, "type" => "thing", "attributes" => %{}, "relationships" => []}
      ]
    }

    JSON.encode!(document)
  end

  # REAL pre-reshape emitter output, captured verbatim from the dev log
  # (run.tick on Xaas.Ultracode.Run) -- the shape the court rejects.
  @legacy_line "{\"ocel:activity\":\"run.tick\",\"ocel:eid\":\"01a0ca6b-d83a-7139-bcb8-71eb9b033688\",\"ocel:omap\":[\"run\"],\"ocel:timestamp\":\"2026-09-22T18:41:00.474091Z\",\"ocel:vmap\":{\"action\":\"tick\",\"actor_present?\":true,\"authorize?\":true,\"domain\":\"Xaas.Ultracode\",\"duration_ms\":2,\"outcome\":\"ok\",\"public_attribute_count\":28,\"resource\":\"Xaas.Ultracode.Run\",\"resource_description\":null}}"

  test "assembles conforming lines into one valid document, deduplicating objects by id" do
    lines = [
      conforming_line("evt-1", "thing-1"),
      conforming_line("evt-2", "thing-1")
    ]

    assert {:ok, document} = OcelNdjson.assemble_document(lines)

    assert {:ok, report} = Validator.validate(document)
    assert report["status"] == "valid"
    assert report["event_count"] == 2
    # "thing-1" stated twice across lines, once in the aggregate.
    assert report["object_count"] == 1
    assert report["event_types"] == ["thing.poke"]
    assert report["object_types"] == ["thing"]
  end

  test "file order is preserved and object ids are stated once, first occurrence" do
    path =
      write_ndjson([
        conforming_line("evt-a", "thing-1"),
        conforming_line("evt-b", "thing-1")
      ])

    assert {:ok, document} = OcelNdjson.read_document(path)
    assert Enum.map(document["ocel:events"], & &1["id"]) == ["evt-a", "evt-b"]
    assert Enum.map(document["ocel:objects"], & &1["id"]) == ["thing-1"]
  end

  test "validate_ndjson_file/1 runs the real court over the assembled file" do
    path = write_ndjson([conforming_line("evt-1", "thing-1")])

    assert {:ok, report} = OcelNdjson.validate_ndjson_file(path)
    assert report["status"] == "valid"
    assert report["event_count"] == 1
    assert report["object_count"] == 1
  end

  test "blank lines are skipped and never counted as events" do
    lines = ["", conforming_line("evt-1", "thing-1"), ""]

    assert {:ok, document} = OcelNdjson.assemble_document(lines)
    assert {:ok, report} = Validator.validate(document)
    assert report["event_count"] == 1
  end

  test "a legacy flat-event line is refused, naming the legacy shape (permanent tripwire)" do
    assert {:error, [%{path: "line 1", reason: reason}]} =
             OcelNdjson.assemble_document([@legacy_line])

    assert reason =~ "legacy flat event shape"
    assert reason =~ "ocel:eid"
  end

  test "a malformed-JSON line fails closed with a typed line path" do
    assert {:error, [%{path: "line 1", reason: reason}]} =
             OcelNdjson.assemble_document(["{not json"])

    assert reason =~ "malformed JSON"
  end

  test "a line missing any of the four OCEL 2.0 top-level arrays fails closed" do
    half_document =
      JSON.encode!(%{
        "ocel:events" => [],
        "ocel:objects" => []
      })

    assert {:error, violations} = OcelNdjson.assemble_document([half_document])

    for key <- ~w(ocel:objectTypes ocel:eventTypes) do
      # Violations are atom-keyed maps, exactly like the court's own
      # `%{path: ..., reason: ...}` violation shape.
      assert Enum.any?(violations, &(&1.path == "line 1.#{key}"))
    end
  end

  test "a malformed type-declaration element fails closed at its exact line path" do
    bad_declaration_line =
      JSON.encode!(%{
        "ocel:objectTypes" => [%{"name" => "thing"}],
        "ocel:eventTypes" => [42],
        "ocel:events" => [],
        "ocel:objects" => []
      })

    assert {:error, [%{path: "line 1.ocel:eventTypes[0]", reason: reason}]} =
             OcelNdjson.assemble_document([bad_declaration_line])

    assert reason =~ "malformed type declaration"
  end

  test "an unreadable file fails closed at path $ like the court does", %{sandbox: sandbox} do
    assert {:error, [%{path: "$", reason: reason}]} =
             OcelNdjson.validate_ndjson_file(Path.join(sandbox, "absent.ndjson"))

    assert reason =~ "cannot read file"
  end

  defp write_ndjson(lines) do
    path = Path.join(System.tmp_dir!(), "ocel-ndjson-#{System.unique_integer()}.ndjson")
    File.write!(path, Enum.map_join(lines, "\n", & &1) <> "\n")
    on_exit(fn -> File.rm(path) end)
    path
  end
end
