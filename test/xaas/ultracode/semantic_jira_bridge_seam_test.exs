defmodule Xaas.Ultracode.SemanticJiraBridgeSeamTest do
  @moduledoc """
  The compile seam of `Xaas.Ultracode.SemanticJiraBridge` (lane X1, v26.10.1-loop;
  shrunk by lane D1, 2026-10-02).

  The bridge module is conditionally compiled: the enclosing `if` in
  `lib/xaas/ultracode/semantic_jira_bridge.ex` admits the module into the build
  only when the resolved ggen_igniter ships the post-G1 TransitionLog digest
  seam as a PUBLIC `event_digest/1`. This test never aliases or calls the
  bridge; it re-derives the exact 3-conjunct guard at runtime and asserts the
  two things the seam promises:

    1. the module is loaded IFF the guard holds (seam consistency);
    2. the guard holds (the dep-drift alarm: if a dep change silently drops the
       public `event_digest/1` — e.g. a revert to hex 26.9.29, where it is
       `defp` — this assert fails in the DEFAULT loop instead of the bridge
       silently vanishing from the build).

  The deprecated `legacy_event_digest/1` is deliberately NOT in the guard: the
  legacy digest rule is a shrinking compatibility window (ggen marks it
  @deprecated with a v26.11.1 removal milestone), and the bridge's `derives?/1`
  probes its availability at run time, so a dep that drops the pre-v26.10.1
  export compiles and verifies current-only instead of the bridge vanishing.

  Runs in the default `mix test` loop (never tagged), so the alarm cannot be
  skipped by tag exclusion.
  """

  use ExUnit.Case, async: true

  test "the bridge seam holds: module loaded IFF the post-G1 guard holds, and the guard holds" do
    # Re-derived at runtime inside the test body (no module attribute): this is
    # the same conjunction the bridge file's compile-time `if` evaluates, spelled
    # against the literal module atoms so a dep change that removes the public
    # current-rule digest function flips guard_holds to false here.
    guard_holds =
      Code.ensure_loaded?(GgenIgniter.SemanticJira.Shacl) and
        Code.ensure_loaded?(GgenIgniter.SemanticJira.TransitionLog) and
        function_exported?(GgenIgniter.SemanticJira.TransitionLog, :event_digest, 1)

    assert Code.ensure_loaded?(Xaas.Ultracode.SemanticJiraBridge) == guard_holds
    assert guard_holds == true
  end
end
