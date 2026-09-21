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
             appearance_type: "epoch_claimed",
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

  # ---- receipt-vocabulary law: heartbeats are NON-STANDING --------------
  # `heartbeat_recorded` is the OCEL egress's event for the typed
  # non-standing `:heartbeat` Receipt class (Run-tick lifecycle/liveness
  # records). It is deliberately absent from this module's claim, terminal,
  # and verification vocabularies: a heartbeat can never close an epoch,
  # never hold or free a capacity slot, and never be promoted into terminal
  # evidence by carrying a "verification" attribute.

  defp heartbeat(epoch_id, at, attributes \\ %{}) do
    event(
      "hb-#{epoch_id}",
      "heartbeat_recorded",
      at,
      Map.merge(
        %{"epoch_id" => epoch_id, "run_id" => @run, "outcome" => "heartbeat"},
        attributes
      ),
      [epoch_rel(epoch_id), run_rel(@run)]
    )
  end

  test "a claimed epoch whose only receipt is a heartbeat_recorded is still missing_terminal" do
    log =
      ocel_log(
        [claimed("ep-0", minute(0)), heartbeat("ep-0", minute(5))],
        [run_object(@run), epoch_object("ep-0")]
      )

    result = RunValidation.validate(log, run_id: @run)

    assert result.verdict == :not_validated
    assert [%{code: :missing_terminal, epoch_id: "ep-0", message: msg}] = result.violations
    assert msg =~ "stuck"
  end

  test "a heartbeat_recorded with a 'verification' attribute is still not terminal evidence" do
    log =
      ocel_log(
        [claimed("ep-0", minute(0)), heartbeat("ep-0", minute(5), %{"verification" => "passed"})],
        [run_object(@run), epoch_object("ep-0")]
      )

    result = RunValidation.validate(log, run_id: @run)

    assert result.verdict == :not_validated
    assert [%{code: :missing_terminal, epoch_id: "ep-0"}] = result.violations
  end

  test "a heartbeat alongside a real claim and verified terminal disturbs nothing" do
    events = [
      claimed("ep-0", minute(0)),
      heartbeat("ep-0", minute(5)),
      closed("ep-0", "passed", minute(10))
    ]

    log = ocel_log(events, [run_object(@run), epoch_object("ep-0")])

    result = RunValidation.validate(log, run_id: @run)

    assert result.verdict == :validated
    assert result.violations == []
    assert result.max_in_flight == 1

    # The heartbeat is invisible to the per-epoch accounting: the epoch's
    # appearance is its claim and its terminal is the receipt_closed.
    assert result.epochs["ep-0"].appearance_type == "epoch_claimed"
    assert result.epochs["ep-0"].terminal.verification == "passed"
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

    # The court is the structural authority; its non-cascading policy
    # names the missing collection as THE violation (dependent checks
    # are inadmissible, not piled on).
    assert [%{code: :court_violation, message: msg}] = result.violations

    assert msg =~ "ocel:objects"
  end

  test "a relationship to an undeclared object fails conformance" do
    events = [
      claimed("ep-0", minute(0)),
      closed("ep-0", "passed", minute(10))
    ]

    log = ocel_log(events, [run_object(@run)])

    # Both lifecycle events relate to the undeclared epoch object ep-0;
    # the court names each dangling reference and the bridge recovers
    # the offending event id from the violation's JSON path.
    assert [
             %{code: :court_violation, event_id: "claim-ep-0", message: msg1},
             %{code: :court_violation, event_id: "close-ep-0", message: msg2}
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

    assert [%{code: :court_violation, event_id: "bogus-1", message: msg}] =
             RunValidation.validate(log).violations

    assert msg =~ "epoch_teleported"
  end

  test "a duplicate event id fails conformance" do
    events = [
      claimed("ep-0", minute(0), "dup"),
      closed("ep-0", "passed", minute(10), "dup")
    ]

    log = ocel_log(events, [run_object(@run), epoch_object("ep-0")])

    assert [%{code: :court_violation, event_id: "dup"}] = RunValidation.validate(log).violations
  end

  test "an unparseable event time fails conformance" do
    events = [%{claimed("ep-0", minute(0)) | "time" => "not-a-time"}]
    log = ocel_log(events, [run_object(@run), epoch_object("ep-0")])

    # The court names the unparseable time on the event (its violation's
    # JSON path recovers the event id), and the malformed event is
    # dropped from the judged set, so the epoch it would have claimed
    # also legitimately cascades to missing_claim.
    assert [
             %{code: :court_violation, event_id: "claim-ep-0", message: msg},
             %{code: :missing_claim, epoch_id: "ep-0"}
           ] = RunValidation.validate(log).violations

    assert msg =~ "ocel:events"
    assert msg =~ "time"
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

  # ---- dialect absorption: Xaas.Ultracode.OcelEgress shape -------------

  # The egress (landed 2026-09-20) emits ocel:-prefixed keys, capitalized
  # object types, epoch_scheduled/epoch_started appearance facts
  # (epoch_claimed is declared but never emitted), and verification as
  # SIBLING EVENTS rather than a receipt_closed attribute.
  defp egress_shape_log do
    rel = fn id, type -> %{"objectId" => id, "qualifier" => String.downcase(type)} end

    epoch_event = fn id, type, time, epoch_id ->
      %{
        "id" => id,
        "type" => type,
        "time" => time,
        "attributes" => %{},
        "relationships" => [rel.(epoch_id, "Epoch"), rel.("run-1", "Run")]
      }
    end

    events =
      Enum.flat_map(["ep-a", "ep-b"], fn ep ->
        hour = if(ep == "ep-a", do: 0, else: 1)
        start_t = "2026-09-19T0#{hour}:00:00Z"
        close_t = "2026-09-19T0#{hour}:30:00Z"

        [
          epoch_event.("epoch_scheduled:#{ep}", "epoch_scheduled", start_t, ep),
          epoch_event.("epoch_started:#{ep}", "epoch_started", start_t, ep),
          epoch_event.("receipt_closed:#{ep}", "receipt_closed", close_t, ep),
          epoch_event.("verification_passed:#{ep}", "verification_passed", close_t, ep)
        ]
      end)

    %{
      "ocel:objectTypes" => Enum.map(["Run", "Epoch"], &%{"name" => &1}),
      "ocel:eventTypes" =>
        Enum.map(
          ["epoch_scheduled", "epoch_started", "receipt_closed", "verification_passed"],
          &%{"name" => &1}
        ),
      "ocel:objects" => [
        %{"id" => "run-1", "type" => "Run", "attributes" => %{}},
        %{"id" => "ep-a", "type" => "Epoch", "attributes" => %{}},
        %{"id" => "ep-b", "type" => "Epoch", "attributes" => %{}}
      ],
      "ocel:events" => events
    }
  end

  test "an egress-shape log (ocel:-prefixed keys, Run/Epoch types, sibling verification) validates" do
    result = RunValidation.validate(egress_shape_log(), run_id: "run-1")

    assert result.verdict == :validated, "violations: #{inspect(result.violations)}"
    assert result.conformance == :ok
    assert result.epochs["ep-a"].claimed_at == "2026-09-19T00:00:00Z"
    # Priority order: epoch_started (a real worker moment) outranks
    # epoch_scheduled for slot-holding.
    assert result.epochs["ep-a"].appearance_type == "epoch_started"

    assert result.epochs["ep-a"].terminal == %{
             event_id: "receipt_closed:ep-a",
             verification: "verification_passed"
           }

    assert result.max_in_flight == 1
  end

  test "an egress-shape log with a stuck epoch (scheduled, never closed) is not_validated naming it" do
    log = egress_shape_log()

    log = %{
      log
      | "ocel:events" =>
          Enum.reject(log["ocel:events"], fn e ->
            e["id"] in ["receipt_closed:ep-b", "verification_passed:ep-b"]
          end)
    }

    result = RunValidation.validate(log, run_id: "run-1")

    assert result.verdict == :not_validated
    assert [%{code: :missing_terminal, epoch_id: "ep-b", message: msg}] = result.violations
    assert msg =~ "stuck"
  end

  test "an egress receipt_closed with a sibling verification is terminal; without one it is not" do
    log = egress_shape_log()

    # Drop ONLY the verification_passed sibling for ep-a: its
    # receipt_closed now has no verification attribute and no sibling ->
    # stuck, not receipt-accounted.
    log = %{
      log
      | "ocel:events" =>
          Enum.reject(log["ocel:events"], &(&1["id"] == "verification_passed:ep-a"))
    }

    result = RunValidation.validate(log, run_id: "run-1")

    assert result.verdict == :not_validated
    assert Enum.any?(result.violations, &match?(%{code: :missing_terminal, epoch_id: "ep-a"}, &1))
  end

  # ------------------------------------------------------------------
  # Per-repo capacity accounting (--per-repo-capacity)
  # ------------------------------------------------------------------

  defp repo_rel(repo), do: %{"objectId" => repo, "qualifier" => "repo"}
  defp repo_object(id), do: %{"id" => id, "type" => "Repo"}

  defp claimed_on_repo(epoch_id, repo, at),
    do: Map.update(claimed(epoch_id, at), "relationships", [], &(&1 ++ [repo_rel(repo)]))

  defp closed_on_repo(epoch_id, repo, verification, at),
    do:
      Map.update(
        closed(epoch_id, verification, at),
        "relationships",
        [],
        &(&1 ++ [repo_rel(repo)])
      )

  test "per-repo accounting: two repos each holding 2 slots is validated, and the per-repo maxima are reported" do
    events = [
      claimed_on_repo("ep-0", "repo-a", minute(0)),
      closed_on_repo("ep-0", "repo-a", "passed", minute(10)),
      claimed_on_repo("ep-1", "repo-a", minute(5)),
      closed_on_repo("ep-1", "repo-a", "failed", minute(15)),
      claimed_on_repo("ep-2", "repo-b", minute(0)),
      closed_on_repo("ep-2", "repo-b", "passed", minute(10)),
      claimed_on_repo("ep-3", "repo-b", minute(5)),
      closed_on_repo("ep-3", "repo-b", "refused", minute(15))
    ]

    log =
      ocel_log(events, [
        run_object(@run),
        epoch_object("ep-0"),
        epoch_object("ep-1"),
        epoch_object("ep-2"),
        epoch_object("ep-3"),
        repo_object("repo-a"),
        repo_object("repo-b")
      ])

    result = RunValidation.validate(log, run_id: @run, per_repo_capacity: 2)

    assert result.verdict == :validated
    assert result.violations == []
    # GLOBAL observed max is 4 (2 slots per repo at one instant) -- under
    # the default global capacity 5 this validates; the per-repo law sees
    # each repo's own 2.
    assert result.max_in_flight == 4
    assert result.per_repo_capacity == 2

    assert result.max_in_flight_per_repo == %{"repo-a" => 2, "repo-b" => 2}
  end

  test "per-repo breach: one repo exceeding ITS cap is not_validated naming that repo (global cap untouched)" do
    events = [
      claimed_on_repo("ep-0", "repo-a", minute(0)),
      closed_on_repo("ep-0", "repo-a", "passed", minute(20)),
      claimed_on_repo("ep-1", "repo-a", minute(5)),
      closed_on_repo("ep-1", "repo-a", "passed", minute(25)),
      claimed_on_repo("ep-2", "repo-a", minute(10)),
      closed_on_repo("ep-2", "repo-a", "passed", minute(30)),
      claimed_on_repo("ep-3", "repo-b", minute(0)),
      closed_on_repo("ep-3", "repo-b", "passed", minute(10))
    ]

    log =
      ocel_log(events, [
        run_object(@run),
        epoch_object("ep-0"),
        epoch_object("ep-1"),
        epoch_object("ep-2"),
        epoch_object("ep-3"),
        repo_object("repo-a"),
        repo_object("repo-b")
      ])

    result = RunValidation.validate(log, run_id: @run, per_repo_capacity: 2)

    assert result.verdict == :not_validated

    # 3 concurrent on repo-a breaches the per-repo cap of 2; the breach
    # NAMES the repo. The global law (5) is nowhere near breached (3 in
    # flight) -- this violation is the per-repo law's own catch.
    assert [
             %{code: :per_repo_capacity_breach, repo: "repo-a", epoch_id: nil, message: msg}
           ] = result.violations

    assert msg =~ "repo-a"
    assert msg =~ "3 workers in flight"
    assert msg =~ "at most 2"
  end

  test "per-repo mode still enforces the GLOBAL capacity law on top" do
    # Six epochs in flight at one instant, split 3+3 across two repos:
    # each repo is deep under its per-repo cap of 10, but the run's own
    # global capacity (5) is breached -- per-repo is a refinement, never
    # a relaxation.
    events =
      Enum.flat_map(0..5, fn i ->
        repo = if rem(i, 2) == 0, do: "repo-a", else: "repo-b"

        [
          claimed_on_repo("ep-#{i}", repo, minute(0)),
          closed_on_repo("ep-#{i}", repo, "passed", minute(30))
        ]
      end)

    log =
      ocel_log(
        events,
        [
          run_object(@run)
        ] ++
          Enum.map(0..5, &epoch_object("ep-#{&1}")) ++
          [repo_object("repo-a"), repo_object("repo-b")]
      )

    result = RunValidation.validate(log, run_id: @run, per_repo_capacity: 10)

    assert result.verdict == :not_validated
    assert [%{code: :capacity_breach, message: msg}] = result.violations
    assert msg =~ "6 workers in flight"
    assert msg =~ "at most 5"
  end

  test "per-repo mode with an alias-less log is a TYPED REFUSAL naming every unattributable epoch" do
    # The existing single-repo fixture binds no repo anywhere: per-repo
    # accounting cannot be manufactured for it, so the law refuses.
    result = RunValidation.validate(three_epoch_log(), run_id: @run, per_repo_capacity: 2)

    assert result.verdict == :not_validated

    refusals = Enum.filter(result.violations, &(&1.code == :repo_unattributable))

    assert Enum.map(refusals, & &1.epoch_id) == ["ep-0", "ep-1", "ep-2"]

    for refusal <- refusals do
      assert refusal.message =~ "REFUSED_PER_REPO_CAPACITY_NO_REPO_ALIAS"
      assert refusal.message =~ "binds no repo"
    end

    # No per-repo maxima are fabricated for unattributable epochs.
    assert result.max_in_flight_per_repo == %{}
  end

  test "per-repo mode is opt-in: the same alias-less log validates without the flag and reports nil" do
    result = RunValidation.validate(three_epoch_log(), run_id: @run)

    assert result.verdict == :validated
    assert result.max_in_flight_per_repo == nil
    assert result.per_repo_capacity == nil
  end

  test "per-repo mode: one bound and one unbound epoch refuses only the unbound one, and still accounts the bound repo" do
    events = [
      claimed_on_repo("ep-0", "repo-a", minute(0)),
      closed_on_repo("ep-0", "repo-a", "passed", minute(10)),
      claimed("ep-1", minute(0)),
      closed("ep-1", "passed", minute(10))
    ]

    log =
      ocel_log(events, [
        run_object(@run),
        epoch_object("ep-0"),
        epoch_object("ep-1"),
        repo_object("repo-a")
      ])

    result = RunValidation.validate(log, run_id: @run, per_repo_capacity: 1)

    assert result.verdict == :not_validated

    refusals = Enum.filter(result.violations, &(&1.code == :repo_unattributable))
    assert [%{epoch_id: "ep-1"}] = refusals

    # The bound repo's accounting is not suppressed by the refusal.
    assert result.max_in_flight_per_repo == %{"repo-a" => 1}

    refute Enum.any?(result.violations, &(&1.code == :per_repo_capacity_breach))
  end
end
