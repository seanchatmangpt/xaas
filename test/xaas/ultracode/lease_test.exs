defmodule Xaas.Ultracode.LeaseTest do
  @moduledoc """
  Chicago-style qualification for the ActuationLease edge on the existing
  Ultracode seam (Run/Epoch/Receipt — no new resources).

  Proves: race-safe claim over a provider-pull run, lease-keyed admission
  court (construction allowed, consequence refused under the no-ceiling
  fence, unknown tool fenced), head-verified closure sealing the existing
  Receipt vocabulary, typed refusal, and that legacy provider-less runs
  keep complete-next-cycle reactor semantics.
  """

  use ExUnit.Case, async: true

  alias Xaas.Ultracode.{Epoch, Lease, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp provider_run_and_epoch(provider \\ "zcode-test", worktree \\ nil) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "Qualify the lease edge.", provider: provider},
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
          exact_subject: "Xaas.Ultracode.Lease qualification",
          state: :running,
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()

    {run, epoch}
  end

  describe "claim_next/3" do
    test "binds a lease to the oldest running epoch of a provider run" do
      {run, epoch} = provider_run_and_epoch()

      assert {:ok, leased, token, run_ctx} = Lease.claim_next("zcode-test", "worker-1")
      assert leased.id == epoch.id
      assert leased.lease_token == token
      assert leased.leased_to == "worker-1"
      assert DateTime.compare(leased.lease_expires_at, DateTime.utc_now()) == :gt
      assert run_ctx.id == run.id
      assert run_ctx.goal == run.goal
    end

    test "no ready work without a provider-pull run" do
      provider_run_and_epoch(nil)

      assert {:error, :no_ready_work} = Lease.claim_next("zcode-test", "worker-1")
    end

    test "already-leased epoch is not double-claimable" do
      provider_run_and_epoch()

      {:ok, _epoch, _token, _run} = Lease.claim_next("zcode-test", "worker-1")

      assert {:error, :no_ready_work} = Lease.claim_next("zcode-test", "worker-2")
    end
  end

  describe "admit_tool/2" do
    test "allows construction tools under a live lease" do
      provider_run_and_epoch()
      {:ok, _epoch, token, _run} = Lease.claim_next("zcode-test", "worker-1")

      assert {:ok, %{decision: :allow}} = Lease.admit_tool(token, "Edit")
    end

    test "refuses consequence tools under the no-ceiling fence" do
      provider_run_and_epoch()
      {:ok, _epoch, token, _run} = Lease.claim_next("zcode-test", "worker-1")

      assert {:error, {:refused_no_authority, "git_push"}} = Lease.admit_tool(token, "git_push")
      assert {:error, {:refused_no_authority, "Bash"}} = Lease.admit_tool(token, "Bash")
    end

    test "unknown tool classes are fenced" do
      provider_run_and_epoch()
      {:ok, _epoch, token, _run} = Lease.claim_next("zcode-test", "worker-1")

      assert {:error, {:unknown_tool_class, "TimeMachine"}} = Lease.admit_tool(token, "TimeMachine")
    end

    test "no lease, no admission" do
      assert {:error, _} = Lease.admit_tool("no-such-lease", "Edit")
    end
  end

  describe "close/4" do
    test "seals an alive receipt when final_head matches the worktree HEAD" do
      worktree = make_git_worktree()
      provider_run_and_epoch("zcode-test", worktree)
      {:ok, _epoch, token, _run} = Lease.claim_next("zcode-test", "worker-1")

      assert {:ok, epoch, receipt} = Lease.close(token, git_head(worktree), :alive, %{"verifier" => "mix test"})
      assert epoch.state == :completed
      assert epoch.final_head == git_head(worktree)
      assert receipt.outcome == :alive
      assert receipt.evidence["head_verified"] == true
    end

    test "downgrades to build_broken on head mismatch" do
      worktree = make_git_worktree()
      provider_run_and_epoch("zcode-test", worktree)
      {:ok, _epoch, token, _run} = Lease.claim_next("zcode-test", "worker-1")

      real = git_head(worktree)
      fake = "0" <> String.slice(real, 1..-1//1)

      assert {:ok, _epoch, receipt} = Lease.close(token, fake, :alive)
      assert receipt.outcome == :build_broken
      assert receipt.evidence["head_verified"] == false
    end

    test "downgrades to partial_alive when no worktree is verifiable" do
      provider_run_and_epoch("zcode-test", nil)
      {:ok, _epoch, token, _run} = Lease.claim_next("zcode-test", "worker-1")

      assert {:ok, _epoch, receipt} = Lease.close(token, "abc123", :alive)
      assert receipt.outcome == :partial_alive
      assert receipt.evidence["verifier_unavailable"]
    end
  end

  describe "refuse/3" do
    test "lands the epoch failed with a refused receipt" do
      provider_run_and_epoch()
      {:ok, _epoch, token, _run} = Lease.claim_next("zcode-test", "worker-1")

      assert {:ok, epoch, receipt} = Lease.refuse(token, :refused_no_authority)
      assert epoch.state == :failed
      assert receipt.outcome == :refused
      assert receipt.evidence["refusal_reason"] == "refused_no_authority"
    end
  end

  describe "EpochReactor provider-pull semantics" do
    test "provider-pull running epoch awaits provider instead of auto-completing" do
      {_run, epoch} = provider_run_and_epoch()

      assert {:ok, result} = Reactor.run(Xaas.Ultracode.EpochReactor, %{epoch_id: epoch.id})

      assert result.action_taken == :await_provider
      assert result.outcome == :alive

      reloaded = Ash.get!(Epoch, epoch.id)
      assert reloaded.state == :running
    end

    test "legacy provider-less run keeps complete-next-cycle semantics" do
      {_run, epoch} = provider_run_and_epoch(nil)

      assert {:ok, result} = Reactor.run(Xaas.Ultracode.EpochReactor, %{epoch_id: epoch.id})

      assert result.action_taken == :complete
      assert Ash.get!(Epoch, epoch.id).state == :completed
    end
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp make_git_worktree do
    dir = Path.join(System.tmp_dir(), "xaas-lease-test-#{System.unique_integer()}")
    File.mkdir_p!(dir)

    System.cmd("git", ["-C", dir, "init", "--quiet"], stderr_to_stdout: true)

    System.cmd(
      "git",
      ["-C", dir, "commit", "--allow-empty", "-m", "init", "--quiet"],
      stderr_to_stdout: true,
      env: [
        {"GIT_AUTHOR_NAME", "test"},
        {"GIT_AUTHOR_EMAIL", "test@test"},
        {"GIT_COMMITTER_NAME", "test"},
        {"GIT_COMMITTER_EMAIL", "test@test"}
      ]
    )

    dir
  end

  defp git_head(worktree) do
    {out, 0} = System.cmd("git", ["-C", worktree, "rev-parse", "HEAD"])
    String.trim(out)
  end
end
