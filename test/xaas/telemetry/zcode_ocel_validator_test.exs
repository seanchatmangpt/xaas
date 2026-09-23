defmodule Xaas.Telemetry.ZcodeOcelValidatorTest do
  @moduledoc """
  Chicago-style, no-mocks proof (SJ-002) that `Xaas.Telemetry.ZcodeOcelValidator`
  really validates against the real generated
  `Xaas.Generated.ZcodeEventRegistry` (rendered by `mix ggen_igniter.sync
  --pack-dir priv/packs/xaas_zcode_ocel_pack`, not hand-listed) -- every
  assertion here is on real return values / real raised exceptions from real
  module calls, never on "was this called".
  """
  use ExUnit.Case, async: true

  alias Xaas.Generated.ZcodeEventRegistry
  alias Xaas.Telemetry.ZcodeOcelValidator

  test "the generated registry really carries the full zcode event vocabulary" do
    assert ZcodeEventRegistry.event_types() == [
             "TurnStarted",
             "TurnComplete",
             "TurnError",
             "ModelRequest",
             "ModelComplete",
             "ToolCallScheduled",
             "ToolCallStarted",
             "ToolCallResult",
             "ToolCallError",
             "PermissionRequested",
             "PermissionResolved",
             "SubagentSpawned",
             "SubagentStopped",
             "CompactStarted",
             "CompactCompleted"
           ]
  end

  test "a known generated event type is accepted" do
    assert {:ok, "ToolCallScheduled"} =
             ZcodeOcelValidator.validate_event_type("ToolCallScheduled")

    assert "ToolCallScheduled" = ZcodeOcelValidator.validate_event_type!("ToolCallScheduled")
  end

  test "the falsifier this ticket names: an event type absent from the generated registry is refused" do
    refute ZcodeEventRegistry.event_type?("HallucinatedEventType")

    assert {:error, {:unknown_event_type, "HallucinatedEventType"}} =
             ZcodeOcelValidator.validate_event_type("HallucinatedEventType")

    assert_raise ArgumentError, ~r/unknown zcode OCEL event type "HallucinatedEventType"/, fn ->
      ZcodeOcelValidator.validate_event_type!("HallucinatedEventType")
    end
  end

  test "build_event/3 refuses to build an event for an unknown event type" do
    assert {:error, {:unknown_event_type, "NotARealEvent"}} =
             ZcodeOcelValidator.build_event("NotARealEvent", %{"foo" => "bar"})
  end

  test "build_event/3 builds a real OCEL event map for a known event type, defaulting omap to the generated primary object" do
    assert {:ok, event} = ZcodeOcelValidator.build_event("TurnStarted", %{"foo" => "bar"})

    assert event["ocel:activity"] == "TurnStarted"
    assert event["ocel:omap"] == ["turn"]
    assert event["ocel:vmap"] == %{"foo" => "bar"}
    assert is_binary(event["ocel:eid"])
    assert is_binary(event["ocel:timestamp"])
  end

  test "object type validation also goes through the real generated registry" do
    assert {:ok, "turn"} = ZcodeOcelValidator.validate_object_type("turn")

    assert {:error, {:unknown_object_type, "not_a_real_object"}} =
             ZcodeOcelValidator.validate_object_type("not_a_real_object")
  end
end
