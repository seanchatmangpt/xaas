defmodule Xaas.Ultracode.RunValidationTest do
  @moduledoc """
  The results-validation law's court, exercised both ways.

  Positive control: a spec-exact 3-epoch log (passed / failed / refused)
  validates. Negative controls: every way a log can lie -- a stuck epoch
  with no terminal receipt, a capacity breach, a receipt_closed for an
  epoch that was never claimed, a structurally-valid log for the WRONG
  run -- fails WITH the offending epoch id named in the violations. The
  law under test is `Xaas.Ultracode.RunValidation.validate/2`'s
  moduledoc contract; these tests are pure (no DB, no mocking -- the
  module under test has neither a database nor a collaborator).
  """

  use ExUnit.Case, async: true

  @moduletag :ultracode

  alias Xaas.Ultracode.RunValidation

  @run "run-1111"

  # ---- log fixture builders (spec-exact Xaas.Ocel.Projection shape) ----

  defp ocel_log(events, objects) do
    %{
      "objectTypes" => objects |> Enum.map(& &1["type"]) |> Enum.uniq(),
      "eventTypes" => events |> Enum.map(& &1["type"]) |> Enum.uniq(),
      "objects" => objects,
      "events" => events
    }
  end

  defp epoch_object(id), do: %{"id" => id, "type" => "epoch"}
  defp run_object(id), do: %{"id" => id, "type" => "run"}

  defp event(id, type, iso_time, attributes, relationships) do
    %{
      "id" => id,
      "type" => type,
      "time" => iso_time,
      "attributes" => attributes,
      "relationships" => relationships
    }
  end

  defp epoch_rel(epoch_id), do: %{"objectId" => epoch_id, "qualifier" => "epoch"}
  defp run_rel(run_id), do: %{"objectId" => run_id, "qualifier" => "run"}

  defp claimed(epoch_id, at, id \\ nil) do
    event(
      id || "claim-#{epoch_id}",
      "epoch_claimed",
      at,
      %{"epoch_id" => epoch_id, "run_id" => @run, "worker" => "w-#{epoch_id}"},
      [epoch_rel(epoch_id), run_rel(@run)]
    )
  end

  defp closed(epoch_id, verification, at, id \\ nil) do
    event(
      id || "close-#{epoch_id}",
      "receipt_closed",
      at,
      %{"epoch_id" => epoch_id, "run_id" => @run, "verification" => verification},
      [epoch_rel(epoch_id), run_rel(@run)]
    )
  end

  defp minute(n) do
    base = ~U[2026-09-19T00:00:00Z]
    DateTime.to_iso8601(DateTime.add(base, n * 60, :second))
  end

  # A lawful 3-epoch run: one verified passed, one verified failed, one
  # refused -- sequential, so capacity is never stressed.
  defp three_epoch_log do
    events = [
      claimed("ep-0", minute(0)),
      closed("ep-0", "passed", minute(10)),
      claimed("ep-1", minute(20)),
      closed("ep-1", "failed", minute(30)),
      claimed("ep-2", minute(40)),
      closed("ep-2", "refused", minute(50))
    ]

    ocel_log(events, [
      run_object(@run),
      epoch_object("ep-0"),
      epoch_object("ep-1"),
      epoch_object("ep-2")
    ])
  end

  # ---- positive control ------------------------------------------------

  test "a spec-exact 3-epoch run (passed, failed, refused) is validated" do
    result = RunValidation.validate(three_epoch_log(), run_id: @run)

    assert result.verdict == :validated
    assert result.violations == []
    assert result.conformance == :ok
    assert result.max_in_flight == 1
    assert map_size(result.epochs) == 3

    assert result.epochs["ep-0"] == %{
             claimed_at: minute(0),
             terminal: %{event_id: "close-ep-0", verification: "passed"}
           }

    assert result.epochs["ep-1"].terminal.verification == "failed"
    assert result.epochs["ep-2"].terminal.verification == "refused"
  end

  test "validation is stable against the same log loaded from a path" do
    path = Path.join(System.tmp_dir!(), "run_validation_positive_#{System.unique_integer()}.json")
    File.write!(path, Jason.encode!(three_epoch_log()))

    on_exit(fn -> File.rm(path) end)

    assert RunValidation.validate_run(@run, path).verdict == :validated
  end

  test "five concurrent workers are within the capacity law; the check is the run's own knob" do
    claims = Enum.map(0..4, fn i -> claimed("ep-#{i}", minute(0), "claim-#{i}") end)
    closes = Enum.map(0..4, fn i -> closed("ep-#{i}", "passed", minute(30), "close-#{i}") end)
    objects = [run_object(@run)] ++ Enum.map(0..4, &epoch_object("ep-#{&1}"))
    log = ocel_log(claims ++ closes, objects)

    assert RunValidation.validate(log, run_id: @run).verdict == :validated

    # The same shape judged against a tighter capacity law of 1 breaches.
    result = RunValidation.validate(log, run_id: @run, capacity: 1)
    assert result.verdict == :not_validated
    assert [%{code: :capacity_breach, message: msg}] = result.violations
    assert msg =~ "5 workers in flight"
  end

  # ---- negative control 1: a stuck epoch (missing terminal) ------------

  test "a log missing one epoch's terminal event is not_validated naming that epoch" do
    log = three_epoch_log()
    [claim0, close0, claim1, close1, claim2, _close2] = log["events"]

    # ep-2 keeps its claim but loses its receipt_closed.
    log =
      ocel_log(
        [claim0, close0, claim1, close1, claim2],
        [run_object(@run), epoch_object("ep-0"), epoch_object("ep-1"), epoch_object("ep-2")]
      )

    result = RunValidation.validate(log, run_id: @run)

    assert result.verdict == :not_validated
    assert [%{code: :missing_terminal, epoch_id: "ep-2", message: msg}] = result.violations
    assert msg =~ "ep-2"
    assert msg =~ "stuck"
  end

  # ---- negative control 2: capacity breach ------------------------------

  test "6 workers in flight at one instant is not_validated with a capacity_breach" do
    claims = Enum.map(0..5, fn i -> claimed("ep-#{i}", minute(0), "claim-#{i}") end)
    closes = Enum.map(0..5, fn i -> closed("ep-#{i}", "passed", minute(30), "close-#{i}") end)
    objects = [run_object(@run)] ++ Enum.map(0..5, &epoch_object("ep-#{&1}"))

    result = RunValidation.validate(ocel_log(claims ++ closes, objects), run_id: @run)

    assert result.verdict == :not_validated

    assert [%{code: :capacity_breach, epoch_id: nil, message: msg}] = result.violations
    assert msg =~ "6 workers in flight"
    assert msg =~ "at most 5"
  end

  # ---- negative control 3: receipt_closed for a never-claimed epoch -----

  test "a receipt_closed referencing an epoch never claimed is not_validated naming it" do
    # ep-ghost is a declared epoch object that only ever appears through a
    # receipt_closed -- no epoch_claimed anywhere in the log.
    events = [
      claimed("ep-0", minute(0)),
      closed("ep-0", "passed", minute(10)),
      closed("ep-ghost", "passed", minute(20), "close-ghost")
    ]

    log = ocel_log(events, [run_object(@run), epoch_object("ep-0"), epoch_object("ep-ghost")])

    result = RunValidation.validate(log, run_id: @run)

    assert result.verdict == :not_validated

    assert [%{code: :unclaimed_receipt_closed, epoch_id: "ep-ghost", message: msg}] =
             result.violations

    assert msg =~ "ep-ghost"
    assert msg =~ "never claimed"
  end

  # ---- negative control 4: structurally-valid log for the WRONG run -----

  test "a structurally-valid log for a different run id is not_validated" do
    events =
      Enum.map(three_epoch_log()["events"], fn event ->
        %{
          event
          | "attributes" => Map.put(event["attributes"], "run_id", "run-9999"),
            "relationships" => [epoch_rel(event["attributes"]["epoch_id"]), run_rel("run-9999")]
        }
      end)

    log =
      ocel_log(events, [
        run_object("run-9999"),
        epoch_object("ep-0"),
        epoch_object("ep-1"),
        epoch_object("ep-2")
      ])

    result = RunValidation.validate(log, run_id: @run)

    assert result.verdict == :not_validated

    assert result.conformance == :ok,
           "the log IS structurally conformant -- it is for the wrong run"

    assert [%{code: :wrong_run, message: msg}] = result.violations
    assert msg =~ "run-9999"
    assert msg =~ @run
  end

  # ---- further semantic negatives ---------------------------------------

  test "two terminal events for one epoch is a duplicate_terminal naming the epoch" do
    events = [
      claimed("ep-0", minute(0)),
      closed("ep-0", "passed", minute(10), "close-a"),
      closed("ep-0", "passed", minute(20), "close-b")
    ]

    log = ocel_log(events, [run_object(@run), epoch_object("ep-0")])

    assert [%{code: :duplicate_terminal, epoch_id: "ep-0"}] =
             RunValidation.validate(log).violations
  end

  test "two claims for one epoch is a duplicate_claim naming the epoch" do
    events = [
      claimed("ep-0", minute(0), "claim-a"),
      claimed("ep-0", minute(5), "claim-b"),
      closed("ep-0", "refused", minute(10))
    ]

    log = ocel_log(events, [run_object(@run), epoch_object("ep-0")])

    assert [%{code: :duplicate_claim, epoch_id: "ep-0"}] = RunValidation.validate(log).violations
  end

  test "a receipt_closed whose verification is not passed/failed/refused is not terminal evidence" do
    events = [
      claimed("ep-0", minute(0)),
      closed("ep-0", "pending", minute(10))
    ]

    log = ocel_log(events, [run_object(@run), epoch_object("ep-0")])

    violations = RunValidation.validate(log).violations

    # The epoch is ALSO stuck (a "pending" receipt is no terminal), so
    # both facts are named; the invalid_verification one carries the
    # offending event id and value.
    assert Enum.any?(violations, fn
             %{
               code: :invalid_verification,
               epoch_id: "ep-0",
               event_id: "close-ep-0",
               message: msg
             } ->
               msg =~ "pending"

             _other ->
               false
           end)

    assert Enum.any?(violations, &match?(%{code: :missing_terminal, epoch_id: "ep-0"}, &1))
  end

  test "a terminal event predating its claim is a violation naming the epoch" do
    events = [
      claimed("ep-0", minute(10)),
      closed("ep-0", "passed", minute(5))
    ]

    log = ocel_log(events, [run_object(@run), epoch_object("ep-0")])

    assert [%{code: :terminal_before_claim, epoch_id: "ep-0"}] =
             RunValidation.validate(log).violations
  end

  test "a claimed epoch with no terminal keeps its worker slot (counts as in flight)" do
    # ep-0 is claimed and never closes; ep-1 is claimed 10 minutes later.
    # Both intervals overlap from minute(10) on -> 2 in flight.
    events = [
      claimed("ep-0", minute(0)),
      claimed("ep-1", minute(10)),
      closed("ep-1", "passed", minute(20))
    ]

    log = ocel_log(events, [run_object(@run), epoch_object("ep-0"), epoch_object("ep-1")])

    result = RunValidation.validate(log, capacity: 1)

    assert result.max_in_flight == 2
    assert result.verdict == :not_validated
    assert Enum.any?(result.violations, &match?(%{code: :capacity_breach}, &1))
  end

  test "an epoch object declared but entirely absent from events is a missing_claim" do
    events = [
      claimed("ep-0", minute(0)),
      closed("ep-0", "passed", minute(10))
    ]

    log = ocel_log(events, [run_object(@run), epoch_object("ep-0"), epoch_object("ep-silent")])

    assert [%{code: :missing_claim, epoch_id: "ep-silent", message: msg}] =
             RunValidation.validate(log).violations

    assert msg =~ "ep-silent"
  end

  # ---- structural conformance negatives ---------------------------------

  test "a log missing a required top-level collection fails conformance" do
    log = Map.delete(three_epoch_log(), "objects")

    result = RunValidation.validate(log, run_id: @run)

    assert result.verdict == :not_validated
    assert result.conformance == :failed

    # The objects collection is gone, so EVERY event-to-object
    # relationship dangles too -- but the missing collection itself is
    # named first, before the per-relationship cascade.
    assert [
             %{code: :missing_collection, message: msg} | _rest
           ] = result.violations

    assert msg =~ "\"objects\""
  end

  test "a relationship to an undeclared object fails conformance" do
    events = [
      claimed("ep-0", minute(0)),
      closed("ep-0", "passed", minute(10))
    ]

    log = ocel_log(events, [run_object(@run)])

    # Both lifecycle events relate to the undeclared epoch object ep-0;
    # each dangling reference is named with its event id.
    assert [
             %{code: :dangling_relationship, event_id: "claim-ep-0", message: msg1},
             %{code: :dangling_relationship, event_id: "close-ep-0", message: msg2}
           ] = RunValidation.validate(log).violations

    assert msg1 =~ "ep-0"
    assert msg2 =~ "ep-0"
  end

  test "an event whose type is not declared fails conformance" do
    events = [
      claimed("ep-0", minute(0)),
      event("bogus-1", "epoch_teleported", minute(5), %{"epoch_id" => "ep-0"}, [epoch_rel("ep-0")]),
      closed("ep-0", "passed", minute(10))
    ]

    # Deliberate: the declared eventTypes do NOT include the bogus type
    # (an auto-declaring fixture would hide this check entirely).
    log = %{
      ocel_log(events, [run_object(@run), epoch_object("ep-0")])
      | "eventTypes" => ["epoch_claimed", "receipt_closed"]
    }

    assert [%{code: :undeclared_type, message: msg}] = RunValidation.validate(log).violations
    assert msg =~ "epoch_teleported"
  end

  test "a duplicate event id fails conformance" do
    events = [
      claimed("ep-0", minute(0), "dup"),
      closed("ep-0", "passed", minute(10), "dup")
    ]

    log = ocel_log(events, [run_object(@run), epoch_object("ep-0")])

    assert [%{code: :duplicate_id, event_id: "dup"}] = RunValidation.validate(log).violations
  end

  test "an unparseable event time fails conformance" do
    events = [%{claimed("ep-0", minute(0)) | "time" => "not-a-time"}]
    log = ocel_log(events, [run_object(@run), epoch_object("ep-0")])

    # The malformed event is dropped from the judged set, so the epoch it
    # would have claimed also legitimately cascades to missing_claim.
    assert [%{code: :malformed_event, message: msg}, %{code: :missing_claim, epoch_id: "ep-0"}] =
             RunValidation.validate(log).violations

    assert msg =~ "ISO8601"
  end

  test "a claimed lifecycle event binding to no epoch is unattributable" do
    events = [
      event("claim-mystery", "epoch_claimed", minute(0), %{"run_id" => @run}, [run_rel(@run)])
    ]

    log = ocel_log(events, [run_object(@run)])

    assert [%{code: :unattributable_event, event_id: "claim-mystery"}] =
             RunValidation.validate(log).violations
  end

  test "a log path that does not exist is not_validated (log_unreadable), not a crash" do
    result = RunValidation.validate("/nonexistent/path.ocel.json")

    assert result.verdict == :not_validated
    assert [%{code: :log_unreadable}] = result.violations
  end

  test "binding via relationships alone (no epoch_id attributes) still accounts the epochs" do
    # Emitter-alternative shape: epoch binding carried ONLY by the
    # relationship to the epoch-type object (attributes keep run_id and
    # verification, but no epoch_id).
    bare_claimed = %{
      claimed("ep-0", minute(0))
      | "attributes" => %{"run_id" => @run},
        "relationships" => [epoch_rel("ep-0"), run_rel(@run)]
    }

    bare_closed = %{
      closed("ep-0", "failed", minute(10))
      | "attributes" => %{"run_id" => @run, "verification" => "failed"},
        "relationships" => [epoch_rel("ep-0"), run_rel(@run)]
    }

    log = ocel_log([bare_claimed, bare_closed], [run_object(@run), epoch_object("ep-0")])

    result = RunValidation.validate(log, run_id: @run)
    assert result.verdict == :validated
    assert result.epochs["ep-0"].terminal.verification == "failed"
  end
end
