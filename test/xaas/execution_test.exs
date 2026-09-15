defmodule Xaas.ExecutionTest do
  @moduledoc """
  Chicago-style qualification for the execution-fabric lease kernel.

  Real Ash resources, real sandboxed Postgres, real bulk-update claims. These
  tests prove the load-bearing invariants of the fabric: race-safe claiming,
  lease expiry sweep, per-consequence admission with authority ceilings,
  fail-closed unknown-tool handling, and head-verified closure downgrade.
  """

  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Execution
  alias Xaas.Operations.WorkContract

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    {:ok, worker} =
      Execution.register_worker(%{
        provider: "zcode-test",
        provider_worker_id: "worker-#{System.unique_integer()}",
        quota_lane: :scarce_frontier,
        capabilities: %{"tools" => ["Edit", "Bash"]}
      })

    %{worker: worker}
  end

  defp pending_contract(attrs \\ %{}) do
    {:ok, contract} =
      Execution.submit_contract(
        Map.merge(
          %{
            work_id: "work-#{System.unique_integer([:positive])}",
            repository: "seanchatmangpt/xaas",
            base_sha: "e164ee5c782b17db5c2f54a188de8d4250fb9235",
            goal: "Advance one bounded contract for qualification.",
            acceptance: %{"tests" => ["mix test test/xaas/execution_test.exs"]},
            verifier: %{"commands" => ["mix test"]},
            quota_lane: :scarce_frontier
          },
          Map.new(attrs, fn {k, v} -> {to_string(k), v} end)
        )
      )

    contract
  end

  describe "register_worker/1" do
    test "upserts on provider identity", %{worker: worker} do
      {:ok, again} =
        Execution.register_worker(%{
          provider: worker.provider,
          provider_worker_id: worker.provider_worker_id,
          model_class: "glm-5.3-flash"
        })

      assert again.id == worker.id
      assert again.model_class == "glm-5.3-flash"
    end
  end

  describe "claim_next/2" do
    test "claims oldest pending contract and binds a lease", %{worker: worker} do
      contract = pending_contract()

      assert {:ok, claimed, token} = Execution.claim_next(worker)
      assert claimed.id == contract.id
      assert claimed.state == :claimed
      assert claimed.execution_worker_id == worker.id
      assert claimed.lease_token == token
      assert is_binary(token) and byte_size(token) > 16
      refute is_nil(claimed.lease_expires_at)
    end

    test "returns no_ready_work when queue is empty", %{worker: worker} do
      assert {:error, :no_ready_work} = Execution.claim_next(worker)
    end

    test "lane filter excludes other lanes", %{worker: worker} do
      pending_contract()

      assert {:error, :no_ready_work} = Execution.claim_next(worker, quota_lane: :free_idle)
    end

  test "sweeps expired leases to :expired before claiming", %{worker: worker} do
    pending_contract()
    {:ok, contract, _token} = Execution.claim_next(worker)

      # Age the lease past expiry directly in SQL: the honest way to move
      # time in a sandboxed test.
      Xaas.Repo.query!(
        "UPDATE work_contracts SET lease_expires_at = now() - interval '1 hour' WHERE id = $1",
        [Ecto.UUID.dump!(contract.id)]
      )

      assert {:error, :no_ready_work} = Execution.claim_next(worker)

      expired =
        WorkContract
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(id == ^contract.id)
        |> Ash.read_one!(authorize?: false)

      assert expired.state == :expired
    end
  end

  describe "admit_tool/3" do
    test "allows construction tools under a live lease", %{worker: worker} do
      pending_contract()
      {:ok, _contract, token} = Execution.claim_next(worker)

      assert {:ok, %{decision: :allow}} = Execution.admit_tool(token, "Edit", %{})
    end

    test "denies consequence tools above the authority ceiling", %{worker: worker} do
      pending_contract(authority_ceiling: "CONSTRUCT_AND_EXECUTE")
      {:ok, _contract, token} = Execution.claim_next(worker)

      assert {:error, {:tool_above_authority_ceiling, "git_push", "CONSTRUCT_AND_EXECUTE"}} =
               Execution.admit_tool(token, "git_push", %{})
    end

    test "stronger ceiling admits consequence tool", %{worker: worker} do
      pending_contract(authority_ceiling: "PUBLISH")
      {:ok, _contract, token} = Execution.claim_next(worker)

      assert {:ok, %{decision: :allow}} = Execution.admit_tool(token, "git_push", %{})
    end

    test "denies unknown tool classes as a fence", %{worker: worker} do
      pending_contract(authority_ceiling: "PUBLISH")
      {:ok, _contract, token} = Execution.claim_next(worker)

      assert {:error, {:unknown_tool_class, "TimeMachine"}} =
               Execution.admit_tool(token, "TimeMachine", %{})
    end

    test "denies without any lease", _ctx do
      assert {:error, _} = Execution.admit_tool("no-such-lease", "Edit", %{})
    end
  end

  describe "close_candidate/4" do
    test "downgrades standing to UNKNOWN on head mismatch", %{worker: worker} do
      worktree = make_git_worktree()
      pending_contract(worktree: worktree)
      {:ok, _contract, token} = Execution.claim_next(worker)

      real_head = git_head(worktree)
      fake_head = "0" <> String.slice(real_head, 1..-1//1)

      assert {:ok, closed} = Execution.close_candidate(token, fake_head, "ALIVE")
      assert closed.state == :closed
      assert closed.standing == "UNKNOWN"
    end

    test "keeps standing when final_head matches worktree HEAD", %{worker: worker} do
      worktree = make_git_worktree()
      pending_contract(worktree: worktree)
      {:ok, _contract, token} = Execution.claim_next(worker)

      assert {:ok, closed} = Execution.close_candidate(token, git_head(worktree), "PARTIAL_ALIVE")
      assert closed.state == :closed
      assert closed.standing == "PARTIAL_ALIVE"
    end
  end

  describe "refuse/2" do
    test "records typed refusal standing", %{worker: worker} do
      pending_contract()
      {:ok, _contract, token} = Execution.claim_next(worker)

      assert {:ok, refused} = Execution.refuse(token, "REFUSED_NO_AUTHORITY")
      assert refused.state == :refused
      assert refused.standing == "REFUSED_NO_AUTHORITY"
    end
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp make_git_worktree do
    dir = Path.join(System.tmp_dir(), "xaas-exec-test-#{System.unique_integer()}")
    File.mkdir_p!(dir)

    System.cmd("git", ["-C", dir, "init", "--quiet"], stderr_to_stdout: true)

    System.cmd(
      "git",
      ["-C", dir, "commit", "--allow-empty", "-m", "init", "--quiet"],
      stderr_to_stdout: true,
      env: [{"GIT_AUTHOR_NAME", "test"}, {"GIT_AUTHOR_EMAIL", "test@test"}, {"GIT_COMMITTER_NAME", "test"}, {"GIT_COMMITTER_EMAIL", "test@test"}]
    )

    dir
  end

  defp git_head(worktree) do
    {out, 0} = System.cmd("git", ["-C", worktree, "rev-parse", "HEAD"])
    String.trim(out)
  end
end
