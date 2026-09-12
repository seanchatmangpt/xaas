defmodule Xaas.Telemetry.OcelEnvelopeTest do
  @moduledoc """
  Chicago-style state-based tests for the pure, generated
  `Xaas.Telemetry.OcelEnvelope.build/3` field constructor. No mocking of any
  kind -- real map literals in, real map assertions on the return value out.
  """
  use ExUnit.Case, async: true

  alias Xaas.Telemetry.OcelEnvelope

  test "build/3 wraps the given event, producer, and sequence into the exact envelope shape Ex4pm.OCEL.validate_envelope/1 requires" do
    event = %{
      "ocel:eid" => "evt-123",
      "ocel:activity" => "Book.checkout",
      "ocel:timestamp" => "2026-09-09T00:00:00Z",
      "ocel:omap" => ["Book"],
      "ocel:vmap" => %{"resource" => "Xaas.Library.Book"}
    }

    producer = %{"agent_id" => "xaas", "run_id" => "run-abc"}

    envelope = OcelEnvelope.build(event, producer, 7)

    assert envelope == %{
             "schema" => "xaas.ocel.v2",
             "producer" => producer,
             "sequence" => 7,
             "events" => [event]
           }
  end

  test "build/3 forwards the event map verbatim, unchanged, inside a single-element events list" do
    event = %{"ocel:eid" => "evt-456", "ocel:activity" => "Checkout.return"}

    envelope = OcelEnvelope.build(event, %{}, 0)

    assert envelope["events"] == [event]
    assert is_list(envelope["events"])
    assert length(envelope["events"]) == 1
  end

  test "build/3 result satisfies the loose structural shape Ex4pm.OCEL.validate_envelope/1 checks" do
    envelope = OcelEnvelope.build(%{"ocel:eid" => "e"}, %{"agent_id" => "xaas"}, 42)

    assert is_binary(envelope["schema"])
    assert is_map(envelope["producer"])
    assert is_integer(envelope["sequence"]) and envelope["sequence"] >= 0
    assert is_list(envelope["events"])
  end
end
