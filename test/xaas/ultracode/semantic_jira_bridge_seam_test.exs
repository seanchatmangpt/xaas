defmodule Xaas.Ultracode.SemanticJiraBridgeSeamTest do
  @moduledoc """
  The compile seam of `Xaas.Ultracode.SemanticJiraBridge` (lane X1, v26.10.1-loop).

  The bridge module is conditionally compiled: the enclosing `if` in
  `lib/xaas/ultracode/semantic_jira_bridge.ex` admits the module into the build
  only when the resolved ggen_igniter ships the post-G1 TransitionLog digest pair
  as PUBLIC functions. This test never aliases or calls the bridge; it re-derives
  the exact 4-conjunct guard at runtime and asserts the two things the seam
  promises:

    1. the module is loaded IFF the guard holds (seam consistency);
    2. the guard holds (the dep-drift alarm: if a dep change silently drops the
       public `legacy_event_digest/1` — e.g. a revert to hex 26.9.29, where it is
       `defp` and `event_digest/1` is private too — this assert fails in the
       DEFAULT loop instead of the bridge silently vanishing from the build).

  Runs in the default `mix test` loop (never tagged), so the alarm cannot be
  skipped by tag exclusion.
  """

  use ExUnit.Case, async: true

  test "the bridge seam holds: module loaded IFF the post-G1 guard holds, and the guard holds" do
    # Re-derived at runtime inside the test body (no module attribute): this is
    # the same conjunction the bridge file's compile-time `if` evaluates, spelled
    # against the literal module atoms so a dep change that removes either public
    # digest function flips guard_holds to false here.
    guard_holds =
      Code.ensure_loaded?(GgenIgniter.SemanticJira.Shacl) and
        Code.ensure_loaded?(GgenIgniter.SemanticJira.TransitionLog) and
        function_exported?(GgenIgniter.SemanticJira.TransitionLog, :event_digest, 1) and
        function_exported?(GgenIgniter.SemanticJira.TransitionLog, :legacy_event_digest, 1)

    assert Code.ensure_loaded?(Xaas.Ultracode.SemanticJiraBridge) == guard_holds
    assert guard_holds == true
  end
end
