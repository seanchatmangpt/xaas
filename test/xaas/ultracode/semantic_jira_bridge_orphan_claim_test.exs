defmodule Xaas.Ultracode.SemanticJiraBridgeOrphanClaimTest do
  @moduledoc """
  QUALIFIER falsifier. Status when added: FAILS against the bridge at fb43705.

  `GgenIgniter.SemanticJira.TransitionLog.append/2` makes each event single-owner with an
  exclusive-create `digest-<hex>.claim` marker before it writes the event file. A producer
  killed between the marker and the event file leaves a marker with no event. Every later
  `append/2` of the same event then waits out `await/3` (500 x 10 ms) and returns
  `{:ok, nil, :already_recorded}`, and `Reconciler.reconcile/4` passes that through.

  `SemanticJiraBridge.admit/5` reports it as `{:ok, %{event: nil, disposition:
  :already_recorded}}`: an admission that names no transition, over a log that holds none,
  with the work order still on the frontier. The crown's "kill the producer" step kills the
  producer only AFTER it has finished, so it does not cover this window.

  The crash artifact is built directly from the marker layout in `TransitionLog.claim_digest/2`
  (a marker file named after the event digest, in the log directory). Real kernel, real
  `Reconciler`, real `TransitionLog`; no doubles. A lawful outcome is a typed refusal or a
  landed event, never `{:ok, event: nil}`.
  """

  use ExUnit.Case, async: false

  alias GgenIgniter.SemanticJira.TransitionLog
  alias Xaas.Ultracode.SemanticJiraBridge, as: Bridge
  alias Xaas.Ultracode.SemanticJiraBridgeFixtures, as: F

  @base F.sha("base")

  test "an orphaned digest claim (writer killed inside append) is never reported as an admission" do
    reference_log = F.tmp_dir("orphan-ref")
    orphaned_log = F.tmp_dir("orphan-log")

    on_exit(fn ->
      File.rm_rf(reference_log)
      File.rm_rf(orphaned_log)
    end)

    root = F.work_order("FIX-BROKEN", @base)
    graph = [root, F.work_order("VERIFY-CLEAN", @base, ["FIX-BROKEN"])]

    opts = [
      execution_repo_alias: "demo",
      verifier_suite: "bridge-suite",
      graph_digest: F.graph_digest(),
      court_map: F.court_map("FIX-BROKEN", "check.sh::broken_absent", "check.sh::no_regression")
    ]

    {:ok, %{execution: execution}} = Bridge.descriptor(graph, reference_log, "FIX-BROKEN", opts)
    export = F.export(root, execution["bridge"])

    # what a clean log records for this export
    assert {:ok, %{event: reference, disposition: :appended}} =
             Bridge.admit(graph, "FIX-BROKEN", export, reference_log, fabric_check: false)

    # the writer was killed after claiming the event digest and before the event file landed
    File.mkdir_p!(orphaned_log)
    hex = String.slice(reference["event_digest"], 7, 64)
    File.write!(Path.join(orphaned_log, "digest-#{hex}.claim"), "")
    assert TransitionLog.read(orphaned_log) == []

    result = Bridge.admit(graph, "FIX-BROKEN", export, orphaned_log, fabric_check: false)

    refute match?({:ok, %{event: nil}}, result),
           "false admission over an empty log: #{inspect(result, limit: 8)}"

    assert match?({:error, {:refused_bridge, _}}, result) or
             match?({:ok, %{event: %{"event_digest" => _}}}, result)
  end
end
