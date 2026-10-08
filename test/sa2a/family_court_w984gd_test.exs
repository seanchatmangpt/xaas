defmodule Xaas.Sa2a.FamilyCourtW984gdTest do
  @moduledoc """
  Unclaimed-family probe court for `lib/xaas/sa2a/` (W984gd). `Changes.Execute`
  was already courted by W984dq9/W984es (`test/sa2a/changes/execute_deepening_test.exs`);
  this file courts the residue the rest of the suite leaves unexercised.

  Real collaborators throughout: real `/bin/sh` JSON-lines subprocess ports
  (the w741 convention), the real single-slot `Xaas.Sa2a.Bridge` GenServer,
  the real `python3` canonical-JSON cross-check, real Ash replan vocabulary.
  No mocks.

  Per-branch mutation rationale is stated inline: each test fails if the branch
  under court is deleted or mutated, because the assertion names the branch's
  exact typed outcome.
  """

  use ExUnit.Case, async: false

  alias Xaas.Sa2a.{Bridge, Canonical, Court, ReceiptFeedback, WaveOutcome}

  @admit_hash String.duplicate("a", 64)
  @plan_hash String.duplicate("b", 64)

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # -- real-subprocess port stand-in (w741 convention, as in execute_deepening_test.exs) --

  defp responder_script(arms) do
    body =
      Enum.map_join(arms, "\n      ", fn {op, action} ->
        "*#{op}*) " <> action <> ";;"
      end)

    script = """
    #!/bin/sh
    while IFS= read -r line; do
      case "$line" in
        #{body}
      esac
    done
    """

    path = Path.join(System.tmp_dir!(), "w984gd-#{System.unique_integer([:positive])}.sh")
    File.write!(path, script)
    File.chmod!(path, 0o755)

    on_exit(fn ->
      _ = File.rm(path)
      :ok
    end)

    path
  end

  defp start_script_bridge!(arms) do
    # Real Port.open subprocess, real single-slot GenServer state machine.
    start_supervised!({Bridge, port_command: responder_script(arms), port_args: []})
  end

  # -- static-valid request (passes every STATIC admission condition of the court) --------

  defp static_valid_request do
    id = "SJ-GD-#{System.unique_integer([:positive])}"
    digest = "sha256:" <> Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
    query = "workorder:#{id} resolve"
    assertion = "workorder:#{id} digest:#{digest} requires-construction"

    %{
      "work_order_id" => id,
      "work_order_digest" => digest,
      "query" => query,
      "compiled_rules" => [[query, "constructed:#{id}"]],
      "admit" => %{
        "candidate_id" => id,
        "assertion" => assertion,
        "receipt" => %{
          "ok" => true,
          "standing" => "KNOWN",
          "candidate_hash" => @admit_hash,
          "admitted_assertion" => assertion
        }
      },
      "plan" => %{
        "plan_id" => "gd-plan",
        "plan_hash" => @plan_hash,
        "candidates" => [%{"item_id" => id, "description" => "gd"}],
        "ticks" => 1000,
        "tokens" => 50_000,
        "experiments" => 10
      }
    }
  end

  # -- 1. Court.bridge/2: the :bridge_busy retry loop against a REAL busy slot --------------

  test "a busy slot is retried with backoff and the real reply wins once the slot frees" do
    # The port sleeps before answering sa2a_plan, so the slot is genuinely held.
    start_script_bridge!([
      {"sa2a_plan", ~s(sleep 0.5; echo '{"ok":true,"plan_hash":"#{@plan_hash}","allocations":[]}')}
    ])

    holder =
      Task.async(fn ->
        Bridge.plan([%{"item_id" => "SJ-GD-holder"}], plan_id: "hold")
      end)

    # Let the holder deterministically own the single slot before the court dials.
    Process.sleep(100)

    # Attempt 1 lands while the slot is held -> :bridge_busy; the court retries
    # after its backoff and the retry lands after the holder's real reply.
    result =
      Court.bridge(fn ->
        Bridge.plan([%{"item_id" => "SJ-GD-w984gd"}], plan_id: "gd")
      end)

    assert {:ok, %{"ok" => true, "plan_hash" => @plan_hash}} = result
    assert {:ok, %{"ok" => true, "plan_hash" => @plan_hash}} = Task.await(holder)
  end

  test "a slot held longer than the retry budget exhausts into a typed BLOCKED" do
    start_script_bridge!([
      {"sa2a_plan", ~s(sleep 3; echo '{"ok":true,"plan_hash":"x","allocations":[]}')}
    ])

    holder = Task.async(fn -> Bridge.plan([%{"item_id" => "SJ-GD-slow"}], plan_id: "slow") end)
    # Give the holder a head start so it deterministically owns the single slot.
    Process.sleep(100)

    result =
      Court.bridge(fn ->
        Bridge.plan([%{"item_id" => "SJ-GD-w984gd"}], plan_id: "gd")
      end)

    assert {:error, {:blocked, :bridge_busy}} = result

    # The holder still completes with its real reply once the port frees.
    assert {:ok, %{"ok" => true}} = Task.await(holder, 10_000)
  end

  # -- 2. Court.bridge/2: non-noproc exit while a call is in flight -------------------------

  test "a bridge killed mid-call surfaces as {:bridge_exit, :killed}, not a crash" do
    start_script_bridge!([
      {"sa2a_plan", ~s(sleep 2; echo '{"ok":true,"plan_hash":"x","allocations":[]}')}
    ])

    task =
      Task.async(fn ->
        Court.bridge(fn ->
          Bridge.plan([%{"item_id" => "SJ-GD-kill"}], plan_id: "kill")
        end)
      end)

    Process.sleep(100)
    pid = Process.whereis(Bridge)
    Process.exit(pid, :kill)

    assert {:error, {:blocked, {:bridge_exit, :killed}}} = Task.await(task)
  end

  # -- 3. the court's `other ->` unexpected-reply arms --------------------------------------

  test "an admit reply without an ok flag is a typed BLOCKED (admit_unexpected_reply)" do
    start_script_bridge!([
      {"sa2a_admit", ~s(echo '{"surprise":true}')}
    ])

    req = static_valid_request()

    assert {:error, {:blocked, {:admit_unexpected_reply, {:ok, %{"surprise" => true}}}}} =
             Court.admit(req)
  end

  test "a plan reply without a plan_hash is a typed BLOCKED (plan_unexpected_reply)" do
    start_script_bridge!([
      {"sa2a_admit", ~s(echo '{"ok":true,"standing":"KNOWN","candidate_hash":"#{@admit_hash}"}')},
      {"sa2a_plan", ~s(echo '{"ghost":1}')}
    ])

    req = static_valid_request()

    assert {:error, {:blocked, {:plan_unexpected_reply, {:ok, %{"ghost" => 1}}}}} =
             Court.admit(req)
  end

  # -- 4. Canonical: escape shortcuts and typed raises --------------------------------------

  test "\\r, \\b and \\f escape shortcuts round-trip and agree with a real python3 sha256" do
    manifest = %{
      "s1" => "carriage\rreturn",
      "s2" => "back\bspace",
      "s3" => "form\ffeed",
      "s4" => "ctrl\u0001char"
    }

    encoded = Canonical.encode!(manifest)

    assert encoded =~ ~s(\\r) and encoded =~ ~s(\\b) and encoded =~ ~s(\\f)
    refute encoded =~ "\r"

    # Independent implementation: real python3 json.dumps(sort_keys, compact, ensure_ascii).
    py_hash =
      run_python!(
        ~s|import json,hashlib;print(hashlib.sha256(json.dumps(#{py_literal(manifest)},sort_keys=True,separators=(",",":")).encode()).hexdigest())|
      )

    assert Canonical.sha256(manifest) == py_hash
  end

  test "atoms encode as strings and integer map keys are stringified, Python-identically" do
    manifest = %{:atom_key => 1, 2 => [:ok, false, nil]}
    encoded = Canonical.encode!(manifest)

    assert encoded == ~s({"2":["ok",false,null],"atom_key":1})

    py_hash =
      run_python!(
        ~s|import json,hashlib;print(hashlib.sha256(json.dumps({"2":["ok",False,None],"atom_key":1},sort_keys=True,separators=(",",":")).encode()).hexdigest())|
      )

    assert Canonical.sha256(manifest) == py_hash
  end

  test "invalid UTF-8 is a typed ArgumentError, never a mis-hash" do
    assert_raise ArgumentError, ~r/invalid UTF-8/, fn ->
      Canonical.encode!(<<0xFF, 0xFE>>)
    end
  end

  test "non-JSON terms (tuples, pids) are typed ArgumentErrors" do
    assert_raise ArgumentError, ~r/not canonical JSON/, fn ->
      Canonical.encode!({:tuple, 1})
    end

    assert_raise ArgumentError, ~r/not canonical JSON/, fn ->
      Canonical.encode!(self())
    end
  end

  # -- 5. WaveOutcome: binary vocabulary and the recovery mapping ---------------------------

  test "the known binary vocabulary parses; unknown binaries and non-strings do not" do
    assert WaveOutcome.parse("failed") == :failed
    assert WaveOutcome.parse("worker_completed") == :worker_completed
    assert WaveOutcome.parse("unknown_outcome") == :unknown_outcome
    assert WaveOutcome.parse("never_seen_before") == :unknown_outcome
    assert WaveOutcome.parse(42) == :unknown_outcome
    assert WaveOutcome.parse(nil) == :unknown_outcome
  end

  test "recovery maps each consequence onto the ash_a2a recovery policy" do
    assert WaveOutcome.recovery(:worker_completed) == :stop
    assert WaveOutcome.recovery(:refused) == :stop
    assert WaveOutcome.recovery(:compensated) == :stop
    assert WaveOutcome.recovery(:failed) == :replan
    assert WaveOutcome.recovery(:timeout) == :replan
    assert WaveOutcome.recovery("never_seen_before") == :reconcile_before_replan
  end

  test "failed and timeout settlements requeue; compensated settles complete" do
    assert WaveOutcome.settlement(:failed) == :requeue
    assert WaveOutcome.settlement(:timeout) == :requeue
    assert WaveOutcome.settlement(:compensated) == :complete
    assert WaveOutcome.chainable?("worker_completed", false)
  end

  # -- 6. ReceiptFeedback: string-keyed receipts and subject/id fallbacks -------------------

  test "a string-keyed receipt with id/subject/outcome keys projects identically" do
    assert %{kind: :replan, subject: "sha256:s2", reason: :failed, authority: :none} =
             ReceiptFeedback.decision(%{
               "id" => "r3",
               "subject" => "sha256:s2",
               "outcome" => "failed"
             })
  end

  test "semantic_subject wins over subject and exact_subject in the fallback chain" do
    assert %{kind: :stop, subject: "sha256:first", reason: :refused} =
             ReceiptFeedback.decision(%{
               receipt_id: "r4",
               semantic_subject: "sha256:first",
               subject: "sha256:second",
               exact_subject: "sha256:third",
               outcome: :refused
             })
  end

  test "an outcome outside the terminal vocabulary is classify-resistant" do
    assert %{kind: :replan, reason: :unknown_outcome_reconcile_first} =
             ReceiptFeedback.decision(%{receipt_id: "r5", subject: "s", outcome: :busy})
  end

  # -- helpers -------------------------------------------------------------------------------

  defp run_python!(code) do
    {out, 0} = System.cmd("python3", ["-c", code])
    String.trim(out)
  end

  defp py_literal(_manifest) do
    # The manifest is plain ASCII strings with the exact escapes under court; a
    # hand-built Python literal keeps the cross-check independent of Elixir encoding.
    ~s({"s1":"carriage\\rreturn","s2":"back\\bspace","s3":"form\\ffeed","s4":"ctrl\\u0001char"})
  end
end
