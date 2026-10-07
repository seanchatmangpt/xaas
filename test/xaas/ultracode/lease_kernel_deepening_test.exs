defmodule Xaas.Ultracode.LeaseKernelDeepeningTest do
  @moduledoc """
  Lane W811: standalone kernel-contract deepening for `Xaas.Ultracode.Lease`
  covering ONLY edges the existing lease courts do not:

    * (a) real TTL/expiry mechanics via the module's own clock seam
      (`:xaas, :ultracode_clock` -> `DurationBudget.now/0`): expired-token
      typed refusals, expiry exclusion from `live_leases/1`, reclaim of the
      expired epoch, and death of the stale token on re-claim;
    * (b) heartbeat keepalive (`renew/1`) and the heartbeat-during-expiry
      race as a real sequential approximation on the steppable clock;
    * (c) `admit_tool/2` court-before-registry ordering from the kernel
      side: the live-lease kernel's live-lease court runs BEFORE the
      per-provider registry -- an expired lease is a typed expiry refusal
      even when a provider override would have allowed the tool;
    * (d) `refuse/3` receipt semantics: exactly-once terminal, slot
      release, semantic-work evidence binding, close/refuse winner-take-all;
    * (e) determinism: oldest-first claim, distinct tokens, `pool_capacity/1`
      config reading, and the `:pool_at_capacity` slot recycle through
      refusal.

  No mocks: real Postgres rows in the SQL sandbox, real Ash resources, and
  time is fast-forwarded through the PRODUCTION clock seam (Application env
  `:xaas, :ultracode_clock`), never by sleeping or faking collaborators.
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{DurationBudget, Epoch, Lease, Receipt, Run}

  import Ecto.Query, only: [from: 2]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  # The production clock seam: DurationBudget.now/0 reads
  # `Application.get_env(:xaas, :ultracode_clock)`. An Agent holds the
  # clock at real-now-at-install; tests advance it explicitly. This is
  # Application env -- the documented test seam -- not a mock of Lease.
  defp install_steppable_clock do
    {:ok, agent} = Agent.start_link(fn -> DateTime.utc_now() end)

    Application.put_env(:xaas, :ultracode_clock, fn -> Agent.get(agent, & &1) end)

    on_exit(fn ->
      Application.delete_env(:xaas, :ultracode_clock)
    end)

    agent
  end

  defp clock_now(agent), do: Agent.get(agent, & &1)

  defp advance(agent, seconds) do
    Agent.update(agent, fn t -> DateTime.add(t, seconds, :second) end)
  end

  defp uninstall_clock(agent) do
    Application.delete_env(:xaas, :ultracode_clock)
    Agent.stop(agent)
  end

  defp provider_run_and_epoch(provider \\ "zcode-deepen") do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{
          goal: "W811 lease kernel deepening.",
          provider: provider,
          work_order_iri: "sjira://v26.10.6/w811",
          checkpoint_iri: "sjira://v26.10.6/w811#cp",
          graph_digest: "sha256:w811",
          repository_identity: "github.com/sac/anxaas",
          execution_repo_alias: "xaas",
          base_sha: "a0723bf600000000000000000000000000000001"
        },
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
          exact_subject: "W811 lease kernel deepening subject",
          state: :running
        },
        authorize?: false
      )
      |> Ash.create()

    {:ok, run, epoch}
  end

  defp epoch_receipts(epoch_id) do
    Receipt
    |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch_id}, authorize?: false)
    |> Ash.read!()
  end

  defp fetch_epoch(epoch_id) do
    Ash.get(Epoch, epoch_id, action: :read_unscoped, authorize?: false)
  end

  # ------------------------------------------------------------------
  # Clock seam
  # ------------------------------------------------------------------
  describe "clock seam" do
    test "DurationBudget.now/0 reads the :ultracode_clock seam; deleting the env restores real time" do
      t0 = ~U[2026-10-07 00:00:00.000000Z]
      Application.put_env(:xaas, :ultracode_clock, fn -> t0 end)
      assert DateTime.compare(DurationBudget.now(), t0) == :eq

      Application.delete_env(:xaas, :ultracode_clock)

      assert abs(DateTime.diff(DurationBudget.now(), DateTime.utc_now())) <= 1
    end
  end

  # ------------------------------------------------------------------
  # (a) Expiry semantics per the real code
  # ------------------------------------------------------------------
  describe "lease expiry mechanics" do
    test "claim writes lease_expires_at = clock + 30m TTL, claimed_at = clock, no heartbeat yet" do
      agent = install_steppable_clock()
      {:ok, _run, epoch} = provider_run_and_epoch()

      t0 = clock_now(agent)
      {:ok, leased, token, _run} = Lease.claim_next("zcode-deepen", "worker-1")

      assert leased.id == epoch.id
      assert is_binary(token)
      assert DateTime.diff(leased.lease_expires_at, t0, :second) == 30 * 60
      assert DateTime.compare(leased.claimed_at, t0) == :eq
      assert is_nil(leased.last_heartbeat_at)

      uninstall_clock(agent)
    end

    test "an expired token is a typed {:lease_expired, token} for every lease-keyed verb" do
      agent = install_steppable_clock()
      {:ok, _run, _epoch} = provider_run_and_epoch()
      {:ok, _e, token, _run} = Lease.claim_next("zcode-deepen", "worker-1")

      advance(agent, 31 * 60)

      assert {:error, {:lease_expired, ^token}} = Lease.renew(token)
      assert {:error, {:lease_expired, ^token}} = Lease.admit_tool(token, "Edit")
      assert {:error, {:lease_expired, ^token}} = Lease.close(token, "head", :partial_alive)
      assert {:error, {:lease_expired, ^token}} = Lease.refuse(token, :worker_gave_up)
      assert {:error, {:lease_expired, ^token}} = Lease.cancel(token, :worker_gave_up)

      uninstall_clock(agent)
    end

    test "an expired lease is not live capacity and its epoch is re-claimable" do
      agent = install_steppable_clock()
      {:ok, _run, epoch} = provider_run_and_epoch()
      {:ok, _e, old_token, _run} = Lease.claim_next("zcode-deepen", "worker-1")

      advance(agent, 31 * 60)

      # W840 FIX (asserted, not reasoned): live_leases/1 now judges expiry
      # on the SAME DurationBudget clock seam as the claim kernel and the
      # live-lease court -- a kernel-expired lease releases its slot, so
      # the meter, the reclaim path, and the court can never disagree.
      assert Lease.live_leases("zcode-deepen") == 0

      # The reclaim filter (`is_nil(lease_token) or lease_expires_at < now`)
      # picks the epoch up again; the bind succeeds on the SAME epoch.
      assert {:ok, leased, new_token, _run} = Lease.claim_next("zcode-deepen", "worker-2")
      assert leased.id == epoch.id
      assert new_token != old_token
      assert DateTime.compare(leased.claimed_at, clock_now(agent)) == :eq

      # The stale bearer has no capability: find_by_lease keys on the row's
      # CURRENT token, so the old token resolves to nothing.
      assert {:error, {:no_lease, ^old_token}} = Lease.admit_tool(old_token, "Edit")

      uninstall_clock(agent)
    end

    test "the lease is live exactly until the TTL boundary: strict :lt comparison" do
      agent = install_steppable_clock()
      {:ok, _run, _epoch} = provider_run_and_epoch()
      {:ok, _e, token, _run} = Lease.claim_next("zcode-deepen", "worker-1")

      # One second before the TTL: live.
      advance(agent, 30 * 60 - 1)
      assert {:ok, %{decision: :allow}} = Lease.admit_tool(token, "Edit")

      # AT the boundary (expires_at == now) live_lease/2's comparison is
      # `:lt`, so :eq is still LIVE by the strict comparison...
      advance(agent, 1)
      assert {:ok, %{decision: :allow}} = Lease.admit_tool(token, "Edit")

      # ...one second past it, the same token is expired.
      advance(agent, 1)
      assert {:error, {:lease_expired, ^token}} = Lease.admit_tool(token, "Edit")

      uninstall_clock(agent)
    end

    test "a budget-exhausted run's epoch is not ready work (claim filter)" do
      agent = install_steppable_clock()
      {:ok, run, _epoch} = provider_run_and_epoch()

      # started_at + duration_budget_seconds already in the clock's past.
      {1, nil} =
        Xaas.Repo.update_all(
          from(r in Run, where: r.id == ^run.id),
          set: [
            started_at: DateTime.add(clock_now(agent), -100, :second),
            duration_budget_seconds: 60
          ]
        )

      assert {:error, :no_ready_work} = Lease.claim_next("zcode-deepen", "worker-1")

      uninstall_clock(agent)
    end
  end

  # ------------------------------------------------------------------
  # (b) Heartbeat keepalive (renew/1)
  # ------------------------------------------------------------------
  describe "heartbeat keepalive (renew/1)" do
    test "renew extends the TTL from the heartbeat moment and stamps last_heartbeat_at on the clock seam" do
      agent = install_steppable_clock()
      {:ok, _run, epoch} = provider_run_and_epoch()
      {:ok, _leased, token, _run} = Lease.claim_next("zcode-deepen", "worker-1")

      # W840 FIX (asserted): renew/1 reads the DurationBudget clock seam
      # for both the extension base and last_heartbeat_at -- the same
      # clock the claim/live-lease court uses:
      before = clock_now(agent)
      assert :ok = Lease.renew(token)

      {:ok, row} = fetch_epoch(epoch.id)
      assert DateTime.compare(row.last_heartbeat_at, before) == :eq
      assert DateTime.diff(row.lease_expires_at, before, :second) == 30 * 60

      # And the heartbeat does keep a lease alive whose ORIGINAL TTL would
      # be judged on the seam only while the seam tracks real time: the
      # live-lease court still admits the token.
      assert {:ok, %{decision: :allow}} = Lease.admit_tool(token, "Edit")

      uninstall_clock(agent)
    end

    test "heartbeat-during-expiry: a heartbeat after the TTL is refused on the lease clock even though renew writes real wall clock" do
      agent = install_steppable_clock()
      {:ok, _run, _epoch} = provider_run_and_epoch()
      {:ok, _e, token, _run} = Lease.claim_next("zcode-deepen", "worker-1")

      # A worker heartbeat arriving AFTER the TTL passed on the seam clock
      # but BEFORE anyone re-claimed: the live-lease court refuses on the
      # seam, even though renew's own wall-clock stamp would be fresh.
      advance(agent, 31 * 60)

      assert {:error, {:lease_expired, ^token}} = Lease.renew(token)
      # W840: the capacity meter judges on the same seam clock, so the
      # kernel-expired row holds no slot.
      assert Lease.live_leases("zcode-deepen") == 0

      uninstall_clock(agent)
    end

    test "renew with an unknown token is {:no_lease, token}" do
      assert {:error, {:no_lease, "no-such-token"}} = Lease.renew("no-such-token")
    end

    test "renew after a terminal transition is {:lease_not_live, :failed}" do
      agent = install_steppable_clock()
      {:ok, _run, _epoch} = provider_run_and_epoch()
      {:ok, _e, token, _run} = Lease.claim_next("zcode-deepen", "worker-1")

      assert {:ok, _epoch, _receipt} = Lease.refuse(token, :court_reason)
      assert {:error, {:lease_not_live, :failed}} = Lease.renew(token)

      uninstall_clock(agent)
    end
  end

  # ------------------------------------------------------------------
  # (c) admit_tool/2 court-before-registry ordering (kernel side)
  # ------------------------------------------------------------------
  describe "admit_tool court-before-registry ordering" do
    test "an expired lease is a typed expiry refusal even when the provider override would allow the tool" do
      agent = install_steppable_clock()
      provider = "zcode-deepen-#{System.unique_integer([:positive])}"
      prev = Application.get_env(:xaas, :ultracode_provider_tools)

      Application.put_env(:xaas, :ultracode_provider_tools, %{provider => ~w(Edit Read Grep)})
      {:ok, _run, _epoch} = provider_run_and_epoch(provider)
      {:ok, _e, token, _run} = Lease.claim_next(provider, "worker-1")

      advance(agent, 31 * 60)

      # The registry WOULD allow Edit for this provider; the lease court
      # fires FIRST -- expiry is never demoted to a registry verdict.
      assert {:error, {:lease_expired, ^token}} = Lease.admit_tool(token, "Edit")

      Application.put_env(:xaas, :ultracode_provider_tools, prev)

      uninstall_clock(agent)
    end

    test "a terminal epoch's token is {:lease_not_live, state}, again before the registry" do
      agent = install_steppable_clock()
      {:ok, _run, _epoch} = provider_run_and_epoch()
      {:ok, _e, token, _run} = Lease.claim_next("zcode-deepen", "worker-1")
      {:ok, _failed, _receipt} = Lease.refuse(token, :done)

      assert {:error, {:lease_not_live, :failed}} = Lease.admit_tool(token, "Edit")

      uninstall_clock(agent)
    end
  end

  # ------------------------------------------------------------------
  # (d) refuse/3 receipt semantics
  # ------------------------------------------------------------------
  describe "refuse/3 receipt semantics" do
    test "refusal lands :failed with terminal_at and seals :refused with refusal_reason" do
      agent = install_steppable_clock()
      {:ok, _run, epoch} = provider_run_and_epoch()
      {:ok, _e, token, _run} = Lease.claim_next("zcode-deepen", "worker-1")

      assert {:ok, failed, receipt} = Lease.refuse(token, :worker_gave_up)

      assert failed.id == epoch.id
      assert failed.state == :failed
      assert not is_nil(failed.terminal_at)
      assert receipt.outcome == :refused
      assert receipt.evidence["refusal_reason"] == "worker_gave_up"
      # The bearer lease token never enters durable evidence.
      refute Map.has_key?(receipt.evidence, "lease_token")

      uninstall_clock(agent)
    end

    test "refusal binds the semantic work identity when the run carries the full subject" do
      agent = install_steppable_clock()
      {:ok, run, _epoch} = provider_run_and_epoch()
      {:ok, _e, token, _run} = Lease.claim_next("zcode-deepen", "worker-1")
      {:ok, _failed, receipt} = Lease.refuse(token, :court_reason)

      sw = receipt.evidence["semantic_work"]
      assert sw["work_order_iri"] == run.work_order_iri
      assert sw["checkpoint_iri"] == run.checkpoint_iri
      assert sw["graph_digest"] == run.graph_digest
      assert sw["repository_identity"] == run.repository_identity
      assert sw["execution_repo_alias"] == run.execution_repo_alias
      assert sw["base_sha"] == run.base_sha

      uninstall_clock(agent)
    end

    test "refusal is exactly-once: the second refuse is typed and no second receipt seals" do
      agent = install_steppable_clock()
      {:ok, _run, epoch} = provider_run_and_epoch()
      {:ok, _e, token, _run} = Lease.claim_next("zcode-deepen", "worker-1")

      assert {:ok, _failed, _r1} = Lease.refuse(token, :first)
      assert {:error, {:lease_not_live, :failed}} = Lease.refuse(token, :second)

      assert [%{outcome: :refused}] = epoch_receipts(epoch.id)

      uninstall_clock(agent)
    end

    test "refusal releases the capacity slot: a slot IS a live lease row" do
      agent = install_steppable_clock()
      {:ok, _run, _epoch} = provider_run_and_epoch()

      assert Lease.live_leases("zcode-deepen") == 0
      {:ok, _e, token, _run} = Lease.claim_next("zcode-deepen", "worker-1")
      assert Lease.live_leases("zcode-deepen") == 1

      {:ok, _failed, _r} = Lease.refuse(token, :freeing)
      assert Lease.live_leases("zcode-deepen") == 0

      uninstall_clock(agent)
    end

    test "close/refuse on the same token: the first terminal transition wins, the loser is typed" do
      agent = install_steppable_clock()
      {:ok, _run, epoch} = provider_run_and_epoch()
      {:ok, _e, token, _run} = Lease.claim_next("zcode-deepen", "worker-1")

      assert {:ok, _failed, _refuse_receipt} = Lease.refuse(token, :won)

      # close re-checks liveness first: the epoch is already :failed.
      assert {:error, {:lease_not_live, :failed}} =
               Lease.close(token, "head", :partial_alive)

      assert [%{outcome: :refused}] = epoch_receipts(epoch.id)

      uninstall_clock(agent)
    end

    test "refuse with a forged/unknown token is typed {:no_lease, token}" do
      assert {:error, {:no_lease, "forged"}} = Lease.refuse("forged", :nope)
    end
  end

  # ------------------------------------------------------------------
  # (e) Determinism and pool capacity
  # ------------------------------------------------------------------
  describe "determinism and pool capacity" do
    test "claims are oldest-inserted-first with distinct tokens" do
      {:ok, _run1, epoch1} = provider_run_and_epoch()
      {:ok, _run2, epoch2} = provider_run_and_epoch()

      {:ok, e1, t1, _} = Lease.claim_next("zcode-deepen", "w1")
      {:ok, e2, t2, _} = Lease.claim_next("zcode-deepen", "w2")

      assert e1.id == epoch1.id
      assert e2.id == epoch2.id
      assert t1 != t2
    end

    test "pool_capacity/1 reads integer, per-provider map with :default, nil, and the unset default" do
      prev = Application.get_env(:xaas, :ultracode_pool_capacity)

      Application.put_env(:xaas, :ultracode_pool_capacity, 7)
      assert Lease.pool_capacity("any-provider") == 7

      Application.put_env(:xaas, :ultracode_pool_capacity, %{
        "zcode-deepen" => 2,
        default: 9
      })

      assert Lease.pool_capacity("zcode-deepen") == 2
      assert Lease.pool_capacity("other-provider") == 9

      Application.put_env(:xaas, :ultracode_pool_capacity, nil)
      assert Lease.pool_capacity("zcode-deepen") == nil

      Application.delete_env(:xaas, :ultracode_pool_capacity)
      assert Lease.pool_capacity("zcode-deepen") == 5

      on_exit(fn ->
        if prev,
          do: Application.put_env(:xaas, :ultracode_pool_capacity, prev),
          else: Application.delete_env(:xaas, :ultracode_pool_capacity)
      end)
    end

    test ":pool_at_capacity is terminal for the call and the slot recycles through refusal" do
      {:ok, _run1, _e1} = provider_run_and_epoch()
      {:ok, _run2, epoch2} = provider_run_and_epoch()

      {:ok, _e, token, _run} = Lease.claim_next("zcode-deepen", "w1", pool_capacity: 1)

      assert {:error, :pool_at_capacity} =
               Lease.claim_next("zcode-deepen", "w2", pool_capacity: 1)

      # Terminal, not retried: the second ready epoch stays unclaimed.
      assert {:error, :pool_at_capacity} =
               Lease.claim_next("zcode-deepen", "w3", pool_capacity: 1)

      # Release the slot by refusal -> the next claim binds the oldest
      # still-ready epoch (epoch2; epoch1 is terminal now).
      {:ok, _failed, _r} = Lease.refuse(token, :freeing)
      {:ok, leased, _t2, _run} = Lease.claim_next("zcode-deepen", "w4", pool_capacity: 1)
      assert leased.id == epoch2.id
    end
  end

  # ------------------------------------------------------------------
  # (f) W840: one production clock seam across the whole lease kernel
  # ------------------------------------------------------------------
  describe "W840 clock-seam regression courts" do
    test "fast-forwarded seam: a kernel-expired lease is excluded from live_leases/1 (slot freed)" do
      agent = install_steppable_clock()
      {:ok, _run, _epoch} = provider_run_and_epoch()

      # With capacity enforced, the one slot is held by the live lease.
      {:ok, _e, token, _run} = Lease.claim_next("zcode-deepen", "worker-1", pool_capacity: 1)
      assert Lease.live_leases("zcode-deepen") == 1

      # Fast-forward the PRODUCTION seam past the TTL: the claim kernel and
      # the live-lease court already judge the row expired; the capacity
      # meter must agree on the same clock.
      advance(agent, 31 * 60)

      assert Lease.live_leases("zcode-deepen") == 0
      # The freed slot is real: a claim that would be :pool_at_capacity
      # against a phantom slot now binds the same pool.
      assert {:ok, _e2, _t2, _r2} = Lease.claim_next("zcode-deepen", "worker-2", pool_capacity: 1)
      # And the stale bearer is dead both to the meter and to the court:
      # the re-claim overwrote the row's token, so the old token resolves
      # to nothing (same typed shape as W811's re-claim court).
      assert {:error, {:no_lease, ^token}} = Lease.admit_tool(token, "Edit")

      uninstall_clock(agent)
    end

    test "fast-forwarded seam: renew/1's extension is observable against the advanced seam (new expiry = advanced now + TTL)" do
      agent = install_steppable_clock()
      {:ok, _run, epoch} = provider_run_and_epoch()
      {:ok, _e, token, _run} = Lease.claim_next("zcode-deepen", "worker-1")

      advance(agent, 10 * 60)
      now_advanced = clock_now(agent)

      assert :ok = Lease.renew(token)

      {:ok, row} = fetch_epoch(epoch.id)
      # Exactly advanced-now + TTL -- impossible if renew still read real
      # wall clock (that would write real-now + TTL, ~10 minutes BEHIND
      # the advanced seam, and the court would judge the lease expired).
      assert DateTime.diff(row.lease_expires_at, now_advanced, :second) == 30 * 60
      assert DateTime.compare(row.last_heartbeat_at, now_advanced) == :eq

      # The renewed lease survives a further fast-forward of almost the
      # full TTL: the extension actually moved the SEAM-judged boundary.
      advance(agent, 29 * 60)
      assert {:ok, %{decision: :allow}} = Lease.admit_tool(token, "Edit")

      advance(agent, 2 * 60)
      assert {:error, {:lease_expired, ^token}} = Lease.admit_tool(token, "Edit")

      uninstall_clock(agent)
    end
  end
end
