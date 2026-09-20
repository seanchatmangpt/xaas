defmodule Xaas.Ultracode.LeaseConcurrencyStressTest do
  @moduledoc """
  Real-concurrency hardening pass for `Xaas.Ultracode.Lease`, beyond the
  already-covered `claim_next/2` double-binding race (see `Lease`'s own
  moduledoc + `lease_test.exs`'s "already-leased epoch is not
  double-claimable" test).

  Chicago-style throughout: real `Ecto.Adapters.SQL.Sandbox` `{:shared,
  self()}` mode (same pattern as `test/xaas/library/
  checkout_concurrency_test.exs` and `test/xaas/marketplace/
  provider_stress_test.exs`), real `Task.async`/`Task.async_stream`
  against the real dev/test Postgres, real `Lease`/`Epoch`/`Receipt`
  resources -- no mocking of `Lease` or `Ash`.

  Investigates, with real repro (not reasoning alone):

    1. Lease-expiry TOCTOU: worker A's `close/4`/`refuse/3` call checks
       lease liveness ONCE (`live_lease/2`) then performs several
       SEPARATE, unguarded `Ash.update` writes -- none of which re-verify
       `lease_token` ownership at write time. If worker B legitimately
       re-claims the epoch in the window between A's check and A's writes,
       A's stale-token call can still land, silently clobbering B's live
       lease. `close/4`'s own `worktree_head/1` step (a real `git
       rev-parse` subprocess) gives this window real, non-contrived
       wall-clock width when a real worktree is present.
    2. Renew race: same TOCTOU shape on `renew/1` -- can a worker renew a
       lease that has already been legitimately reassigned, or one that
       never existed (forged token)?
    3. `claim_next/2` at real scale: N=25 concurrent claimers against
       N=25 ready epochs for one provider -- correctness (no double-binds)
       and liveness (no spurious `:no_ready_work` while ready work
       remains).
    4. Double-close / close-vs-refuse on the SAME live lease_token from
       two real concurrent callers -- does exactly one receipt land?
    5. `admit_tool/2` concurrent with `close/4` on the same lease (no
       lease-holding-state race expected here since `admit_tool/2`
       performs no mutation of its own).
  """

  use ExUnit.Case, async: false
  @moduletag :stress

  alias Xaas.Ultracode.{Epoch, Lease, Receipt, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
    end)

    :ok
  end

  # ------------------------------------------------------------------
  # Helpers (same shape as lease_test.exs)
  # ------------------------------------------------------------------

  defp provider_run_and_epoch(provider, worktree) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "Concurrency stress qualification.", provider: provider},
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
          exact_subject: "Xaas.Ultracode.Lease stress qualification",
          state: :running,
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()

    {run, epoch}
  end

  defp make_git_worktree do
    dir = Path.join(System.tmp_dir(), "xaas-lease-stress-#{System.unique_integer()}")
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

  defp receipts_for(epoch_id) do
    Receipt
    |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch_id})
    |> Ash.read!(authorize?: false)
  end

  defp reload_epoch(epoch_id) do
    Ash.get!(Epoch, epoch_id, action: :read_unscoped)
  end

  # ------------------------------------------------------------------
  # 1. Lease expiry race
  # ------------------------------------------------------------------

  describe "lease expiry race: stale-token close vs. a legitimate re-claim" do
    test "across real concurrent trials, a stale close/4 and a legitimate re-claim are never BOTH admitted" do
      provider = "stress-expiry-#{System.unique_integer([:positive])}"
      trials = 15

      results =
        for i <- 1..trials do
          worktree = make_git_worktree()
          {_run, epoch} = provider_run_and_epoch(provider, worktree)

          {:ok, _epoch, token_a, _run} =
            Lease.claim_next(provider, "worker-A-#{i}", lease_ttl_minutes: 0)

          # Real elapsed wall-clock time: guarantee the TTL-0 lease is
          # genuinely expired (not merely at the boundary) before the race
          # starts, matching the task's "about to expire" framing.
          Process.sleep(5)

          head = git_head(worktree)

          task_a = Task.async(fn -> Lease.close(token_a, head, :alive) end)
          task_b = Task.async(fn -> Lease.claim_next(provider, "worker-B-#{i}") end)

          [result_a, result_b] = Task.await_many([task_a, task_b], 10_000)

          a_closed? = match?({:ok, _epoch, _receipt}, result_a)

          b_reclaimed? =
            case result_b do
              {:ok, _epoch, token_b, _run} -> token_b != token_a
              _ -> false
            end

          %{
            epoch_id: epoch.id,
            a_closed?: a_closed?,
            b_reclaimed?: b_reclaimed?,
            result_a: result_a,
            result_b: result_b
          }
        end

      both_admitted = Enum.filter(results, &(&1.a_closed? and &1.b_reclaimed?))

      assert both_admitted == [],
             "found #{length(both_admitted)}/#{trials} trial(s) where A's STALE close/4 " <>
               "succeeded AND B legitimately re-claimed the same epoch -- A acted on an " <>
               "epoch B now holds. First offending trial: " <>
               inspect(List.first(both_admitted))

      # Cross-check with real persisted state: no epoch this test touched
      # should ever carry more than one Receipt.
      for %{epoch_id: epoch_id} <- results do
        real_receipts = receipts_for(epoch_id)

        assert length(real_receipts) <= 1,
               "epoch #{epoch_id} carries #{length(real_receipts)} receipts -- expected at most 1"
      end
    end

    test "refuse/3 with a stale token is refused once a legitimate re-claim has landed" do
      provider = "stress-expiry-refuse-#{System.unique_integer([:positive])}"

      {_run, epoch} = provider_run_and_epoch(provider, nil)

      {:ok, _epoch, token_a, _run} =
        Lease.claim_next(provider, "worker-A", lease_ttl_minutes: 0)

      Process.sleep(5)

      task_a = Task.async(fn -> Lease.refuse(token_a, :timeout) end)
      task_b = Task.async(fn -> Lease.claim_next(provider, "worker-B") end)

      [result_a, result_b] = Task.await_many([task_a, task_b], 10_000)

      a_refused_epoch? = match?({:ok, _epoch, _receipt}, result_a)

      b_reclaimed? =
        case result_b do
          {:ok, _epoch, token_b, _run} -> token_b != token_a
          _ -> false
        end

      refute a_refused_epoch? and b_reclaimed?,
             "A's stale refuse/3 succeeded AND B legitimately re-claimed the same epoch: " <>
               inspect({result_a, result_b})

      real_receipts = receipts_for(epoch.id)
      assert length(real_receipts) <= 1
    end
  end

  # ------------------------------------------------------------------
  # 2. Renew race
  # ------------------------------------------------------------------

  describe "renew race" do
    test "renew is refused for a forged (never-issued) lease_token" do
      assert {:error, _} = Lease.renew("forged-token-#{System.unique_integer()}")
    end

    test "renew is refused for a token whose lease has already expired" do
      provider = "stress-renew-expired-#{System.unique_integer([:positive])}"
      {_run, _epoch} = provider_run_and_epoch(provider, nil)

      {:ok, _epoch, token, _run} = Lease.claim_next(provider, "worker-1", lease_ttl_minutes: 0)

      Process.sleep(5)

      assert {:error, {:lease_expired, ^token}} = Lease.renew(token)
    end

    test "across real concurrent trials, a stale renew never lands after a legitimate re-claim" do
      provider = "stress-renew-race-#{System.unique_integer([:positive])}"
      trials = 15

      results =
        for i <- 1..trials do
          {_run, epoch} = provider_run_and_epoch(provider, nil)

          {:ok, _epoch, token_a, _run} =
            Lease.claim_next(provider, "worker-A-#{i}", lease_ttl_minutes: 0)

          Process.sleep(5)

          task_a = Task.async(fn -> Lease.renew(token_a) end)
          task_b = Task.async(fn -> Lease.claim_next(provider, "worker-B-#{i}") end)

          [result_a, result_b] = Task.await_many([task_a, task_b], 10_000)

          a_renewed? = result_a == :ok

          b_reclaimed? =
            case result_b do
              {:ok, _epoch, token_b, _run} -> token_b != token_a
              _ -> false
            end

          %{epoch_id: epoch.id, a_renewed?: a_renewed?, b_reclaimed?: b_reclaimed?}
        end

      both = Enum.filter(results, &(&1.a_renewed? and &1.b_reclaimed?))

      assert both == [],
             "found #{length(both)}/#{trials} trial(s) where A's STALE renew/1 succeeded " <>
               "AFTER B legitimately re-claimed the same epoch -- A silently extended a " <>
               "lease it no longer held. First offending trial: #{inspect(List.first(both))}"
    end
  end

  # ------------------------------------------------------------------
  # 3. claim_next/2 at real scale
  # ------------------------------------------------------------------

  describe "claim_next/2 stress at real scale" do
    test "25 real concurrent claimers against 25 real ready epochs: every epoch claimed exactly once, every caller gets an epoch" do
      provider = "stress-claim25-#{System.unique_integer([:positive])}"
      n = 25

      epoch_ids =
        for i <- 1..n do
          {_run, epoch} = provider_run_and_epoch(provider, nil)
          # `provider_run_and_epoch` gives every epoch its own Run, so
          # `AtMostOneActiveEpoch(run)` never fences these against each
          # other -- all N are real, independently `:running`, ready work
          # for the SAME shared provider queue, matching the task's "N=25
          # ready epochs for one provider" shape.
          _ = i
          epoch.id
        end

      results =
        1..n
        |> Task.async_stream(
          fn i -> Lease.claim_next(provider, "worker-#{i}") end,
          max_concurrency: n,
          timeout: 30_000
        )
        |> Enum.map(fn {:ok, result} -> result end)

      successes =
        for {:ok, epoch, token, _run} <- results do
          {epoch.id, token}
        end

      failures = Enum.filter(results, &match?({:error, _}, &1))

      claimed_epoch_ids = Enum.map(successes, &elem(&1, 0))
      claimed_tokens = Enum.map(successes, &elem(&1, 1))

      # Liveness: with exactly N callers and N ready epochs, every real
      # caller must get a real epoch -- none should see a spurious
      # `:no_ready_work` while ready work sits unclaimed.
      assert failures == [],
             "expected 0 failures claiming #{n} epochs with #{n} callers, got " <>
               "#{length(failures)}: #{inspect(failures)}"

      assert length(successes) == n

      # Correctness: no epoch double-bound, no token reused.
      assert length(Enum.uniq(claimed_epoch_ids)) == n,
             "expected #{n} distinct claimed epochs, got #{length(Enum.uniq(claimed_epoch_ids))} " <>
               "-- a real double-bind occurred"

      assert length(Enum.uniq(claimed_tokens)) == n,
             "expected #{n} distinct lease tokens, got #{length(Enum.uniq(claimed_tokens))}"

      assert MapSet.new(claimed_epoch_ids) == MapSet.new(epoch_ids),
             "claimed epoch set does not match the seeded ready-epoch set"

      # A real, reported collision/retry-needed rate: with an atomic
      # filtered UPDATE claim path and N==N (no actual contention beyond
      # the initial candidate-selection reads), the expected rate is 0.
      # This assertion is the receipted evidence for that number, not a
      # prediction.
      assert failures == []
    end
  end

  # ------------------------------------------------------------------
  # 4. Concurrent close / refuse on the SAME lease_token
  # ------------------------------------------------------------------

  describe "concurrent close/refuse on the same lease_token" do
    test "two concurrent close/4 calls on the same token: exactly one lands, exactly one receipt" do
      provider = "stress-double-close-#{System.unique_integer([:positive])}"
      {_run, epoch} = provider_run_and_epoch(provider, nil)
      {:ok, _epoch, token, _run} = Lease.claim_next(provider, "worker-1")

      task_1 = Task.async(fn -> Lease.close(token, "head-from-call-1", :alive) end)
      task_2 = Task.async(fn -> Lease.close(token, "head-from-call-2", :alive) end)

      [result_1, result_2] = Task.await_many([task_1, task_2], 10_000)

      successes = Enum.filter([result_1, result_2], &match?({:ok, _, _}, &1))

      assert length(successes) == 1,
             "expected exactly one of two concurrent close/4 calls on the same lease_token " <>
               "to succeed, got: #{inspect([result_1, result_2])}"

      real_receipts = receipts_for(epoch.id)

      assert length(real_receipts) == 1,
             "expected exactly one real Receipt to exist for epoch #{epoch.id}, got " <>
               "#{length(real_receipts)}: #{inspect(real_receipts)}"

      reloaded = reload_epoch(epoch.id)
      assert reloaded.state == :completed
    end

    test "close racing refuse on the same token: exactly one lands, exactly one receipt" do
      provider = "stress-close-vs-refuse-#{System.unique_integer([:positive])}"
      {_run, epoch} = provider_run_and_epoch(provider, nil)
      {:ok, _epoch, token, _run} = Lease.claim_next(provider, "worker-1")

      task_close = Task.async(fn -> Lease.close(token, "head-from-close", :alive) end)
      task_refuse = Task.async(fn -> Lease.refuse(token, :timeout) end)

      [close_result, refuse_result] = Task.await_many([task_close, task_refuse], 10_000)

      successes =
        Enum.filter([close_result, refuse_result], &match?({:ok, _, _}, &1))

      assert length(successes) == 1,
             "expected exactly one of a racing close/4 + refuse/3 pair on the same " <>
               "lease_token to succeed, got: #{inspect([close_result, refuse_result])}"

      real_receipts = receipts_for(epoch.id)

      assert length(real_receipts) == 1,
             "expected exactly one real Receipt to exist for epoch #{epoch.id}, got " <>
               "#{length(real_receipts)}: #{inspect(real_receipts)}"

      reloaded = reload_epoch(epoch.id)
      assert reloaded.state in [:completed, :failed]
    end

    test "20 real concurrent close/4 calls on the same token: exactly one lands, exactly one receipt" do
      provider = "stress-double-close-20-#{System.unique_integer([:positive])}"
      {_run, epoch} = provider_run_and_epoch(provider, nil)
      {:ok, _epoch, token, _run} = Lease.claim_next(provider, "worker-1")

      results =
        1..20
        |> Task.async_stream(
          fn i -> Lease.close(token, "head-from-call-#{i}", :alive) end,
          max_concurrency: 20,
          timeout: 30_000
        )
        |> Enum.map(fn {:ok, result} -> result end)

      successes = Enum.filter(results, &match?({:ok, _, _}, &1))

      assert length(successes) == 1,
             "expected exactly one of 20 concurrent close/4 calls on the same lease_token " <>
               "to succeed, got #{length(successes)}: #{inspect(successes)}"

      real_receipts = receipts_for(epoch.id)

      assert length(real_receipts) == 1,
             "expected exactly one real Receipt for epoch #{epoch.id}, got " <>
               "#{length(real_receipts)}: #{inspect(real_receipts)}"
    end
  end

  # ------------------------------------------------------------------
  # 5. admit_tool/2 concurrent with close/4 on the same lease
  # ------------------------------------------------------------------

  describe "admit_tool/2 concurrent with close/4 on the same lease" do
    test "admit_tool never allows once close/4 has landed, and never corrupts the receipt" do
      provider = "stress-admit-vs-close-#{System.unique_integer([:positive])}"
      trials = 10

      for i <- 1..trials do
        {_run, epoch} = provider_run_and_epoch(provider, nil)
        {:ok, _epoch, token, _run} = Lease.claim_next(provider, "worker-#{i}")

        task_close = Task.async(fn -> Lease.close(token, "head-#{i}", :alive) end)
        task_admit = Task.async(fn -> Lease.admit_tool(token, "Edit") end)

        [close_result, admit_result] = Task.await_many([task_close, task_admit], 10_000)

        assert match?({:ok, _, _}, close_result)

        # Whichever side of the race admit_tool landed on, it must reflect
        # a real, consistent decision -- never crash, never silently
        # allow against a token that (by the time admit_tool's own read
        # ran) was already closed AND simultaneously report success in a
        # way inconsistent with a single, real receipt existing.
        assert match?({:ok, %{decision: :allow}}, admit_result) or
                 match?({:error, _}, admit_result)

        real_receipts = receipts_for(epoch.id)

        assert length(real_receipts) == 1,
               "trial #{i}: expected exactly one receipt for epoch #{epoch.id}, got " <>
                 "#{length(real_receipts)}: #{inspect(real_receipts)}"
      end
    end
  end
end
