defmodule Xaas.Ultracode.AutonomicTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Chicago-style qualification of the autonomic loop (`Xaas.Ultracode.Autonomic`)
  end to end, with every collaborator real except the LLM: sandboxed Postgres,
  the real Python backlog generator and definition-of-done court, a real local
  clone of the agile-protocol-specification repository, real git worktrees,
  real leases, and the real `Lease.close/4` fabric verifier.

  The worker is a scripted protocol client: a real implementation of the lease
  protocol that claims its epoch, writes a file, commits, and closes -- it
  stands in only for the model's judgment. Assertions are on sealed receipts,
  git history and the ledger the loop actually produced.

  Tagged `:subprocess` (each test runs the court and APS's canonical gates) and
  skipped by name when the operator APS clone, python3, or mdbook is missing.
  """

  alias Xaas.Ultracode.{Autonomic, Epoch, Lease, Receipt, Run}

  @moduletag :subprocess
  @moduletag timeout: 600_000

  @source Path.expand("~/xaas-worktrees/repos/aps")
  @provider "zcode-autonomic-test"

  @moduletag skip:
               (cond do
                  not File.dir?(Path.join(@source, ".git")) ->
                    "operator APS clone missing at #{@source}"

                  is_nil(System.find_executable("python3")) ->
                    "python3 not on PATH"

                  is_nil(System.find_executable("mdbook")) ->
                    "mdbook not on PATH"

                  true ->
                    false
                end)

  @good_test ~S'''
  import json
  import unittest
  from pathlib import Path

  import jsonschema

  SCHEMA = json.loads(
      (Path(__file__).resolve().parents[1] / "contracts" / "standing.schema.json").read_text()
  )
  VALID = ["ALIVE", "PARTIAL_ALIVE", "BLOCKED", "BUILD_BROKEN", "UNKNOWN", "UNSUPPORTED", "REFUSED"]


  class StandingContract(unittest.TestCase):
      def setUp(self):
          self.validator = jsonschema.Draft202012Validator(SCHEMA)

      def test_alive_is_accepted(self):
          self.assertTrue(self.validator.is_valid("ALIVE"))

      def test_every_named_standing_is_accepted(self):
          for value in VALID:
              self.assertTrue(self.validator.is_valid(value), value)

      def test_lowercase_is_rejected(self):
          self.assertFalse(self.validator.is_valid("alive"))

      def test_unnamed_standing_is_rejected(self):
          self.assertFalse(self.validator.is_valid("DONE"))

      def test_non_string_is_rejected(self):
          self.assertFalse(self.validator.is_valid(1))


  if __name__ == "__main__":
      unittest.main()
  '''

  @vacuous_test ~S'''
  import unittest


  class StandingContract(unittest.TestCase):
      def test_alive(self):
          pass

      def test_blocked(self):
          pass

      def test_refused(self):
          pass

      def test_unknown(self):
          pass
  '''

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    original =
      for key <- [
            :ultracode_verifier_suites,
            :ultracode_worktree_root,
            :ultracode_ticket_dir,
            :ultracode_repos
          ],
          into: %{},
          do: {key, Application.get_env(:xaas, key)}

    base = mktmp("base")
    repo = Path.join(base, "aps")
    {_, 0} = System.cmd("git", ["clone", "-q", @source, repo], stderr_to_stdout: true)

    Application.put_env(:xaas, :ultracode_worktree_root, Path.join(base, "runs"))
    Application.put_env(:xaas, :ultracode_ticket_dir, Path.join(base, "tickets"))
    Application.put_env(:xaas, :ultracode_repos, %{"aps" => repo})
    Application.put_env(:xaas, :ultracode_verifier_suites, suites())

    on_exit(fn ->
      # nil = unset before this test: DELETE, never put_env(key, nil) --
      # a literal nil poisons later `get_env(key, %{})` readers
      # (see target_suites_test's restore_env note).
      for {key, value} <- original do
        if is_nil(value),
          do: Application.delete_env(:xaas, key),
          else: Application.put_env(:xaas, key, value)
      end
    end)

    %{base: base, repo: repo}
  end

  test "a vacuous first attempt is rejected by the court, repaired, and then promoted", %{
    repo: repo
  } do
    worker = scripted(fn attempt -> if attempt == 1, do: @vacuous_test, else: @good_test end)

    assert {:ok, report} = run_loop(worker, only: ["contract-standing"])

    assert report["standing"] == "ALIVE"
    assert report["human_inputs"] == 0
    assert report["backlog"] == ["contract-standing"]
    assert [%{"status" => "done", "attempts" => 2} = item] = report["items"]

    # The failed attempt is on the record: the court rejected it for a named gate.
    assert [%{"attempt" => 1, "failure" => failure}] = item["history"]
    assert failure =~ "CHI-ASSERT"

    # Sealed receipts the database really holds: attempt 1 was NOT alive, attempt 2 was.
    outcomes =
      Enum.map(receipts_for_item("contract-standing"), &{&1.attempt, &1.outcome, &1.fv["status"]})

    assert {1, :build_broken, "fail"} in outcomes
    assert {2, :alive, "pass"} in outcomes

    # The court's own APS-schema receipt is carried in the sealed evidence, executor != verifier.
    winner = Enum.find(receipts_for_item("contract-standing"), &(&1.attempt == 2))
    court = winner.fv["court_receipt"]
    assert court["standing"] == "ALIVE"
    assert court["executorRef"] == item["executor"]
    refute court["verifier"]["identity"] == court["executorRef"]

    # The integration branch really contains the merged, court-approved work.
    integration = report["integration"]
    assert integration["head"] != report["base_sha"]

    assert git(integration["worktree"], ["show", "HEAD:tests/test_contract_standing.py"]) =~
             "StandingContract"

    assert git(integration["worktree"], ["log", "-1", "--format=%s"]) =~
             "merge: contract-standing"

    assert report["canonical"]["status"] == "pass"
    assert report["merged"] == ["contract-standing"]

    # Nothing was pushed and the operator clone's own branch is untouched.
    assert git(repo, ["rev-parse", "HEAD"]) == report["base_sha"]

    events = ledger_events(report)

    for expected <- ~w(start sensed attempt_start attempt_failed item_done merged canonical final) do
      assert expected in events, "ledger missing #{expected}"
    end

    assert Enum.count(events, &(&1 == "attempt_start")) == 2
  end

  test "an honest partial_alive on a court-pass head completes in ONE worker session", %{
    repo: _repo
  } do
    # The honest-worker protocol: the worker has no Bash and cannot run the
    # court itself, so it closes :partial_alive even though the candidate is
    # good. The fabric's court passes the exact head; the judge accepts, so
    # the item is done in ONE worker session (pre-fix this burned a second
    # full worker session to manufacture the word alive).
    worker = scripted(fn _attempt -> @good_test end, :partial_alive)

    assert {:ok, report} = run_loop(worker, only: ["contract-standing"])

    assert [%{"status" => "done", "attempts" => 1} = item] = report["items"]
    assert item["fabric_verifier"]["status"] == "pass"
    assert report["standing"] == "ALIVE"
    assert report["merged"] == ["contract-standing"]
    assert report["canonical"]["status"] == "pass"

    # Exactly one worker session: no failed attempt, no second dispatch.
    lines = ledger_lines(report)
    assert Enum.count(lines, &(&1["event"] == "attempt_start")) == 1
    refute Enum.any?(lines, &(&1["event"] == "attempt_failed"))

    assert [%{"data" => %{"attempt" => 1, "accepted_via" => "partial_alive"}}] =
             Enum.filter(lines, &(&1["event"] == "item_done"))

    # The sealed receipt the database holds is the honest one, court-verified
    # on the exact head.
    assert [%{outcome: :partial_alive, evidence: evidence, fv: fv}] =
             receipts_for_item("contract-standing")

    assert evidence["head_verified"] == true
    assert fv["status"] == "pass"

    # The integration branch really holds the court-approved work.
    integration = report["integration"]
    assert integration["head"] != report["base_sha"]

    assert git(integration["worktree"], ["show", "HEAD:tests/test_contract_standing.py"]) =~
             "StandingContract"
  end

  test "a worker that dies without closing is reaped and the attempt is retried", %{repo: _repo} do
    worker = fn epoch, ctx ->
      case attempt_of(epoch) do
        1 ->
          # Claims the lease, then vanishes without closing.
          {:ok, _claimed, _token, _run} =
            Lease.claim_next(@provider, "dies-#{epoch.id}", epoch_id: epoch.id)

          :ok

        _ ->
          scripted(fn _ -> @good_test end).(epoch, ctx)
      end
    end

    assert {:ok, report} = run_loop(worker, only: ["contract-standing"])

    assert [%{"status" => "done", "attempts" => 2} = item] = report["items"]

    assert [%{"attempt" => 1, "failure" => "worker ended without closing the lease"}] =
             item["history"]

    assert report["standing"] == "ALIVE"

    [first | _] = Enum.filter(receipts_for_item("contract-standing"), &(&1.attempt == 1))
    assert first.outcome == :refused
    assert first.evidence["refusal_reason"] == "worker_no_close"
  end

  test "an EXPIRED lease is reaped to a terminal epoch with a refused receipt", %{repo: _repo} do
    # PERMANENT TRIPWIRE (observed falsifier 2026-09-21, Campaign 3 wave 1):
    # when the worker's lease TTL expires before it vanishes, `Lease.refuse/3`
    # errors with `{:lease_expired, _}` and the reap used to DISCARD that
    # result -- the epoch stayed stuck `:running` forever, and
    # `mix xaas.run_validate` named it `missing_terminal`. The terminal
    # epoch => receipt invariant must hold through the expired-lease path.
    worker = fn epoch, ctx ->
      case attempt_of(epoch) do
        1 ->
          # Claim with a ZERO TTL: by the time the worker vanishes the lease
          # is genuinely expired (the sanctioned fast-forward from
          # lease_concurrency_stress_test), so the loop's refuse/3 hits
          # `{:lease_expired, _}` instead of being what terminates the epoch.
          {:ok, _claimed, _token, _run} =
            Lease.claim_next(@provider, "expires-#{epoch.id}",
              epoch_id: epoch.id,
              lease_ttl_minutes: 0
            )

          Process.sleep(5)

          :ok

        _ ->
          scripted(fn _ -> @good_test end).(epoch, ctx)
      end
    end

    assert {:ok, report} = run_loop(worker, only: ["contract-standing"])

    assert [%{"status" => "done", "attempts" => 2} = item] = report["items"]

    assert [%{"attempt" => 1, "failure" => "worker ended without closing the lease"}] =
             item["history"]

    assert report["standing"] == "ALIVE"

    # THE INVARIANT: the attempt-1 epoch is TERMINAL, not stuck claimed.
    [expired_epoch] =
      for run <- Ash.read!(Run, action: :read_unscoped, authorize?: false),
          run.provider == @provider,
          epoch <- Ash.read!(Epoch, action: :read_unscoped, authorize?: false),
          epoch.run_id == run.id,
          String.starts_with?(epoch.exact_subject, "aps-autonomic:contract-standing#1:"),
          do: epoch

    assert expired_epoch.state == :failed

    # ...and the receipt invariant holds: a refused receipt sealed at reap.
    assert [%{outcome: :refused} = receipt] =
             Receipt
             |> Ash.Query.for_read(:for_epoch, %{epoch_id: expired_epoch.id})
             |> Ash.read!(authorize?: false)
             |> Enum.filter(&Map.has_key?(&1.evidence, "refusal_reason"))

    assert receipt.evidence["refusal_reason"] == "worker_no_close"
  end

  test "a provider rate refusal halves the pace and retries without spending an attempt", %{
    repo: _repo
  } do
    flag = :counters.new(1, [])

    worker = fn epoch, ctx ->
      if :counters.get(flag, 1) == 0 do
        :counters.add(flag, 1, 1)
        :rate_limited
      else
        scripted(fn _ -> @good_test end).(epoch, ctx)
      end
    end

    assert {:ok, report} =
             run_loop(worker, only: ["contract-standing"], capacity: 4, rate_backoff_ms: 10)

    assert [%{"status" => "done", "attempts" => 1}] = report["items"]
    assert "attempt_start" in ledger_events(report)
    assert Enum.count(ledger_events(report), &(&1 == "attempt_start")) == 2
  end

  test "an item that never satisfies the court is reported blocked with its history, never dropped",
       %{repo: _repo} do
    worker = scripted(fn _ -> @vacuous_test end)

    assert {:ok, report} = run_loop(worker, only: ["contract-standing"], max_attempts: 2)

    assert report["standing"] == "BLOCKED"
    assert [%{"status" => "blocked", "attempts" => 2, "history" => history}] = report["items"]
    assert length(history) == 2
    assert report["merged"] == []
    assert is_nil(report["integration"])
    assert "item_blocked" in ledger_events(report)
  end

  # ------------------------------------------------------------------
  # The scripted protocol client
  # ------------------------------------------------------------------

  defp scripted(content_for_attempt), do: scripted(content_for_attempt, :alive)

  # `outcome` is the worker's HONEST self-assessment at close time -- the
  # court, not the worker, decides what the evidence is worth.
  defp scripted(content_for_attempt, outcome) do
    fn epoch, _ctx ->
      attempt = attempt_of(epoch)
      worker_id = "scripted-worker-#{attempt}-#{String.slice(epoch.id, 0, 8)}"

      {:ok, claimed, token, _run} = Lease.claim_next(@provider, worker_id, epoch_id: epoch.id)
      worktree = claimed.worktree
      file = Path.join(worktree, "tests/test_contract_standing.py")
      File.write!(file, content_for_attempt.(attempt) <> "\n# attempt #{attempt}\n")

      env = [
        {"GIT_AUTHOR_NAME", "scripted"},
        {"GIT_AUTHOR_EMAIL", "s@s"},
        {"GIT_COMMITTER_NAME", "scripted"},
        {"GIT_COMMITTER_EMAIL", "s@s"}
      ]

      {_, 0} =
        System.cmd("git", ["-C", worktree, "add", "tests/test_contract_standing.py"], env: env)

      {_, 0} =
        System.cmd("git", ["-C", worktree, "commit", "-q", "-m", "test(contract): standing"],
          env: env
        )

      head = git(worktree, ["rev-parse", "HEAD"])

      {:ok, _epoch, _receipt} =
        Lease.close(token, head, outcome, %{"note" => "scripted worker done"})

      :ok
    end
  end

  # exact_subject is "aps-autonomic:<item>#<attempt>:<run_id>"
  defp attempt_of(epoch) do
    [_, rest] = String.split(epoch.exact_subject, "#", parts: 2)
    rest |> String.split(":") |> hd() |> String.to_integer()
  end

  defp run_loop(worker, opts) do
    Autonomic.run(
      Keyword.merge(
        [
          repo: "aps",
          provider: @provider,
          worker: worker,
          capacity: 2,
          max_attempts: 3,
          rate_backoff_ms: 10
        ],
        opts
      )
    )
  end

  # ------------------------------------------------------------------
  # Evidence readers
  # ------------------------------------------------------------------

  defp receipts_for_item(item) do
    for run <- Ash.read!(Run, action: :read_unscoped, authorize?: false),
        run.provider == @provider,
        epoch <- Ash.read!(Epoch, action: :read_unscoped, authorize?: false),
        epoch.run_id == run.id,
        String.starts_with?(epoch.exact_subject, "aps-autonomic:#{item}#"),
        receipt <-
          Receipt
          |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch.id})
          |> Ash.read!(authorize?: false),
        Map.has_key?(receipt.evidence, "head_verified") or
          Map.has_key?(receipt.evidence, "refusal_reason") do
      %{
        attempt: attempt_of(epoch),
        outcome: receipt.outcome,
        evidence: receipt.evidence,
        fv: receipt.evidence["fabric_verifier"] || %{}
      }
    end
  end

  defp ledger_events(report) do
    report["receipt_path"]
    |> Path.dirname()
    |> Path.join("ledger.ndjson")
    |> File.stream!()
    |> Enum.map(&(&1 |> Jason.decode!() |> Map.fetch!("event")))
  end

  defp ledger_lines(report) do
    report["receipt_path"]
    |> Path.dirname()
    |> Path.join("ledger.ndjson")
    |> File.stream!()
    |> Enum.map(&Jason.decode!/1)
  end

  # ------------------------------------------------------------------
  # Suites (mirror config/dev.exs)
  # ------------------------------------------------------------------

  defp suites do
    {userbase, 0} = System.cmd("python3", ["-m", "site", "--user-base"])

    env = %{
      "PATH" => "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
      "LANG" => "en_US.UTF-8",
      "PYTHONUSERBASE" => String.trim(userbase)
    }

    %{
      "aps-dod" => %{
        env: env,
        max_output_bytes: 65_536,
        steps: [
          %{
            id: "court",
            timeout_ms: 300_000,
            infra_exit_codes: [2],
            receipt: true,
            argv: [
              "python3",
              "priv:verifiers/aps_dod_court.py",
              "--worktree",
              "{worktree}",
              "--head",
              "{head}",
              "--ticket",
              "{ticket}",
              "--executor",
              "{executor}",
              "--verifier-identity",
              "{verifier_id}"
            ]
          }
        ]
      },
      "aps-canonical" => %{
        env: env,
        max_output_bytes: 16_384,
        steps: [
          %{
            id: "verify",
            timeout_ms: 120_000,
            argv: ["python3", "tools/verify.py", "--no-receipt"]
          },
          %{
            id: "unittest",
            timeout_ms: 120_000,
            argv: ["python3", "-m", "unittest", "discover", "-s", "tests"]
          },
          %{id: "ggen", timeout_ms: 120_000, argv: ["python3", "tools/verify_ggen_ecosystem.py"]},
          %{
            id: "mdbook",
            timeout_ms: 120_000,
            argv: ["/bin/sh", "-c", ~S(mdbook build -d "$TMPDIR/book" specification-guide)]
          },
          %{
            id: "simulate",
            timeout_ms: 120_000,
            argv: [
              "python3",
              "tools/simulate_fortune500.py",
              "examples/fortune500-fibo/enterprise.json"
            ]
          }
        ]
      }
    }
  end

  # ------------------------------------------------------------------

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-autonomic-test-#{label}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    {out, 0} = System.cmd("sh", ["-c", ~s(cd "$1" && pwd -P), "sh", dir])
    String.trim(out)
  end

  defp git(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
    String.trim(out)
  end
end
