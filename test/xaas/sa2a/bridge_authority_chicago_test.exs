defmodule Xaas.Sa2a.BridgeAuthorityChicagoTest do
  @moduledoc """
  Chicago-style closure test for the `Xaas.Sa2a.Bridge` authority gap: prior
  to this closure, `call/2` (lines 96-98 as read this session) forwarded
  every op straight to `GenServer.call` -> `Port.command/2` with zero
  authority check, even though the real generated
  `Xaas.Sa2a.Generated.McpDescriptor.requires_authority?/1` already marks
  `sa2a_execute` `requires_authority?: true`.

  This exercises the real `Xaas.Sa2a.Bridge.execute/2` public client
  function (`lib/xaas/sa2a/bridge.ex`) and the real generated
  `Xaas.Sa2a.Generated.McpDescriptor` -- the same functions any real caller
  uses, not fixtures only this test reads. No mocking: the refusal case
  needs no GenServer and no Port at all, because the fix refuses before
  either is ever reached; that absence is itself part of what is asserted
  (`Process.whereis/1` stays nil across the call).

  `async: false` because it shares the singleton `Xaas.Sa2a.Bridge` process
  name with `bridge_authority_subprocess_chicago_test.exs` (which actually
  starts that GenServer under a real OS port); keeping both files
  non-async prevents any cross-file race on that name.

  The companion real-Port round trip proving a supplied authority ref is no
  longer the blocker lives in `bridge_authority_subprocess_chicago_test.exs`,
  tagged `:subprocess` per this repo's existing real-OS-process test
  convention (see `test/test_helper.exs`).
  """

  use ExUnit.Case, async: false

  alias Xaas.Sa2a.Generated.McpDescriptor

  test "sa2a_execute without an authority ref is refused before the port is ever touched" do
    refute Process.whereis(Xaas.Sa2a.Bridge)

    assert {:error, :sa2a_authority_evidence_required} =
             Xaas.Sa2a.Bridge.execute("SELECT 1 FROM candidates")

    # No GenServer was started as a side effect of the call -- proves the
    # refusal happened strictly before GenServer.call/Port.command, not
    # merely that the eventual response was an error.
    refute Process.whereis(Xaas.Sa2a.Bridge)
  end

  test "sa2a_execute with an empty authority map is refused the same as no authority at all" do
    assert {:error, :sa2a_authority_evidence_required} =
             Xaas.Sa2a.Bridge.execute("SELECT 1", authority: %{})
  end

  test "the fail-closed check is keyed by the real generated descriptor, not a blanket refusal" do
    assert McpDescriptor.requires_authority?("sa2a_execute")
    refute McpDescriptor.requires_authority?("sa2a_validate")
    refute McpDescriptor.requires_authority?("sa2a_admit")
    refute McpDescriptor.requires_authority?("sa2a_plan")
    refute McpDescriptor.requires_authority?("sa2a_replay")
    # Unregistered/unknown ops are fail-closed by default (McpDescriptor's own doc).
    assert McpDescriptor.requires_authority?("sa2a_unknown_future_op")
  end
end
