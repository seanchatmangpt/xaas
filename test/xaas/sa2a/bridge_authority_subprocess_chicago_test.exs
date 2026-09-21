defmodule Xaas.Sa2a.BridgeAuthoritySubprocessChicagoTest do
  @moduledoc """
  Chicago-style closure test, real-Port half: with a real, non-empty
  `:authority` evidence map supplied, `Xaas.Sa2a.Bridge.execute/2` must stop
  being blocked by `admit_authority/2` and reach the real port round trip.

  Real `Xaas.Sa2a.Bridge` GenServer, real `Port.open/2` against `/bin/cat`
  as a stand-in port process (an executable this dev machine does not have
  --  `autofde` from autofde-lab -- would be needed to run the real
  `beam-bridge` subcommand; `cat` is a real OS subprocess reachable here
  that exercises the exact same `{:line, ...}`-framed JSON-lines
  request/response path `Xaas.Sa2a.Bridge` actually speaks, without
  depending on that sibling checkout). `cat` echoes the exact JSON-lines
  request straight back on stdout, so a successful round trip through the
  real GenServer/Port/OS-process pipeline is itself the proof that
  authority was no longer the blocker -- no mocking of any kind.

  Tagged `:subprocess` per this repo's existing real-OS-process test
  convention (see `test/test_helper.exs`, `test/xaas/autofde/
  demo_planner_reactor_test.exs`): excluded from the fast default `mix
  test` loop, run via `mix test --include subprocess` or `mix test.full`.

  `async: false`: shares the singleton `Xaas.Sa2a.Bridge` process name with
  `bridge_authority_chicago_test.exs`; keeping both files non-async
  prevents any cross-file race on that name.
  """

  use ExUnit.Case, async: false

  @moduletag :subprocess

  test "sa2a_execute with a real authority ref reaches the real port and round-trips" do
    refute Process.whereis(Xaas.Sa2a.Bridge)

    start_supervised!({Xaas.Sa2a.Bridge, port_command: "cat", port_args: []})

    assert is_pid(Process.whereis(Xaas.Sa2a.Bridge))

    assert {:ok, resp} =
             Xaas.Sa2a.Bridge.execute("SELECT 1 FROM candidates",
               authority: %{granted_by: "test-operator", ref: "authority-ref-123"}
             )

    # The response came from a real spawned OS process round-tripping the
    # real JSON-lines request -- proof the call actually reached
    # Port.command/2 this time, not merely that no authority error came back.
    assert resp["op"] == "sa2a_execute"
    assert resp["query"] == "SELECT 1 FROM candidates"
  end
end
