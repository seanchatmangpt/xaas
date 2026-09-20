defmodule Xaas.Ultracode.AutonomicJudgeTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Chicago-style qualification of the wave loop's judge seam
  (`Xaas.Ultracode.Autonomic.judge_receipt/1`): real sandboxed Postgres, real
  Run/Epoch/Receipt rows, real git worktrees under the real containment root,
  and REAL verifier-suite subprocesses through the real `Lease.close/4` -- the
  court is never mocked; every receipt asserted on was sealed by the fabric
  against a real head (the harness mirrors `LeaseVerifierTest`).

  The property under test: the promotion decision follows the FABRIC's court
  verdict, never the worker's self-assessment. An honest `partial_alive` on a
  court-pass head is accepted WITHOUT repair (the wasted-work fix); a court
  fail repairs regardless of standing; an unverified head repairs even when
  the worker is honest; a fabricated `alive` with a spoofed verdict never
  promotes.
  """

  alias Xaas.Ultracode.{Autonomic, Epoch, Lease, Run}

  @provider "zcode-judge-test"
  @env %{"PATH" => "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    original = %{
      suites: Application.get_env(:xaas, :ultracode_verifier_suites),
      root: Application.get_env(:xaas, :ultracode_worktree_root),
      seam: Application.get_env(:xaas, :ultracode_judge_accept_court_verified_partial)
    }

    root = canonical(mktmp("root"))
    Application.put_env(:xaas, :ultracode_worktree_root, root)

    # Default (unset) = seam ON; the seam-off test sets it explicitly.
    Application.delete_env(:xaas, :ultracode_judge_accept_court_verified_partial)

    on_exit(fn ->
      Application.put_env(:xaas, :ultracode_verifier_suites, original.suites)
      Application.put_env(:xaas, :ultracode_worktree_root, original.root)

      if is_nil(original.seam) do
        Application.delete_env(:xaas, :ultracode_judge_accept_court_verified_partial)
      else
        Application.put_env(
          :xaas,
          :ultracode_judge_accept_court_verified_partial,
          original.seam
        )
      end
    end)

    %{root: root}
  end

  defp sh(id, script, extra \\ %{}),
    do: Map.merge(%{id: id, argv: ["/bin/sh", "-c", script], timeout_ms: 10_000}, extra)

  defp register(name, steps) do
    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      name => %{env: @env, steps: steps}
    })
  end

  # (a) The wasted-work fix: an honest worker closes partial_alive because it
  # cannot self-verify; the fabric's court PASSES the exact head; the judge
  # accepts -- no repair attempt consumed downstream.
  test "an honest partial_alive on a court-pass head is accepted without repair",
       %{root: root} do
    register("j-pass", [sh("ok", "true")])
    {token, head, _wt} = leased(root, "j-pass")

    {:ok, _epoch, receipt} =
      Lease.close(token, head, :partial_alive, %{"note" => "worker cannot self-verify"})

    # The fabric sealed: honest standing kept (never upgraded), court pass,
    # head verified.
    assert receipt.outcome == :partial_alive
    assert receipt.evidence["head_verified"] == true
    assert receipt.evidence["fabric_verifier"]["status"] == "pass"

    assert Autonomic.judge_receipt(receipt) == :accept
  end

  # Regression guard: the pre-existing alive law is unchanged.
  test "an alive court-pass head is still accepted", %{root: root} do
    register("j-pass", [sh("ok", "true")])
    {token, head, _wt} = leased(root, "j-pass")

    {:ok, _epoch, receipt} = Lease.close(token, head, :alive)
    assert receipt.outcome == :alive
    assert Autonomic.judge_receipt(receipt) == :accept
  end

  # (b) A court fail repairs regardless of the (fabric-adjusted) standing --
  # whether the worker claimed alive or was honest about partial.
  test "a court fail repairs regardless of the claimed standing", %{root: root} do
    register("j-fail", [sh("red", "echo 'FAILED (failures=2)'; exit 1")])

    {token, head, _wt} = leased(root, "j-fail")
    {:ok, _epoch, receipt} = Lease.close(token, head, :alive)

    assert receipt.outcome == :build_broken
    assert receipt.evidence["head_verified"] == true

    assert {:repair, reason} = Autonomic.judge_receipt(receipt)
    assert reason =~ "court verdict fail"

    {token2, head2, _wt2} = leased(root, "j-fail")
    {:ok, _epoch2, receipt2} = Lease.close(token2, head2, :partial_alive)

    assert receipt2.outcome == :build_broken
    assert {:repair, _} = Autonomic.judge_receipt(receipt2)
  end

  # (c) Honesty preserved: partial_alive with an UNVERIFIED head repairs.
  # The fabric could not confirm the head, so there is no confirmed subject
  # for any court to have passed -- the seam never reaches this receipt.
  test "a partial_alive with an unverified head repairs", %{root: root} do
    register("j-pass", [sh("ok", "true")])
    {token, head, wt} = leased(root, "j-pass")

    # The worktree stops being a repository after the claim (the row keeps
    # the path): `Lease.close/4`'s head verification genuinely fails.
    File.rm_rf!(Path.join(wt, ".git"))

    {:ok, _epoch, receipt} = Lease.close(token, head, :partial_alive)

    assert receipt.outcome == :partial_alive
    assert receipt.evidence["head_verified"] == false
    assert receipt.evidence["verifier_unavailable"]
    refute Map.has_key?(receipt.evidence, "fabric_verifier")

    assert {:repair, reason} = Autonomic.judge_receipt(receipt)
    assert reason =~ "no fabric verifier verdict"
  end

  # The other unverified-head shape: the claimed head is not the real one, so
  # the court never runs and the terminal standing repairs.
  test "a head mismatch repairs even when the worker claimed alive", %{root: root} do
    register("j-marker", [sh("untouched", "true")])
    {token, _head, _wt} = leased(root, "j-marker")

    {:ok, _epoch, receipt} = Lease.close(token, String.duplicate("b", 40), :alive)

    assert receipt.outcome == :build_broken
    assert receipt.evidence["head_verified"] == false
    refute Map.has_key?(receipt.evidence, "fabric_verifier")
    assert {:repair, _} = Autonomic.judge_receipt(receipt)
  end

  # (c, complementary) A verified head with an UNVERIFIABLE court (timeout) is
  # still a repair: the seam accepts a court PASS, never a non-pass verdict.
  test "a court timeout repairs even with the head verified", %{root: root} do
    register("j-slow", [sh("hang", "sleep 30", %{timeout_ms: 300})])
    {token, head, _wt} = leased(root, "j-slow")

    {:ok, _epoch, receipt} = Lease.close(token, head, :alive)

    assert receipt.outcome == :partial_alive
    assert receipt.evidence["head_verified"] == true
    assert receipt.evidence["fabric_verifier"]["status"] == "timeout"

    assert {:repair, reason} = Autonomic.judge_receipt(receipt)
    assert reason =~ "court verdict timeout"
  end

  # (d) The court is the authority: a fabricated alive with a spoofed passing
  # verdict dies twice -- the fabric drops the worker's evidence key and seals
  # its own failing verdict, and the judge repairs on that verdict.
  test "a fabricated alive with a spoofed court verdict never promotes", %{root: root} do
    register("j-fail", [sh("red", "exit 1")])
    {token, head, _wt} = leased(root, "j-fail")

    spoof = %{
      "fabric_verifier" => %{"status" => "pass", "suite" => "j-fail"},
      "head_verified" => true
    }

    {:ok, _epoch, receipt} = Lease.close(token, head, :alive, spoof)

    assert receipt.outcome == :build_broken
    assert receipt.evidence["fabric_verifier"]["status"] == "fail"

    assert {:repair, reason} = Autonomic.judge_receipt(receipt)
    assert reason =~ "court verdict fail"
  end

  # Fail-closed: standing alone never promotes. An alive claim on a verified
  # head with NO court verdict (the run names no suite) still repairs.
  test "an alive claim with no court verdict repairs", %{root: root} do
    {token, head, _wt} = leased(root, nil)

    {:ok, _epoch, receipt} = Lease.close(token, head, :alive, %{"note" => "trust me"})

    assert receipt.outcome == :alive
    assert receipt.evidence["head_verified"] == true
    refute Map.has_key?(receipt.evidence, "fabric_verifier")

    assert {:repair, reason} = Autonomic.judge_receipt(receipt)
    assert reason =~ "no fabric verifier verdict"
  end

  # Non-alive-family terminal standings have nothing to verify and repair.
  test "a terminal blocked standing repairs", %{root: root} do
    register("j-pass", [sh("ok", "true")])
    {token, head, _wt} = leased(root, "j-pass")

    {:ok, _epoch, receipt} = Lease.close(token, head, :blocked)

    assert receipt.outcome == :blocked
    assert {:repair, _} = Autonomic.judge_receipt(receipt)
  end

  # The seam is a real seam: false restores the strict alive-only predicate
  # (the pre-fix behavior, for operator rollback).
  test "seam off restores the strict alive-only predicate", %{root: root} do
    Application.put_env(:xaas, :ultracode_judge_accept_court_verified_partial, false)

    register("j-pass", [sh("ok", "true")])
    {token, head, _wt} = leased(root, "j-pass")

    {:ok, _epoch, receipt} = Lease.close(token, head, :partial_alive)

    assert receipt.outcome == :partial_alive
    assert receipt.evidence["head_verified"] == true
    assert receipt.evidence["fabric_verifier"]["status"] == "pass"

    assert {:repair, _} = Autonomic.judge_receipt(receipt)
  end

  # ------------------------------------------------------------------

  # A leased epoch on a real worktree under the containment root; returns
  # {token, confirmed_head, worktree}.
  defp leased(root, suite) do
    worktree = git_worktree(root)

    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "Judge seam qualification.", provider: @provider, verifier_suite: suite},
        authorize?: false
      )
      |> Ash.create()

    {:ok, epoch} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "judge qualification",
          state: :running,
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()

    {:ok, _epoch, token, _run} = Lease.claim_next(@provider, "worker-judge", epoch_id: epoch.id)
    {token, git_head(worktree), worktree}
  end

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-judge-test-#{label}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp canonical(path) do
    {out, 0} = System.cmd("sh", ["-c", ~s(cd "$1" && pwd -P), "sh", path])
    String.trim(out)
  end

  defp git_worktree(root) do
    dir = Path.join(root, "wt-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    {_, 0} = System.cmd("git", ["-C", dir, "init", "--quiet"], stderr_to_stdout: true)

    {_, 0} =
      System.cmd("git", ["-C", dir, "commit", "--allow-empty", "-m", "init", "--quiet"],
        stderr_to_stdout: true,
        env: [
          {"GIT_AUTHOR_NAME", "t"},
          {"GIT_AUTHOR_EMAIL", "t@t"},
          {"GIT_COMMITTER_NAME", "t"},
          {"GIT_COMMITTER_EMAIL", "t@t"}
        ]
      )

    canonical(dir)
  end

  defp git_head(worktree) do
    {out, 0} = System.cmd("git", ["-C", worktree, "rev-parse", "HEAD"])
    String.trim(out)
  end
end
