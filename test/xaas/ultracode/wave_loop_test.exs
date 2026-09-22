defmodule Xaas.Ultracode.WaveLoopTest do
  use Xaas.DataCase, async: false

  @moduledoc """
  Qualification of the fabric-native wave loop
  (`Xaas.Ultracode.WaveLoop` + the hourly `:wave_loop` schedule on
  `Xaas.Ultracode.Run`).

  Chicago-style boundaries, no LLM anywhere:

    * the STATE parser (`Xaas.Ultracode.WaveLoop.State`) -- well-formed
      tables, the REMAINING-note dependency chain, `BLOCKED-ON-` row deps,
      section extraction, and every malformed shape as a TYPED refusal
      (never a crash, never a guess);
    * first-actionable selection -- dependency order honored, a DONE row
      re-opened by the note, waiting states named;
    * tick outcomes against REAL Postgres rows (Run/Epoch/Lease/Receipt):
      completion no-op, typed refusal on a corrupted STATE, busy slot on a
      live lease, stale-lease reap, the unclosed-worker BLOCKED path, and
      the success path where the STATE row advances and the note shrinks;
    * dispatch wiring with a REAL `Xaas.Ultracode.Dispatch` and a REAL
      scripted CLI subprocess (the hermetic stand-in for the model's
      judgment, exactly like `DispatchTest`/`AutonomicTest`), proving the
      loop's goal construction and the boundary call;
    * schedule registration -- AshOban REALLY merges the hourly crontab
      entry, the worker is bound to the single-slot `:ultracode_wave_loop`
      queue with incomplete-job uniqueness (the ULTRACODE-50 failure mode:
      schedules that existed in the DSL but never reached the running
      crontab);
    * the `:wave_loop` action's runner seam and its `:oban_scheduler`
      authority (full policy calculus in SystemActorChicagoTest).
  """

  require Ash.Query

  alias Xaas.Ultracode.{Epoch, Lease, Receipt, Run}
  alias Xaas.Ultracode.WaveLoop
  alias Xaas.Ultracode.WaveLoop.State

  # A miniature of the real loop STATE file: the same table shape, the
  # same REMAINING-note chain (after-deps on the first listed step, then a
  # sequential chain), a re-opened DONE row (step 8), a `BLOCKED-ON-` row
  # dep (step 7), and the (a)/(c) sections the worker goal carries.
  @state """
  # W9 LOOP STATE — the hourly runner's executable plan

  **How the hourly runner uses this file (each tick):** read top to bottom.

  ---

  ## (a) CURRENT standing (as of generation — always re-verify)

  | surface | state at snapshot | evidence |
  |---|---|---|
  | xaas branch | `feat/ultracode-cron-wave` @ origin tip `abc1234` | `git fetch` exit 0 |

  ---

  ## (b) STEP LIST

  ### [3] Branch integrations
  - **description:** Integrate landed wave branches into
    `feat/ultracode-cron-wave`, then push (fast-forward only).
  - **dispatch:** agent role W8-A3. ONE integration checkout, ONE `--no-ff`
    merge per run, serialized: clean and writer-free, `mix test` gated.
  - **depends on:** nothing. **status:** pending
  - **DONE evidence:** _(fill: merge SHAs, test exit, push result)_

  ### [4] Sole-source fold
  - **description:** Fold the crown chain to a single source.

  ---

  ## (c) THE LAW (non-negotiable — every agent and the runner)

  1. **Collisions are fine.** Never force-push. **Never touch main**.
  2. **Evidence law:** every claim carries command + exit code.

  ---

  ## WAVE RESULT (coordinator update — statuses here are canonical)

  | step | status | evidence |
  |---|---|---|
  | 1 court-receipt producer | DONE | xaas `6a9efad` |
  | 2 crown v2 stages 7-8 | DONE | CROWN V2 CLOSED |
  | 3 branch integrations | PENDING — do next | ggen: merge `ultracode/w7-crown2` |
  | 4 sole-source fold | PENDING — not started | audit pending |
  | 7 campaign launch | READY-BLOCKED-ON-3 | §10 handoff |
  | 8 OCEL sweep | DONE | 15/15 VALIDATED (pre-merge sweep) |

  REMAINING after 3+4: step 7 launch, then step 8 re-sweep post-merge. Then COMPLETE.
  """

  # ------------------------------------------------------------------
  # STATE parsing
  # ------------------------------------------------------------------

  describe "State.parse" do
    test "parses the step table, statuses, dep chain, and sections" do
      assert {:ok, state} = State.parse(@state)

      ids = Enum.map(state.steps, & &1.id)
      assert ids == ["1", "2", "3", "4", "7", "8"]

      s3 = fetch_step(state, "3")
      assert s3.status == :pending
      assert s3.deps == []

      # step 7: the note's after-deps [3, 4] UNION the row's BLOCKED-ON-3.
      s7 = fetch_step(state, "7")
      assert s7.status == :blocked
      assert Enum.sort(s7.deps) == ["3", "4"]

      # step 8: chain dep on its predecessor (7).
      s8 = fetch_step(state, "8")
      assert s8.status == :done
      assert s8.deps == ["7"]

      # Verbatim sections feed the worker goal.
      assert state.sections["3"] =~ "agent role W8-A3"
      assert state.sections["3"] =~ "ONE `--no-ff`"
      assert state.standing =~ "CURRENT standing"
      assert state.law =~ "Evidence law"
      assert state.remaining_note =~ "REMAINING after 3+4"

      refute State.complete?(state)
    end

    test "no REMAINING note parses as an empty chain" do
      raw = """
      | step | status | evidence |
      |---|---|---|
      | 1 only step | DONE | ok |
      """

      assert {:ok, state} = State.parse(raw)
      assert state.remaining_chain == %{}
      assert State.complete?(state)
    end

    test "malformed: no step table is a typed refusal" do
      assert {:error, {:malformed_state, :no_step_table}} = State.parse("# nothing here\n")
    end

    test "malformed: empty table is a typed refusal" do
      raw = "| step | status | evidence |\n|---|---|---|\n"
      assert {:error, {:malformed_state, :empty_step_table}} = State.parse(raw)
    end

    test "malformed: unknown status is a typed refusal, never a guess" do
      raw = table_row("1 mystery step", "IN LIMBO", "evidence")
      assert {:error, {:malformed_state, {:unknown_status, "1", "IN LIMBO"}}} = State.parse(raw)
    end

    test "malformed: header with no rows is a typed refusal" do
      raw = "| step | status | evidence |\n|---|---|---|\nno pipes at all\n"
      assert {:error, {:malformed_state, :empty_step_table}} = State.parse(raw)
    end

    test "malformed: a two-cell row whose first cell is not an id is a typed refusal" do
      raw = "| step | status | evidence |\n|---|---|---|\n| only | two |\n"

      assert {:error, {:malformed_state, {:bad_step_row, "only"}}} = State.parse(raw)
    end

    test "a two-cell row (coordinator's omitted empty evidence cell) parses with empty evidence" do
      # Live failed edge, telemetry tick 1 (2026-09-21): the real STATE's
      # row 4 shipped as `| 4 sole-source fold | PENDING — not started |`.
      # That is id+name+status with EMPTY evidence -- parsed, never guessed.
      raw =
        "| step | status | evidence |\n|---|---|---|\n| 4 sole-source fold | PENDING — not started (#19/#23 audit) |\n"

      assert {:ok, state} = State.parse(raw)
      s4 = fetch_step(state, "4")
      assert s4.status == :pending
      assert s4.evidence == ""
      assert {:ok, %{id: "4"}} = State.first_actionable(state)

      # Rendering normalizes it to the three-cell grammar and evidence
      # appends land in the previously-missing cell.
      assert {:ok, updated} = State.set_row(raw, "4", "DONE", "receipt exit=0")
      {:ok, state2} = State.parse(updated)
      assert fetch_step(state2, "4").status == :done
      assert fetch_step(state2, "4").evidence == "receipt exit=0"
      assert updated =~ "| 4 sole-source fold | DONE | receipt exit=0 |"
    end

    test "malformed: a one-cell row is still a typed refusal" do
      raw = "| step | status | evidence |\n|---|---|---|\n| 4 sole-source fold |\n"

      assert {:error, {:malformed_state, {:short_step_row, ["4 sole-source fold"]}}} =
               State.parse(raw)
    end

    test "malformed: note naming an unknown step is a typed refusal" do
      raw = table_row("1 a", "DONE", "e") <> "\nREMAINING: step 9 ghost. Then COMPLETE."
      assert {:error, {:malformed_state, {:remaining_unknown_step, ["9"]}}} = State.parse(raw)
    end

    test "malformed: note with unknown after-deps is a typed refusal" do
      raw = table_row("1 a", "PENDING", "e") <> "\nREMAINING after 9: step 1 x. Then COMPLETE."
      assert {:error, {:malformed_state, {:unknown_dep, ["9"]}}} = State.parse(raw)
    end

    test "escaped pipes round-trip through parse and set_row" do
      raw = table_row("1 a", "PENDING", "see x \\| y docs")

      assert {:ok, state} = State.parse(raw)
      assert fetch_step(state, "1").evidence == "see x | y docs"

      assert {:ok, updated} = State.set_row(raw, "1", "DONE", nil)
      assert {:ok, state2} = State.parse(updated)
      assert fetch_step(state2, "1").evidence == "see x | y docs"
      assert fetch_step(state2, "1").status == :done
    end
  end

  describe "State.first_actionable" do
    test "picks the first owing step with satisfied deps (table order)" do
      {:ok, state} = State.parse(@state)
      assert {:ok, step} = State.first_actionable(state)
      assert step.id == "3"
    end

    test "deps gate selection: a blocked dep that is not done yields a waiting verdict" do
      # First owing step is 1 (blocked on 2, which is still pending).
      state_waiting =
        table([
          row("1 a", "READY-BLOCKED-ON-2", "e"),
          row("2 b", "PENDING", "e")
        ])
        |> State.parse()
        |> elem(1)

      assert {:waiting, %{id: "1"}, ["2"]} = State.first_actionable(state_waiting)

      # The same blocked step is actionable once its dep is DONE.
      state_ready =
        table([
          row("1 a", "DONE", "e"),
          row("2 b", "READY-BLOCKED-ON-1", "e")
        ])
        |> State.parse()
        |> elem(1)

      assert {:ok, %{id: "2"}} = State.first_actionable(state_ready)
    end

    test "a note re-open makes the DONE row itself first actionable" do
      raw =
        table([
          row("1 a", "DONE", "e"),
          row("2 b", "READY-BLOCKED-ON-1", "e")
        ]) <>
          "\nREMAINING: step 1 re-audit. Then COMPLETE."

      state = raw |> State.parse() |> elem(1)

      # Step 1 is re-opened by the note, so IT owes work again -- and it is
      # first in table order, ahead of step 2.
      assert {:ok, %{id: "1"}} = State.first_actionable(state)
    end

    test "exhausted table plus empty note is complete" do
      raw = table_row("1 a", "DONE", "e")
      assert {:ok, state} = State.parse(raw)
      assert State.first_actionable(state) == :complete
      assert State.complete?(state)
    end

    test "an explicit LOOP COMPLETE marker completes regardless of rows" do
      raw = table_row("1 a", "PENDING", "e") <> "\nLOOP COMPLETE 2026-09-21T00:00Z — down\n"

      {:ok, state} = State.parse(raw)
      assert State.complete?(state)
    end
  end

  describe "State rendering" do
    test "set_row respects a worker's own DONE wording and is idempotent" do
      {:ok, updated} =
        State.set_row(
          @state,
          "3",
          "DONE",
          "wave-loop tick 1: receipt epoch abc — exit=0 log=/t/l"
        )

      {:ok, state} = State.parse(updated)
      s3 = fetch_step(state, "3")
      assert s3.status == :done
      assert s3.status_raw == "DONE"
      assert s3.evidence =~ "wave-loop tick 1"
      # Everything else byte-identical.
      assert fetch_step(state, "1").evidence == "xaas `6a9efad`"

      # Idempotent: the same receipt token is not appended twice.
      {:ok, again} =
        State.set_row(
          updated,
          "3",
          "DONE",
          "wave-loop tick 1: receipt epoch abc — exit=0 log=/t/l"
        )

      assert again == updated
    end

    test "set_row never touches superseded tables elsewhere in the file" do
      raw =
        table_row("3 old branch step", "PENDING", "old") <>
          "\n\n## NEW\n\n" <> table_row("3 new branch step", "PENDING", "new")

      {:ok, updated} = State.set_row(raw, "3", "DONE", "receipt")
      assert updated =~ "| 3 old branch step | PENDING | old |"
      assert updated =~ "| 3 new branch step | DONE | new — receipt |"
    end

    test "remove_from_remaining is idempotent for unlisted steps and re-chains listed ones" do
      # Step 3 is table-pending but NOT note-listed: a no-op, unchanged.
      {:ok, unchanged} = State.remove_from_remaining(@state, "3")
      assert unchanged == @state

      # Removing note-listed step 7 makes step 8 the first listed, so it
      # inherits the after-deps and stays actionable despite its DONE row.
      {:ok, without_7} = State.remove_from_remaining(@state, "7")
      {:ok, state2} = State.parse(without_7)
      refute state2.remaining_note =~ "step 7"
      assert fetch_step(state2, "8").deps |> Enum.sort() == ["3", "4"]

      # With steps 3 and 4 done, step 7 (blocked, deps now satisfied) is
      # the first actionable step, ahead of the re-opened step 8.
      {:ok, ready} =
        without_7
        |> String.replace(
          "| 3 branch integrations | PENDING — do next |",
          "| 3 branch integrations | DONE |"
        )
        |> String.replace(
          "| 4 sole-source fold | PENDING — not started |",
          "| 4 sole-source fold | DONE |"
        )
        |> State.parse()

      assert {:ok, %{id: "7"}} = State.first_actionable(ready)

      # Removing 8 from the original note leaves 7 first (deps [3, 4]).
      {:ok, without_8} = State.remove_from_remaining(@state, "8")
      {:ok, state3} = State.parse(without_8)
      assert state3.remaining_note =~ "step 7"
      refute state3.remaining_note =~ "step 8"
      assert fetch_step(state3, "7").deps |> Enum.sort() == ["3", "4"]
    end

    test "append_complete_marker is visible to the parser" do
      marked = State.append_complete_marker(@state, "2026-09-21T05:00Z (abc12345)")
      {:ok, state} = State.parse(marked)
      assert state.complete_marker
      assert State.complete?(state)
    end

    test "build_goal carries the step verbatim, the standing, the law, and the update instruction" do
      {:ok, state} = State.parse(@state)

      goal =
        State.build_goal(state, fetch_step(state, "3"), %{
          state_path: "/s/STATE.md",
          telemetry_path: "/s/l.ndjson"
        })

      assert goal =~ "STEP 3: branch integrations"
      assert goal =~ "agent role W8-A3"
      assert goal =~ "ONE `--no-ff`"
      assert goal =~ "CURRENT STANDING"
      assert goal =~ "git fetch origin"
      assert goal =~ "THE LAW"
      assert goal =~ "every claim carries command + exit code"
      assert goal =~ "/s/STATE.md"
      assert goal =~ "/s/l.ndjson"
      assert goal =~ "ultracode-wave-loop/1"
      assert String.length(goal) < 50_000
    end
  end

  # ------------------------------------------------------------------
  # Ticks against real rows
  # ------------------------------------------------------------------

  describe "tick" do
    setup do
      # Xaas.DataCase owns LegacyRepo only; the ultracode surface runs on
      # Xaas.Repo -- the same explicit sandbox discipline DispatchTest uses.
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

      %{state_path: tmp_path("state", ".md"), telemetry_path: tmp_path("telemetry", ".ndjson")}
    end

    test "a complete STATE is a no-op that records telemetry and starts nothing", %{
      state_path: state_path,
      telemetry_path: telemetry_path
    } do
      File.write!(state_path, complete_state())

      assert {:ok, %{outcome: :complete, tick: 1, step: nil}} =
               WaveLoop.tick(
                 state_path: state_path,
                 telemetry_path: telemetry_path,
                 dispatcher: flunk_dispatcher()
               )

      assert [] == loop_runs()
      assert telemetry_lines(telemetry_path) =~ ~s("outcome":"complete")
    end

    test "a corrupted STATE is a typed refusal with telemetry, never a crash", %{
      state_path: state_path,
      telemetry_path: telemetry_path
    } do
      File.write!(state_path, "absolute garbage, no table")

      assert {:ok, %{outcome: :refused}} =
               WaveLoop.tick(
                 state_path: state_path,
                 telemetry_path: telemetry_path,
                 dispatcher: flunk_dispatcher()
               )

      assert [] == loop_runs()
      assert telemetry_lines(telemetry_path) =~ ~s("outcome":"refused")
      assert telemetry_lines(telemetry_path) =~ "malformed STATE"
    end

    test "an unreadable STATE file is a typed refusal too", %{
      state_path: state_path,
      telemetry_path: telemetry_path
    } do
      assert {:ok, %{outcome: :refused}} =
               WaveLoop.tick(
                 state_path: Path.join(state_path, "does-not-exist.md"),
                 telemetry_path: telemetry_path,
                 dispatcher: flunk_dispatcher()
               )
    end

    test "a live lease on a loop epoch makes the tick busy and starts nothing", %{
      state_path: state_path,
      telemetry_path: telemetry_path
    } do
      File.write!(state_path, @state)
      {:ok, _run, epoch} = loop_run_with_epoch!(live_lease: true)

      assert {:ok, %{outcome: :busy, step: "3"}} =
               WaveLoop.tick(
                 state_path: state_path,
                 telemetry_path: telemetry_path,
                 dispatcher: flunk_dispatcher()
               )

      # Exactly the pre-existing run; no second worker was started.
      assert [%Run{id: run_id}] = loop_runs()
      assert run_id == epoch.run_id
      assert telemetry_lines(telemetry_path) =~ ~s("outcome":"busy")
    end

    test "a stale lease is reaped (receipted) and the tick proceeds; an unclosed worker BLOCKEDs the row",
         %{state_path: state_path, telemetry_path: telemetry_path} do
      File.write!(state_path, @state)
      {:ok, stale_run, _stale_epoch} = loop_run_with_epoch!(live_lease: false)

      fake_dispatch = fn _epoch_id, _opts ->
        # The worker "exited 0" but never closed the epoch: the loop must
        # reap it (Engine semantics) and mark the row BLOCKED, never DONE.
        {:ok,
         %{
           status: :ok,
           epoch_id: Ecto.UUID.generate(),
           worker_id: "zcode-test",
           mode: :reap,
           protocol: :xaas_prompt,
           attempts: 1,
           exit_code: 0,
           duration_ms: 5,
           output_tail: "done",
           log_path: "/tmp/unused.log",
           prompt: nil,
           epoch_state: :running,
           receipts: []
         }}
      end

      assert {:ok, %{outcome: outcome}} =
               WaveLoop.tick(
                 state_path: state_path,
                 telemetry_path: telemetry_path,
                 dispatcher: fake_dispatch
               )

      assert outcome == :blocked

      # The stale epoch from the "previous tick" is reaped...
      stale_epoch =
        Ash.get!(Epoch, stale_epoch_id(stale_run), action: :read_unscoped, authorize?: false)

      assert stale_epoch.state == :failed

      # ...and this tick's fresh run exists too; its unclosed epoch is
      # reaped with a receipt (Engine semantics, never a silent drop).
      runs = loop_runs()
      assert length(runs) == 2
      new_run = Enum.find(runs, &(&1.id != stale_run.id))

      epochs = epochs_of(new_run.id)
      assert [%Epoch{}] = epochs
      assert hd(epochs).state == :failed

      receipts =
        Receipt
        |> Ash.Query.for_read(:for_epoch, %{epoch_id: hd(epochs).id})
        |> Ash.read!(authorize?: false)

      assert [%Receipt{} = receipt] = receipts
      assert receipt.outcome == :refused
      assert receipt.evidence["reaped_by"] == "xaas-wave-loop"

      # The STATE row is BLOCKED with the tick stamp; telemetry records it.
      {:ok, state} = state_path |> File.read!() |> State.parse()
      assert fetch_step(state, "3").status == :blocked
      assert File.read!(state_path) =~ "BLOCKED (wave-loop tick 1"
      assert telemetry_lines(telemetry_path) =~ ~s("outcome":"blocked")
    end

    test "a completed worker advances the STATE row, shrinks the note, and appends telemetry",
         %{state_path: state_path, telemetry_path: telemetry_path} do
      File.write!(state_path, @state)

      fake_dispatch = fn epoch_id, _opts ->
        {:ok, epoch} =
          Epoch
          |> Ash.get(epoch_id, action: :read_unscoped, authorize?: false)

        {:ok, _} =
          epoch
          |> Ash.Changeset.for_update(
            :complete,
            %{final_head: "sha256:" <> String.duplicate("a", 64)},
            authorize?: false
          )
          |> Ash.update()

        {:ok, _} =
          Receipt
          |> Ash.Changeset.for_create(
            :seal,
            %{
              epoch_id: epoch_id,
              subject: epoch.exact_subject,
              outcome: :partial_alive,
              evidence: %{"head_verified" => true, "note" => "test worker closed"}
            },
            authorize?: false
          )
          |> Ash.create()

        {:ok,
         %{
           status: :ok,
           epoch_id: epoch_id,
           worker_id: "zcode-test",
           mode: :reap,
           protocol: :xaas_prompt,
           attempts: 1,
           exit_code: 0,
           duration_ms: 5,
           output_tail: "closed",
           log_path: "/tmp/unused.log",
           prompt: nil,
           epoch_state: :completed,
           receipts: [%{"outcome" => "partial_alive", "head_verified" => true}]
         }}
      end

      assert {:ok, %{outcome: :worker_completed, step: "3", receipt: receipt}} =
               WaveLoop.tick(
                 state_path: state_path,
                 telemetry_path: telemetry_path,
                 dispatcher: fake_dispatch
               )

      assert receipt.epoch_id

      # STATE really advanced: row 3 DONE with the loop receipt line, and
      # the note no longer blocks on it (it was never note-listed, so the
      # note itself is untouched by THIS close).
      {:ok, state} = state_path |> File.read!() |> State.parse()
      s3 = fetch_step(state, "3")
      assert s3.status == :done
      assert s3.evidence =~ "wave-loop tick 1"

      # The NEXT actionable step is 4 — the loop really moved forward.
      assert {:ok, %{id: "4"}} = State.first_actionable(state)

      assert telemetry_lines(telemetry_path) =~ ~s("outcome":"worker_completed")
      assert telemetry_lines(telemetry_path) =~ ~s("step":"3")
    end

    test "completing the last remaining step marks STATE COMPLETE and later ticks no-op",
         %{state_path: state_path, telemetry_path: telemetry_path} do
      File.write!(state_path, last_step_state())

      assert {:ok, %{outcome: :worker_completed, receipt: %{complete: true}}} =
               WaveLoop.tick(
                 state_path: state_path,
                 telemetry_path: telemetry_path,
                 dispatcher: closing_dispatch()
               )

      raw = File.read!(state_path)
      assert raw =~ "LOOP COMPLETE"

      # Subsequent ticks are complete no-ops.
      assert {:ok, %{outcome: :complete, tick: 2}} =
               WaveLoop.tick(
                 state_path: state_path,
                 telemetry_path: telemetry_path,
                 dispatcher: flunk_dispatcher()
               )

      assert telemetry_lines(telemetry_path) |> String.split("\n", trim: true) |> length() == 2
    end

    test "the loop runs the REAL Dispatch boundary with a scripted CLI worker (hermetic)",
         %{state_path: state_path, telemetry_path: telemetry_path} do
      File.write!(state_path, @state)

      marker = tmp_path("marker", "")

      script = """
      #!/bin/sh
      echo loop-worker-ran > #{marker}
      exit 0
      """

      cli_dir = fake_cli_dir(script)

      assert {:ok, %{outcome: :blocked}} =
               WaveLoop.tick(
                 state_path: state_path,
                 telemetry_path: telemetry_path,
                 dispatch_opts: [
                   cli_dir: cli_dir,
                   node_path: Path.expand("../../support/fake-node.sh", __DIR__),
                   timeout_seconds: 60
                 ]
               )

      # The REAL subprocess really ran (Dispatch -> port -> sh -> script).
      assert File.exists?(marker)
      assert File.read!(marker) =~ "loop-worker-ran"

      # The goal the loop built for the real boundary carries the step id,
      # the step's dispatch instructions VERBATIM, and the update law.
      [%Run{goal: goal}] = loop_runs()
      assert goal =~ "STEP 3: branch integrations"
      assert goal =~ "agent role W8-A3"
      assert goal =~ "ONE `--no-ff`"
      assert goal =~ state_path
      assert goal =~ "ultracode-wave-loop/1"

      # The run is a real provider-pull loop run.
      assert %Run{provider: "zcode", execution_policy: :wave_loop_step, max_cycles: 1} =
               hd(loop_runs())
    end

    test "a dispatcher-level typed refusal leaves the row pending for the next tick",
         %{state_path: state_path, telemetry_path: telemetry_path} do
      File.write!(state_path, @state)

      assert {:ok, %{outcome: :dispatch_refused}} =
               WaveLoop.tick(
                 state_path: state_path,
                 telemetry_path: telemetry_path,
                 dispatcher: fn _epoch_id, _opts ->
                   {:error, {:cli_unavailable, "/nope/bin/zcode.js"}}
                 end
               )

      {:ok, state} = state_path |> File.read!() |> State.parse()
      assert fetch_step(state, "3").status == :pending
      assert telemetry_lines(telemetry_path) =~ ~s("outcome":"dispatch_refused")
    end
  end

  # ------------------------------------------------------------------
  # Schedule + action registration
  # ------------------------------------------------------------------

  describe ":wave_loop schedule registration" do
    test "AshOban merges an hourly crontab entry for the generated worker" do
      built =
        AshOban.config(
          Application.fetch_env!(:xaas, :ash_domains),
          Application.fetch_env!(:xaas, Oban)
        )

      {_plugin, opts} =
        Enum.find(built[:plugins], fn
          {Oban.Plugins.Cron, _opts} -> true
          _ -> false
        end)

      entry =
        Enum.find(opts[:crontab], fn
          {_cron, Xaas.Ultracode.Run.Workers.WaveLoop, _opts} -> true
          _ -> false
        end)

      assert entry, "no crontab entry for Xaas.Ultracode.Run.Workers.WaveLoop"
      {cron, _worker, _entry_opts} = entry
      assert to_string(cron) == "0 * * * *"
    end

    test "generated worker is routed to the single-slot queue with incomplete-job uniqueness" do
      queues = Application.fetch_env!(:xaas, Oban)[:queues]
      worker_opts = Xaas.Ultracode.Run.Workers.WaveLoop.__opts__()

      assert queues[:ultracode_wave_loop] == 1
      assert worker_opts[:queue] == :ultracode_wave_loop
      assert worker_opts[:unique][:period] == :infinity
      assert worker_opts[:unique][:states] == :incomplete
    end

    test "the action runs through the runner seam under the scheduler authority" do
      test_pid = self()

      Application.put_env(:xaas, :ultracode_wave_loop_runner, fn _opts ->
        send(test_pid, :loop_ran)
        {:ok, %{outcome: :seam_test, tick: 0, step: nil, receipt: %{}}}
      end)

      on_exit(fn -> Application.delete_env(:xaas, :ultracode_wave_loop_runner) end)

      assert {:ok, %{outcome: :seam_test}} =
               Run
               |> Ash.ActionInput.for_action(:wave_loop, %{})
               |> Ash.run_action(actor: Xaas.SystemAuthority.new(:oban_scheduler))

      assert_receive :loop_ran
    end
  end

  # ------------------------------------------------------------------
  # Fixtures + helpers
  # ------------------------------------------------------------------

  defp flunk_dispatcher do
    fn _epoch_id, _opts -> flunk("the loop must not dispatch in this test") end
  end

  # A loop Run at :running with its first epoch activated. The lease is
  # bound through the REAL production claim path (`Lease.claim_next`, the
  # same path a real fabric worker takes), never a hand-written `:lease`
  # update: `Epoch.lease` is `multitenancy(:allow_global)`, which Ash's
  # second UPDATE-pipeline tenant checkpoint treats as tenant-requiring
  # when no tenant is supplied (the asymmetry documented on the resource
  # itself). A stale lease is produced by rewinding the expiry through
  # `:renew_lease` -- the one lease-family action that is
  # `multitenancy(:bypass)`.
  defp loop_run_with_epoch!(opts) do
    live? = Keyword.get(opts, :live_lease, true)

    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{
          goal: "loop fixture",
          provider: "zcode",
          max_cycles: 1,
          execution_policy: :wave_loop_step,
          epoch_timeout_seconds: 7200
        },
        authorize?: false
      )
      |> Ash.create()

    {:ok, run} =
      run
      |> Ash.Changeset.for_update(:start, %{exact_subject: "wave-loop:fixture"},
        authorize?: false
      )
      |> Ash.update()

    {:ok, epoch} =
      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(run_id == ^run.id and state == :expected)
      |> Ash.read_one(authorize?: false)
      |> case do
        {:ok, %Epoch{} = epoch} ->
          epoch
          |> Ash.Changeset.for_update(:start, %{}, authorize?: false)
          |> Ash.update()

        other ->
          flunk("no first epoch: #{inspect(other)}")
      end

    {:ok, claimed, _token, _claim_run} =
      Lease.claim_next("zcode", "wave-loop-fixture", epoch_id: epoch.id)

    unless live? do
      claimed
      |> Ash.Changeset.for_update(
        :renew_lease,
        %{lease_expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)},
        authorize?: false
      )
      |> Ash.update!()
    end

    {:ok, run, Ash.get!(Epoch, claimed.id, action: :read_unscoped, authorize?: false)}
  end

  defp stale_epoch_id(run) do
    run.id |> epochs_of() |> hd() |> Map.get(:id)
  end

  defp epochs_of(run_id) do
    Epoch
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(run_id == ^run_id)
    |> Ash.Query.sort(cycle: :asc)
    |> Ash.read!(authorize?: false)
  end

  defp loop_runs do
    Run
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(execution_policy == ^:wave_loop_step)
    |> Ash.read!(authorize?: false)
  end

  defp fetch_step(state, id) do
    Enum.find(state.steps, &(&1.id == id))
  end

  defp table(rows) do
    """
    | step | status | evidence |
    |---|---|---|
    #{Enum.join(rows, "\n")}
    """
  end

  defp table_row(first, status, evidence), do: table([row(first, status, evidence)])

  defp row(first, status, evidence), do: "| #{first} | #{status} | #{evidence} |"

  defp complete_state do
    """
    | step | status | evidence |
    |---|---|---|
    | 1 a | DONE | e1 |
    | 2 b | COMPLETE | e2 |

    REMAINING: none. Then COMPLETE.
    """
  end

  defp last_step_state do
    """
    ### [8] Final sweep
    - **description:** re-sweep.

    | step | status | evidence |
    |---|---|---|
    | 8 OCEL sweep | DONE | pre-merge sweep |

    REMAINING: step 8 re-sweep post-merge. Then COMPLETE.
    """
  end

  # A dispatcher stand-in that closes the epoch like a real fabric worker.
  defp closing_dispatch do
    fn epoch_id, _opts ->
      {:ok, epoch} = Ash.get(Epoch, epoch_id, action: :read_unscoped, authorize?: false)

      {:ok, _} =
        epoch
        |> Ash.Changeset.for_update(
          :complete,
          %{final_head: "sha256:" <> String.duplicate("b", 64)},
          authorize?: false
        )
        |> Ash.update()

      {:ok,
       %{
         status: :ok,
         epoch_id: epoch_id,
         worker_id: "zcode-test",
         mode: :reap,
         protocol: :xaas_prompt,
         attempts: 1,
         exit_code: 0,
         duration_ms: 5,
         output_tail: "closed",
         log_path: "/tmp/unused.log",
         prompt: nil,
         epoch_state: :completed,
         receipts: []
       }}
    end
  end

  defp fake_cli_dir(script) do
    dir = tmp_path("cli", "")
    File.mkdir_p!(Path.join(dir, "bin"))
    path = Path.join([dir, "bin", "zcode.js"])
    File.write!(path, script)
    File.chmod!(path, 0o755)

    File.write!(
      Path.join(dir, "package.json"),
      Jason.encode!(%{
        "name" => "zcode-app-cli",
        "version" => "0.0.0-test",
        "bin" => %{"zcode" => "bin/zcode.js"},
        "engines" => %{"node" => ">=22.19.0"}
      })
    )

    dir
  end

  defp telemetry_lines(path), do: File.read!(path)

  # Wall-clock-qualified per-test artifact paths (System.unique_integer
  # restarts per BEAM; observed cross-run collisions in DispatchTest).
  defp tmp_path(label, suffix) do
    path =
      Path.join(
        System.tmp_dir!(),
        "wave-loop-test-#{label}-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}#{suffix}"
      )

    on_exit(fn -> File.rm_rf(path) end)
    path
  end
end
