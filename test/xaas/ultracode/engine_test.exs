defmodule Xaas.Ultracode.EngineTest do
  @moduledoc """
  Qualification of the continuous engine (`Xaas.Ultracode.Engine`) -- the
  between-waves half of the autonomic loop -- against real sandboxed
  Postgres, real Ash actions, the real `Xaas.Ultracode.Lease` protocol, and
  the real `Xaas.Ultracode.Reactor` tick body. No mocks/stubs.

  The worker is a scripted protocol client at the engine's injected seam
  (`:worker` opt / `config :xaas, :ultracode_engine_worker`): a real
  implementation of the lease protocol that DIRECTED-claims its handed
  epoch via `Lease.claim_next/3` and really closes/refuses through
  `Lease.close/4`/`Lease.refuse/3` -- it stands in only for the dispatch
  seam's process, the same boundary `Xaas.Ultracode.Autonomic`'s
  qualification draws.

  Definition of done encoded here:

    (a) a Run started via `Run.:start` cycles epochs autonomously: tick
        lifecycle (`Reactor.run(Xaas.Ultracode.Reactor)`) + engine cycles
        (worker fill at capacity 5) carry it to `:completed`/`:admitted`
        with zero manual epoch construction;
    (b) worker slots are leased and released with NO leak: capacity 5
        admits exactly 5 concurrent live leases and every release path
        (close, refuse) frees slots -- the meter is the live-lease rows
        themselves, so it cannot drift;
    (c) every epoch reaches a terminal state WITH a receipt -- including
        the previously receipt-less no-lease reap;
    (d) a crashed/stuck worker is reaped: a live lease is exempt from
        `MissedEpochs` (a worker's TTL is its liveness bound), an expired
        lease is reaped `:missed` with a receipt, and a worker that ends
        without closing is reaped `:failed` with a `:refused` receipt;
    (e) a Run can be stopped (`:stop` revokes live leases with receipts)
        and resumed (`:resume` re-arms; the tick machinery then recovers
        it), with typed refusals for every non-resumable shape.
  """

  use ExUnit.Case, async: false

  require Ash.Query

  import ExUnit.CaptureLog

  @moduletag :ultracode

  alias Xaas.Ultracode.{Engine, Epoch, Lease, MissedEpochs, Receipt, Run, TickHealth}

  setup do
    # The engine dispatches slot workers in tasks that really touch the DB
    # (the lease protocol), so the pool must be shared with spawned
    # processes. Scoped start_owner!/stop_owner (the repo's DataCase
    # pattern for async: false), NOT a global `Sandbox.mode/2` flip: a
    # manual `mode(:manual)` reset in on_exit would clobber the live
    # shared mode of another async: false module still running its own
    # on_exit window (a real cross-module interference, first observed
    # against SemanticWorkTest/SemanticWaveTest).
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
    end)

    :ok
  end

  # ------------------------------------------------------------------
  # Fixtures
  # ------------------------------------------------------------------

  defp exact_subject! do
    {sha, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: File.cwd!())
    String.trim(sha)
  end

  defp unique_provider, do: "zcode-engine-#{System.unique_integer([:positive])}"

  # A provider-pull Run already `:running`, with its first Epoch already
  # `:running` (claimable immediately) -- the fixture shape lease_test uses.
  defp running_run_and_epoch(provider, opts \\ []) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{
          goal: "engine qualification",
          provider: provider,
          max_cycles: opts[:max_cycles] || 1,
          epoch_timeout_seconds: opts[:timeout] || 900
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
          exact_subject: "engine qualification subject",
          state: :running,
          expected_at: opts[:expected_at] || DateTime.utc_now()
        },
        authorize?: false
      )
      |> Ash.create()

    {run, epoch}
  end

  # ------------------------------------------------------------------
  # The scripted workers (real lease protocol, no mocks)
  # ------------------------------------------------------------------

  defp claim_close_worker(epoch, ctx) do
    case Lease.claim_next(ctx.provider, "engine-test-worker", epoch_id: epoch.id) do
      {:ok, _leased, token, _run} ->
        case Lease.close(token, "engine-head-#{binary_slice(epoch.id, 0, 8)}", :alive) do
          {:ok, _epoch, _receipt} -> :ok
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp claim_refuse_worker(epoch, ctx) do
    case Lease.claim_next(ctx.provider, "engine-refusing-worker", epoch_id: epoch.id) do
      {:ok, _leased, token, _run} ->
        case Lease.refuse(token, :worker_refused_task) do
          {:ok, _epoch, _receipt} -> :ok
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # A worker that crashed/ended WITHOUT ever driving the protocol.
  defp ghost_worker(_epoch, _ctx), do: :ok

  # A worker that claimed and then died mid-work, holding a live lease.
  defp claim_and_hold_worker(epoch, ctx) do
    {:ok, _leased, _token, _run} =
      Lease.claim_next(ctx.provider, "hold-worker", epoch_id: epoch.id)

    :ok
  end

  # ------------------------------------------------------------------
  # Schedule registration (the ULTRACODE-50 dormant-schedule failure mode)
  # ------------------------------------------------------------------

  describe ":engine_cycle schedule registration" do
    test "AshOban merges a */5 crontab entry for the generated worker on the engine queue" do
      built =
        AshOban.config(
          Application.fetch_env!(:xaas, :ash_domains),
          Application.fetch_env!(:xaas, Oban)
        )

      {_plugin, opts} = Enum.find(built[:plugins], &match?({Oban.Plugins.Cron, _}, &1))

      entry =
        Enum.find(opts[:crontab], fn
          {_cron, Xaas.Ultracode.Run.Workers.EngineCycle, _entry_opts} -> true
          _ -> false
        end)

      assert entry, "no crontab entry for Xaas.Ultracode.Run.Workers.EngineCycle"

      {cron, _worker, _entry_opts} = entry
      assert to_string(cron) == "*/5 * * * *"

      # The queue binding lives on the generated worker itself
      # (`use Oban.Worker, queue: ...` -- the crontab entry opts are empty).
      assert Xaas.Ultracode.Run.Workers.EngineCycle.__opts__()[:queue] == :ultracode_engine
    end

    test "the :ultracode_engine queue is listed with exactly one slot" do
      queues = Application.fetch_env!(:xaas, Oban)[:queues]
      assert queues[:ultracode_engine] == 1
    end

    test "the :engine_cycle action runs the engine through the runner seam" do
      {:ok, _pid} = Agent.start_link(fn -> nil end, name: __MODULE__.RunnerProbe)
      Application.put_env(:xaas, :ultracode_engine_runner, {__MODULE__, :capture_cycle})

      on_exit(fn ->
        Application.delete_env(:xaas, :ultracode_engine_runner)
      end)

      assert {:ok, %{captured: true}} =
               Run
               |> Ash.ActionInput.for_action(:engine_cycle, %{}, authorize?: false)
               |> Ash.run_action()
    end
  end

  def capture_cycle(_opts), do: {:ok, %{captured: true}}

  # ------------------------------------------------------------------
  # (a) a started Run cycles to completion through tick + engine
  # ------------------------------------------------------------------

  test "a started provider run cycles two epochs to :completed via ticks + engine fills, zero manual epoch creation" do
    subject = exact_subject!()
    provider = unique_provider()

    run =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "engine continuous run", provider: provider, max_cycles: 2},
        authorize?: false
      )
      |> Ash.create!()
      |> Ash.Changeset.for_update(:start, %{exact_subject: subject}, authorize?: false)
      |> Ash.update!()

    # Tick 1: first epoch :expected -> :running.
    {:ok, _} = Reactor.run(Xaas.Ultracode.Reactor)

    # Engine cycle: fills the free slot; the worker claims, closes; the
    # fabric sealed a receipt; capacity was 5. The cycle's own advance step
    # then constructs the successor epoch (:expected) and, at the end of
    # the loop below, lands the Run at max_cycles -- zero manual epoch
    # construction anywhere in this test.
    # Directed at this provider: undirected discovery is allowlist-scoped
    # (default ["recipe"]), see the provider-allowlist tests below.
    report =
      Engine.cycle(worker: &claim_close_worker/2, pool_capacity: 5, providers: [provider])

    assert report.tick_health in [:healthy, :stale]

    [fill] = report.fill
    assert fill.capacity == 5
    assert [%{status: :done, receipt_id: receipt_id_1}] = fill.dispatched

    {:ok, [epoch_0]} =
      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(run_id == ^run.id and cycle == 0)
      |> Ash.read(authorize?: false)

    assert epoch_0.state == :completed
    receipt_1 = Ash.get!(Receipt, receipt_id_1, authorize?: false)
    assert receipt_1.epoch_id == epoch_0.id
    assert receipt_1.outcome in [:alive, :partial_alive]

    # The cycle's advance already queued the successor...
    {:ok, epochs_after_cycle} =
      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(run_id == ^run.id and cycle == 1)
      |> Ash.read(authorize?: false)

    assert [%{state: :expected}] = epochs_after_cycle

    # ...the next tick starts it, the next engine cycle closes it, and the
    # cycle's advance lands the Run at max_cycles.
    {:ok, _} = Reactor.run(Xaas.Ultracode.Reactor)

    report_2 =
      Engine.cycle(worker: &claim_close_worker/2, pool_capacity: 5, providers: [provider])

    [%{dispatched: dispatched_2}] = report_2.fill
    assert [%{status: :done}] = dispatched_2

    final_run = Ash.get!(Run, run.id, action: :read_unscoped, authorize?: false)
    assert final_run.state == :completed
    assert final_run.standing == :admitted

    {:ok, all_epochs} =
      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.read(authorize?: false)

    assert length(all_epochs) == 2
    assert Enum.all?(all_epochs, &(&1.state == :completed))
  end

  # ------------------------------------------------------------------
  # (b) slots: capacity 5, released on close/refuse -- no leak
  # ------------------------------------------------------------------

  test "fill dispatches exactly the free slots and closing releases them all (no leak)" do
    provider = unique_provider()

    {_runs, epochs} =
      1..6
      |> Enum.map(fn _ -> running_run_and_epoch(provider) end)
      |> Enum.unzip()

    [report] = Engine.fill(provider: provider, pool_capacity: 5, worker: &claim_close_worker/2)

    assert report.capacity == 5
    assert length(report.dispatched) == 5
    assert Enum.all?(report.dispatched, &(&1.status == :done))

    # The 6th was never dispatched -- capacity held the fence.
    # `DateTime` as the comparator is load-bearing: default `Enum.max_by/2` compares the
    # %DateTime{} structs structurally (microsecond before minute/second), so the six inserts
    # straddling a second boundary picked the wrong "latest" epoch and this test flaked.
    sixth = Enum.max_by(epochs, & &1.inserted_at, DateTime)
    sixth_after = Ash.get!(Epoch, sixth.id, action: :read_unscoped, authorize?: false)
    assert sixth_after.state == :running
    assert is_nil(sixth_after.lease_token)

    # No leak: every slot worker CLOSED, so zero live leases remain -- the
    # meter reads the live-lease rows themselves, not a counter.
    assert Lease.live_leases(provider) == 0

    # The released capacity is really reusable: the 6th epoch fills next.
    [report_2] = Engine.fill(provider: provider, pool_capacity: 5, worker: &claim_close_worker/2)
    assert [%{status: :done}] = report_2.dispatched
  end

  test "the claim kernel refuses an over-capacity claim with a typed error, and releases on close and refuse" do
    provider = unique_provider()

    {_runs, epochs} =
      1..6
      |> Enum.map(fn _ -> running_run_and_epoch(provider) end)
      |> Enum.unzip()

    # Hold five live leases (claims without closure)...
    held =
      for epoch <- Enum.take(epochs, 5) do
        {:ok, _leased, token, _run} =
          Lease.claim_next(provider, "holder", epoch_id: epoch.id, pool_capacity: 5)

        token
      end

    # ...the 6th claim is a real, typed refusal.
    sixth = Enum.fetch!(epochs, 5)

    assert {:error, :pool_at_capacity} =
             Lease.claim_next(provider, "overflow", epoch_id: sixth.id, pool_capacity: 5)

    # Release one slot by REFUSING its work -> the 6th claim fits.
    [released_token | _rest] = held
    assert {:ok, _failed_epoch, refused_receipt} = Lease.refuse(released_token, :holder_gave_up)
    assert refused_receipt.outcome == :refused

    assert {:ok, _leased, _token, _run} =
             Lease.claim_next(provider, "overflow", epoch_id: sixth.id, pool_capacity: 5)
  end

  test "an explicit unbounded capacity override keeps legacy claim semantics" do
    provider = unique_provider()

    {_runs, epochs} =
      1..6
      |> Enum.map(fn _ -> running_run_and_epoch(provider) end)
      |> Enum.unzip()

    results =
      for epoch <- epochs do
        Lease.claim_next(provider, "unbounded", epoch_id: epoch.id, pool_capacity: nil)
      end

    assert Enum.all?(results, &match?({:ok, _, _, _}, &1))
    assert Lease.live_leases(provider) == 6
  end

  # ------------------------------------------------------------------
  # (c) every terminal state carries a receipt -- including the reap
  # ------------------------------------------------------------------

  test "a refusing worker lands :failed with a refused receipt through the engine" do
    provider = unique_provider()
    {_run, epoch} = running_run_and_epoch(provider)

    [report] = Engine.fill(provider: provider, worker: &claim_refuse_worker/2)

    assert [%{status: :refused, receipt_id: receipt_id}] = report.dispatched

    failed = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
    assert failed.state == :failed

    receipt = Ash.get!(Receipt, receipt_id, authorize?: false)
    assert receipt.outcome == :refused
    assert receipt.evidence["refusal_reason"] == "worker_refused_task"
  end

  test "a worker that ends without closing (no lease) is reaped :failed WITH a refused receipt" do
    provider = unique_provider()
    {_run, epoch} = running_run_and_epoch(provider)

    [report] = Engine.fill(provider: provider, worker: &ghost_worker/2)

    assert [%{status: :reaped, receipt_id: receipt_id}] = report.dispatched

    reaped = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
    assert reaped.state == :failed

    receipt = Ash.get!(Receipt, receipt_id, authorize?: false)
    assert receipt.outcome == :refused
    assert receipt.evidence["reaped_by"] == "xaas-engine"
    assert receipt.evidence["reap_reason"] == "worker_ended_without_closing"
    assert receipt.evidence["worker_had_lease"] == false
  end

  test "a rate-limited turn leaves the epoch reclaimable, not reaped" do
    provider = unique_provider()
    {_run, epoch} = running_run_and_epoch(provider)

    [report] = Engine.fill(provider: provider, worker: fn _epoch, _ctx -> :rate_limited end)

    assert [%{status: :rate_limited}] = report.dispatched

    still_running = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
    assert still_running.state == :running
    assert is_nil(still_running.lease_token)
    assert Lease.live_leases(provider) == 0
  end

  # ------------------------------------------------------------------
  # (d) crashed/stuck workers: lease TTL is the liveness bound
  # ------------------------------------------------------------------

  test "MissedEpochs does NOT reap a stale epoch while its lease is live" do
    provider = unique_provider()

    {_run, epoch} =
      running_run_and_epoch(provider,
        timeout: 1,
        expected_at: DateTime.add(DateTime.utc_now(), -60, :second)
      )

    {:ok, _leased, _token, _run} = Lease.claim_next(provider, "slow-but-alive")

    {:ok, [run]} =
      Run
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(provider == ^provider)
      |> Ash.read(authorize?: false)

    summary = MissedEpochs.advance_run(run)
    assert summary.missed == []

    still_running = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
    assert still_running.state == :running
  end

  test "MissedEpochs reaps a stale epoch whose lease EXPIRED, with a blocked receipt" do
    provider = unique_provider()

    {run, epoch} =
      running_run_and_epoch(provider,
        timeout: 1,
        expected_at: DateTime.add(DateTime.utc_now(), -60, :second)
      )

    {:ok, _leased, _token, _run} = Lease.claim_next(provider, "crashed-worker")

    # Simulate the crash's real consequence: nobody renewed, the TTL passed.
    _ =
      epoch
      |> Ash.Changeset.for_update(
        :renew_lease,
        %{lease_expires_at: DateTime.add(DateTime.utc_now(), -60, :second)},
        authorize?: false
      )
      |> Ash.update!()

    summary = MissedEpochs.advance_run(run)
    assert epoch.id in summary.missed

    missed = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
    assert missed.state == :missed

    {:ok, [receipt]} =
      Receipt
      |> Ash.Query.filter(epoch_id == ^epoch.id)
      |> Ash.read(authorize?: false)

    assert receipt.outcome == :blocked
  end

  test "a worker that ends while holding a live lease is handed off, never reaped" do
    provider = unique_provider()
    {_run, epoch} = running_run_and_epoch(provider)

    [report] = Engine.fill(provider: provider, worker: &claim_and_hold_worker/2)

    assert [%{status: :handed_off}] = report.dispatched

    # The live lease protects the epoch from a concurrent engine's reaping.
    untouched = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
    assert untouched.state == :running
    assert Lease.live_leases(provider) == 1
  end

  # ------------------------------------------------------------------
  # (e) stop and resume
  # ------------------------------------------------------------------

  test "stop abandons the run, revokes its live lease with a receipt, and freezes it out of the tick" do
    provider = unique_provider()
    subject = exact_subject!()

    run =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "engine stop", provider: provider, max_cycles: 3},
        authorize?: false
      )
      |> Ash.create!()
      |> Ash.Changeset.for_update(:start, %{exact_subject: subject}, authorize?: false)
      |> Ash.update!()

    {:ok, _} = Reactor.run(Xaas.Ultracode.Reactor)
    {:ok, _leased, _token, _run} = Lease.claim_next(provider, "mid-flight-worker")

    stopped =
      run
      |> Ash.Changeset.for_update(:stop, %{}, authorize?: false)
      |> Ash.update!()

    assert stopped.state == :abandoned
    assert stopped.standing == :blocked

    {:ok, [epoch]} =
      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.read(authorize?: false)

    assert epoch.state == :failed

    {:ok, receipts} =
      Receipt
      |> Ash.Query.filter(epoch_id == ^epoch.id)
      |> Ash.read(authorize?: false)

    assert Enum.any?(receipts, fn r ->
             r.outcome == :refused and r.evidence["refusal_reason"] == "run_stopped"
           end)

    # A stopped Run is out of the tick's active set: nothing advances it.
    {:ok, _} = Reactor.run(Xaas.Ultracode.Reactor)

    still_stopped = Ash.get!(Run, run.id, action: :read_unscoped, authorize?: false)
    assert still_stopped.state == :abandoned

    {:ok, epochs_after} =
      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.read(authorize?: false)

    assert length(epochs_after) == 1

    # Stopping twice is a real error, not an idempotent skip.
    assert {:error, %Ash.Error.Invalid{}} =
             stopped
             |> Ash.Changeset.for_update(:stop, %{}, authorize?: false)
             |> Ash.update()
  end

  test "resume re-arms a stopped run and the tick machinery recovers it" do
    provider = unique_provider()
    subject = exact_subject!()

    run =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "engine resume", provider: provider, max_cycles: 2},
        authorize?: false
      )
      |> Ash.create!()
      |> Ash.Changeset.for_update(:start, %{exact_subject: subject}, authorize?: false)
      |> Ash.update!()

    {:ok, _} = Reactor.run(Xaas.Ultracode.Reactor)

    # A worker is mid-epoch (live lease) when the operator stops the run --
    # the stop revokes the lease (epoch -> :failed, refused receipt), so the
    # resumed run has a TERMINAL last epoch the tick machinery must recover
    # from.
    {:ok, _leased, _token, _run} = Lease.claim_next(provider, "mid-flight-worker")

    _ =
      run
      |> Ash.Changeset.for_update(:stop, %{}, authorize?: false)
      |> Ash.update!()

    # Fresh read: the resume acts on the REAL current row, never the stale
    # pre-stop struct.
    stopped_run = Ash.get!(Run, run.id, action: :read_unscoped, authorize?: false)

    resumed =
      stopped_run
      |> Ash.Changeset.for_update(:resume, %{}, authorize?: false)
      |> Ash.update!()

    assert resumed.state == :running
    assert resumed.standing == :unknown

    # The tick disposes of the stop-frozen terminal epoch (bounded stale
    # recovery) and constructs the successor -- the run really continues.
    {:ok, _} = Reactor.run(Xaas.Ultracode.Reactor)

    {:ok, epochs} =
      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.read(authorize?: false)

    assert length(epochs) == 2
    assert Enum.any?(epochs, &(&1.cycle == 1 and &1.state == :expected))

    resumed_run = Ash.get!(Run, run.id, action: :read_unscoped, authorize?: false)
    assert resumed_run.cycle == 2
    assert resumed_run.state == :running
  end

  test "resume refuses non-resumable shapes with typed errors" do
    # A run with no active epoch and its cycle budget spent.
    exhausted =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "engine resume exhausted", max_cycles: 1},
        authorize?: false
      )
      |> Ash.create!()
      |> Ash.Changeset.for_update(:advance_cycle, %{}, authorize?: false)
      |> Ash.update!()
      |> Ash.Changeset.for_update(:transition_state, %{state: :abandoned}, authorize?: false)
      |> Ash.update!()

    assert {:error, %Ash.Error.Invalid{errors: errors_1}} =
             exhausted
             |> Ash.Changeset.for_update(:resume, %{}, authorize?: false)
             |> Ash.update()

    assert Enum.any?(errors_1, &(&1.message =~ "not resumable"))

    # A completed run has no resume edge at all (:running -> :completed is
    # the admitted edge to completion).
    completed =
      Run
      |> Ash.Changeset.for_create(:create, %{goal: "engine resume completed"}, authorize?: false)
      |> Ash.create!()
      |> Ash.Changeset.for_update(:transition_state, %{state: :running}, authorize?: false)
      |> Ash.update!()
      |> Ash.Changeset.for_update(
        :transition_state,
        %{state: :completed, standing: :admitted},
        authorize?: false
      )
      |> Ash.update!()

    assert {:error, %Ash.Error.Invalid{}} =
             completed
             |> Ash.Changeset.for_update(:resume, %{}, authorize?: false)
             |> Ash.update()
  end

  # ------------------------------------------------------------------
  # the provider allowlist scopes undirected discovery
  # ------------------------------------------------------------------

  describe "provider allowlist" do
    setup do
      original = Application.get_env(:xaas, :ultracode_engine_providers)

      on_exit(fn ->
        if is_nil(original),
          do: Application.delete_env(:xaas, :ultracode_engine_providers),
          else: Application.put_env(:xaas, :ultracode_engine_providers, original)
      end)

      :ok
    end

    test "the configured default is the deterministic recipe provider only" do
      # Behavior first, so a revert fails on WHAT the engine does, not only
      # on a missing function: with the shipped config (configured worker,
      # no :worker/:providers opt) a ready epoch of a non-recipe provider is
      # neither discovered nor reported -- not even as :no_worker_configured.
      provider = unique_provider()
      {_run, epoch} = running_run_and_epoch(provider)

      assert Engine.fill() == []

      untouched = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
      assert untouched.state == :running
      assert is_nil(untouched.lease_token)
      assert is_nil(untouched.leased_to)

      # The shipped config itself (config/config.exs), not only the code
      # default `provider_allowlist/0` falls back to when unset.
      assert Application.get_env(:xaas, :ultracode_engine_providers) == ["recipe"]

      assert Application.get_env(:xaas, :ultracode_engine_worker) ==
               {Xaas.Ultracode.RecipeWorker, :run}

      assert Engine.provider_allowlist() == ["recipe"]
    end

    test "an undirected fill never discovers a non-allowlisted provider's ready epoch" do
      provider = unique_provider()
      {_run, epoch} = running_run_and_epoch(provider)

      assert Engine.fill(worker: &claim_close_worker/2) == []

      untouched = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
      assert untouched.state == :running
      assert is_nil(untouched.lease_token)

      # Allowlisting the provider is the only change -- the same undirected
      # fill now discovers and closes it.
      Application.put_env(:xaas, :ultracode_engine_providers, [provider])

      assert [%{provider: ^provider, dispatched: [%{status: :done}]}] =
               Engine.fill(worker: &claim_close_worker/2)
    end

    test ":all restores unrestricted discovery" do
      provider = unique_provider()
      {_run, _epoch} = running_run_and_epoch(provider)

      Application.put_env(:xaas, :ultracode_engine_providers, :all)

      assert [%{provider: ^provider, dispatched: [%{status: :rate_limited}]}] =
               Engine.fill(worker: fn _epoch, _ctx -> :rate_limited end)

      assert Engine.provider_allowlist() == :all
    end

    test "a malformed allowlist is logged with the bad value and surfaced as a typed config error, never an empty pool" do
      provider = unique_provider()
      {_run, epoch} = running_run_and_epoch(provider)
      invalid = {:error, {:invalid_config, :ultracode_engine_providers}}

      for bad <- [[:not_a_string], [provider, 42], "recipe", %{"recipe" => true}] do
        Application.put_env(:xaas, :ultracode_engine_providers, bad)

        # Behavior first: the undirected fill (the cron path) reports the
        # error instead of `[]` ("no ready work"), and the bad value is in
        # the error log.
        log =
          capture_log([level: :error], fn ->
            assert Engine.fill(worker: &claim_close_worker/2) == invalid
          end)

        assert log =~ "invalid config :ultracode_engine_providers"
        assert log =~ inspect(bad)

        # A directed fill that would use the CONFIGURED worker carries the
        # same error as its outcome and dispatches nothing.
        capture_log(fn ->
          assert [
                   %{
                     provider: ^provider,
                     dispatched: [],
                     outcome: {:invalid_config, :ultracode_engine_providers}
                   }
                 ] =
                   Engine.fill(providers: [provider])

          assert Engine.provider_allowlist() == invalid
          assert Engine.cycle().fill == invalid
        end)
      end

      untouched = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
      assert untouched.state == :running
      assert is_nil(untouched.lease_token)
    end
  end

  # ------------------------------------------------------------------
  # TickHealth is part of every engine cycle report
  # ------------------------------------------------------------------

  test "the cycle report carries the real TickHealth verdict" do
    provider = unique_provider()
    {_run, _epoch} = running_run_and_epoch(provider)

    report = Engine.cycle(worker: &ghost_worker/2, providers: [provider])

    assert report.tick_health == TickHealth.check().status
    assert Map.has_key?(report, :tick_last_activity_at)
  end
end
