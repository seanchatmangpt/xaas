defmodule Xaas.Ultracode.SemanticJiraBridgeFalsifierTest do
  @moduledoc """
  QUALIFIER falsifiers for `Xaas.Ultracode.SemanticJiraBridge` (no doubles, no
  database). Each test asserts the CONTRACT the bridge documents and is expected
  to FAIL while the bridge violates it; the failing output is the evidence.

    * malformed-but-digest-valid exports must be typed refusals, never crashes;
    * a killed producer (writer dead between the log's digest claim and its
      event file) must not leave a false `:already_recorded` success with no
      event and no transition;
    * a hand-written log event whose `event_digest` does not re-derive from its
      content must not steer the frontier or a descriptor's upstream receipt edge;
    * `event_digest` must commit to the receipt an event records (observed for real
      with six racing OS processes: one appended, five got `:already_recorded` for
      receipts whose digests appear in no event, because two events that differ only
      in `receipt_digest` share one `event_digest`).
  """

  use ExUnit.Case, async: false

  alias GgenIgniter.SemanticJira
  alias GgenIgniter.SemanticJira.TransitionLog
  alias Xaas.Ultracode.SemanticJiraBridge, as: Bridge
  alias Xaas.Ultracode.SemanticJiraBridgeFixtures, as: F

  @base F.sha("falsifier-base")

  setup do
    dir = F.tmp_dir("falsifier-log")
    on_exit(fn -> File.rm_rf(dir) end)

    root = F.work_order("FIX-BROKEN", @base)
    dependent = F.work_order("VERIFY-CLEAN", @base, ["FIX-BROKEN"])

    opts = [
      execution_repo_alias: "demo",
      verifier_suite: "bridge-suite",
      graph_digest: F.graph_digest(),
      court_map: F.court_map("FIX-BROKEN", "check.sh::broken_absent", "check.sh::no_regression")
    ]

    {:ok, %{descriptor: _v1, execution: execution}} =
      Bridge.descriptor([root, dependent], dir, "FIX-BROKEN", opts)

    %{
      dir: dir,
      root: root,
      dependent: dependent,
      graph: [root, dependent],
      opts: opts,
      export: F.export(root, execution["bridge"])
    }
  end

  # -- malformed exports: typed refusal, not an exception -------------------------

  @malformed [
    {"fabric_verifier is a string", ["fabric_verifier"], "oops"},
    {"fabric_verifier is a list", ["fabric_verifier"], ["oops"]},
    {"steps is a string", ["fabric_verifier", "steps"], "oops"},
    {"steps is a number", ["fabric_verifier", "steps"], 7},
    {"court_receipt.acceptance_results is a string",
     ["fabric_verifier", "court_receipt", "acceptance_results"], "oops"},
    {"court_receipt.falsifier_results is a list",
     ["fabric_verifier", "court_receipt", "falsifier_results"], ["oops"]},
    {"court_receipt.court_results is a list",
     ["fabric_verifier", "court_receipt", "court_results"], ["oops"]},
    {"court_receipt.binding is a string", ["fabric_verifier", "court_receipt", "binding"], "oops"}
  ]

  for {label, keys, value} <- @malformed do
    test "malformed export (#{label}) is a typed refusal, not a crash", ctx do
      forged = F.reseal(ctx.export, &put_in(&1, unquote(keys), unquote(Macro.escape(value))))

      assert forged["receipt_digest"] == Xaas.Ultracode.SemanticReceipt.receipt_digest(forged)

      result =
        try do
          Bridge.admit(ctx.graph, "FIX-BROKEN", forged, ctx.dir, fabric_check: false)
        rescue
          exception -> {:raised, exception}
        end

      assert match?({:error, {:refused_bridge, _}}, result),
             "expected {:error, {:refused_bridge, _}}, got #{inspect(result, limit: 8)}"

      assert TransitionLog.read(ctx.dir) == []
    end
  end

  # -- a killed producer must not leave a false success -----------------------------

  test "a writer killed after the digest claim leaves no false :already_recorded success",
       ctx do
    # A: what a healthy admission appends, to learn the event's deterministic digest.
    healthy = F.tmp_dir("falsifier-healthy")
    on_exit(fn -> File.rm_rf(healthy) end)

    assert {:ok, %{event: healthy_event, disposition: :appended}} =
             Bridge.admit(ctx.graph, "FIX-BROKEN", ctx.export, healthy, fabric_check: false)

    # B: the same admission, but its writer died right after TransitionLog claimed the
    # event digest (exclusive-create marker) and before the event file appeared. This is the
    # exact on-disk state such a kill leaves; nothing else is faked.
    claim = "digest-" <> String.slice(healthy_event["event_digest"], 7, 64) <> ".claim"
    File.mkdir_p!(ctx.dir)
    File.write!(Path.join(ctx.dir, claim), "")

    assert TransitionLog.read(ctx.dir) == []

    result = Bridge.admit(ctx.graph, "FIX-BROKEN", ctx.export, ctx.dir, fabric_check: false)

    # The log still has no event and FIX-BROKEN is still UNKNOWN. Reporting success with
    # `event: nil` acknowledges a transition that does not exist.
    assert TransitionLog.read(ctx.dir) == []
    assert Bridge.state(ctx.graph, ctx.dir)["standings"]["FIX-BROKEN"] == "UNKNOWN"

    refute match?({:ok, %{event: nil}}, result),
           "admit acknowledged a transition with event: nil: #{inspect(result, limit: 6)}"
  end

  # -- receipts: what the log records must be what the caller is told was recorded -----

  test "an event_digest commits to the receipt the event records", ctx do
    assert {:ok, %{event: event, disposition: :appended}} =
             Bridge.admit(ctx.graph, "FIX-BROKEN", ctx.export, ctx.dir, fabric_check: false)

    other = "sha256:" <> String.duplicate("b", 64)
    tampered = Map.put(event, "receipt_digest", other)

    # `event_digest` as TransitionLog.append/2 computes it: over the event without `seq`
    # (and, of course, without the digest field it is about to be given). If the receipt
    # is not bound, two DIFFERENT receipts for one (identity, from, to) collide: the second
    # is answered `:already_recorded` with the FIRST receipt's event, and a swapped
    # receipt_digest on disk (the value a dependent's upstream receipt edge is read from)
    # is invisible to any re-derivation of the event digest.
    refute SemanticJira.digest(Map.drop(tampered, ~w(seq event_digest))) == event["event_digest"],
           "event_digest does not bind receipt_digest (SemanticJira.digest/1 drops it)"
  end

  # -- the log is a trust root: an event that does not re-derive must not count -------

  test "a hand-written ALIVE event with a bogus event_digest cannot mint a dependent's receipt edge",
       ctx do
    bogus = "sha256:" <> String.duplicate("a", 64)

    forged = %{
      "kind" => "standing_transition_event",
      "identity" => "FIX-BROKEN",
      "definition_digest" => bogus,
      "snapshot_digest" => bogus,
      "from" => "UNKNOWN",
      "to" => "ALIVE",
      "receipt_digest" => bogus,
      "transition_digest" => bogus,
      "authority" => "NONE",
      "event_digest" => bogus,
      "seq" => 1
    }

    File.mkdir_p!(ctx.dir)
    File.write!(Path.join(ctx.dir, "00000001-aaaaaaaaaaaaaaaa.json"), Jason.encode!(forged))

    # the derivation rule the log itself applies on append
    refute forged["event_digest"] == SemanticJira.digest(Map.drop(forged, ~w(seq event_digest)))

    dependent_opts =
      Keyword.put(
        ctx.opts,
        :court_map,
        F.court_map("VERIFY-CLEAN", "verify.sh::verified_marker", "verify.sh::broken_absent")
      )

    result =
      try do
        {:frontier, Bridge.frontier(ctx.graph, ctx.dir).eligible,
         Bridge.descriptor(ctx.graph, ctx.dir, "VERIFY-CLEAN", dependent_opts)}
      rescue
        exception -> {:raised, exception}
      end

    assert match?({:frontier, [], {:error, {:refused_bridge, _}}}, result),
           "a forged, non-deriving log event steered the graph: #{inspect(result, limit: 6)}"
  end
end
