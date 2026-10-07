defmodule Xaas.ObanDepthW984cnTest do
  @moduledoc """
  W984cn Oban/background-job depth court (lane W984cn, v26.10.6 campaign).
  Slices MINUS covered surfaces: the `warming_up` health court (W836) and
  e2e specs are excluded; webhook retry fan-out is already qualified by
  `test/xaas/platform/platform_depth_w984bq_test.exs` (4); the capability-
  liveness `:check_regressions` schedule by
  `test/xaas/operations/capability_liveness_receipt_check_regressions_test.exs`;
  the self-digest worker's `perform/1` behavior by
  `test/xaas/ultracode/capital_census/self_digest_worker_test.exs`.

  The genuinely uncourted Oban slices, qualified here with real jobs in
  Oban's real `testing: :manual` mode (real `oban_jobs` Postgres rows,
  zero mocks):

    1.  The AshOban `:expire_stale_holds` batch (`HoldRequest`'s real
        scheduled Oban entry point) executed as a REAL Oban job via
        `Oban.insert` + `Oban.drain_queue` -- existing courts call the
        per-row `:expire` action directly and never run the scheduled
        batch through the queue.
    1b. Idempotent rerun: a second drain transitions zero rows.
    2.  The job-level lifecycle of `Xaas.Ultracode.SelfDigestWorker`:
        insert -> drain -> `"completed"` state, with real completion side
        effects (admitted `CapitalCensus.WorkOrder` + receipt file).
    3.  The error path per the real `max_attempts: 1` config: an error
        return must transition the real job row to `"discarded"` after
        exactly one attempt, with no `WorkOrder` side effect.
    4.  Config/DSL parity: every AshOban schedule's derived queue name
        and every hand-written worker's queue is a real key in
        `config :xaas, Oban[:queues]` -- the boot-time
        `AshOban.require_queues!/4` law, re-asserted as a court.
    5.  Runtime Oban config invariants: Basic engine, Xaas.Repo,
        Lifeline `rescue_after {75, :minutes}` (P0.1 watchdog), and the
        daily `SelfDigestWorker` cron at `17 6 * * *` -- plus the
        `testing: :manual` contract.
  """

  use Xaas.DataCase, async: false

  require Ash.Query

  alias Xaas.Library.HoldRequest
  alias Xaas.Library.HoldRequest.Workers.ExpireStaleHolds
  alias Xaas.Repo
  alias Xaas.Ultracode.CapitalCensus.WorkOrder
  alias Xaas.Ultracode.SemanticWaveTrigger.Worker, as: WaveWorker
  alias Xaas.Ultracode.SelfDigestWorker

  setup do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)

    tmp = Path.join(System.tmp_dir!(), "oban-depth-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    %{tmp: tmp}
  end

  # ------------------------------------------------------------------
  # (1) AshOban :expire_stale_holds batch -- real Oban job, real drain
  # ------------------------------------------------------------------

  test "(1) the scheduled expire_stale_holds job drains over real holds: expired rows transition, unexpired/cancelled rows are untouched" do
    user = Xaas.Generator.create_user!()
    book = Xaas.Generator.create_book!(%{available_copies: 0, total_copies: 1})
    past = DateTime.add(DateTime.utc_now(), -3600, :second)

    expired_a = place_hold!(user, book, past)
    expired_b = place_hold!(user, book, past)

    # Controls: an active hold whose expiry is still in the future and a
    # cancelled hold whose expiry has passed -- neither is :expirable.
    active_future = place_hold!(user, book, nil)
    cancelled_past = cancel!(place_hold!(user, book, past))

    run_expire_stale_job!()

    assert_expired(expired_a.id)
    assert_expired(expired_b.id)
    assert reloaded(active_future.id).status == :active
    assert reloaded(cancelled_past.id).status == :cancelled
  end

  test "(1b) expire_stale_holds is idempotent: a second drain transitions zero rows and still completes" do
    user = Xaas.Generator.create_user!()
    book = Xaas.Generator.create_book!(%{available_copies: 0, total_copies: 1})
    past = DateTime.add(DateTime.utc_now(), -3600, :second)

    expired = place_hold!(user, book, past)

    run_expire_stale_job!()
    assert_expired(expired.id)

    # A rerun over the same surface must be a no-op (idempotent cron):
    # the now-:expired row is no longer :expirable, so the second batch
    # drains clean.
    run_expire_stale_job!()
    assert reloaded(expired.id).status == :expired
  end

  # ------------------------------------------------------------------
  # (2) SelfDigestWorker job lifecycle: insert -> drain -> completed
  # ------------------------------------------------------------------

  test "(2) SelfDigestWorker insert+drain completes with real completion side effects: admitted self WorkOrder and receipt file on disk",
       %{tmp: tmp} do
    path = write_telemetry!(tmp, recurring_classified(3))
    out_dir = Path.join(tmp, "out")

    assert {:ok, %Oban.Job{id: job_id}} =
             Oban.insert(SelfDigestWorker.new(%{"telemetry_path" => path, "out_dir" => out_dir}))

    assert %{success: 1, failure: 0, discard: 0} = Oban.drain_queue(queue: :ultracode_wave)
    assert %{state: "completed"} = Repo.get!(Oban.Job, job_id)

    # Completion side effects, asserted on state: the admitted self
    # WorkOrder and the real receipt file.
    assert self_orders() != []

    receipt_path = Path.join(out_dir, "self-digest-receipt.json")
    assert File.exists?(receipt_path)
    receipt = receipt_path |> File.read!() |> Jason.decode!()
    assert receipt["schema"] == "xaas.self-digest-receipt/1"
    assert %{"count" => 3} = receipt["recurring_clusters"] |> hd()
  end

  test "(3) SelfDigestWorker error path: an unreadable-telemetry refusal discards the real job after exactly one attempt, with no WorkOrder side effect",
       %{tmp: tmp} do
    missing = Path.join(tmp, "absent.ndjson")
    out_dir = Path.join(tmp, "out")

    assert {:ok, %Oban.Job{id: job_id}} =
             Oban.insert(
               SelfDigestWorker.new(%{"telemetry_path" => missing, "out_dir" => out_dir})
             )

    assert %{success: 0, discard: 1, failure: 0} = Oban.drain_queue(queue: :ultracode_wave)

    drained = Repo.get!(Oban.Job, job_id)
    assert drained.state == "discarded"
    assert drained.attempt == 1

    # The typed refusal ({:error, {:telemetry_unreadable, _, :enoent}} per
    # the real `SelfDigestWorker.run/1` contract) is recorded on the job.
    assert inspect(drained.errors) =~ "telemetry_unreadable"

    assert self_orders() == []
  end

  # ------------------------------------------------------------------
  # (4) Config/DSL parity: derived schedule queues == config queues
  # ------------------------------------------------------------------

  test "(4) every AshOban schedule's derived queue and every hand-written worker's queue is configured -- the require_queues!/4 law as a court" do
    queues = oban_config_queues()

    # Hand-written workers: real queue atoms, present in config.
    assert :ultracode_wave in queues
    assert WaveWorker.__opts__()[:queue] == :ultracode_wave
    assert SelfDigestWorker.__opts__()[:queue] == :ultracode_wave

    # AshOban schedules: the queue each schedule's worker declares must be
    # a real key in config -- the exact demand `AshOban.require_queues!/4`
    # makes at boot.
    expected =
      [
        {Xaas.Library.HoldRequest, :expire_stale_holds,
         Xaas.Library.HoldRequest.Workers.ExpireStaleHolds,
         :hold_request_expire_stale_holds},
        {Xaas.Platform.WebhookDelivery, :retry_failed_deliveries,
         Xaas.Platform.WebhookDelivery.Workers.RetryFailedDeliveries,
         :webhook_delivery_retry_failed_deliveries},
        {Xaas.Operations.CapabilityLivenessReceipt, :check_regressions,
         Xaas.Operations.CapabilityLivenessReceipt.Workers.CheckRegressions,
         :capability_liveness_receipt_check_regressions}
      ]

    for {resource, schedule_name, worker, queue} <- expected do
      scheduled = AshOban.Info.oban_triggers_and_scheduled_actions(resource)
      assert Enum.any?(scheduled, &(&1.name == schedule_name)),
             "missing schedule #{schedule_name} on #{inspect(resource)}"

      assert queue in queues, "queue #{inspect(queue)} missing from config :xaas, Oban queues"
      assert Code.ensure_loaded?(worker), "worker #{inspect(worker)} not compiled"
      assert worker.__opts__()[:queue] == queue
    end
  end

  # ------------------------------------------------------------------
  # (5) Runtime Oban config invariants
  # ------------------------------------------------------------------

  test "(5) runtime Oban config: Basic engine, Xaas.Repo, Lifeline 75m watchdog, SelfDigestWorker daily cron, manual testing mode" do
    cfg = Application.get_env(:xaas, Oban)

    assert cfg[:engine] == Oban.Engines.Basic
    assert cfg[:repo] == Xaas.Repo

    assert cfg[:testing] == :manual

    plugins = cfg[:plugins]

    assert {Oban.Lifeline, lifeline_opts} =
             Enum.find(plugins, &match?({Oban.Lifeline, _}, &1))

    assert lifeline_opts[:rescue_after] == {75, :minutes}

    assert {Oban.Plugins.Cron, cron_opts} =
             Enum.find(plugins, &match?({Oban.Plugins.Cron, _}, &1))

    assert Enum.any?(cron_opts[:crontab], fn entry ->
             match?({"17 6 * * *", SelfDigestWorker, _}, entry) or
               match?({"17 6 * * *", SelfDigestWorker}, entry)
           end)
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp place_hold!(user, book, expires_at) do
    HoldRequest
    |> Ash.Changeset.for_create(:place, %{user_id: user.id, book_id: book.id})
    |> Ash.Changeset.force_change_attribute(:expires_at, expires_at)
    |> Ash.create!(authorize?: false)
  end

  defp cancel!(hold) do
    Ash.Changeset.for_update(hold, :cancel, %{})
    |> Ash.update!(authorize?: false, actor: Xaas.Generator.create_user!())
  end

  defp run_expire_stale_job! do
    assert {:ok, %Oban.Job{id: job_id}} = Oban.insert(ExpireStaleHolds.new(%{}))

    assert %{success: 1, failure: 0, discard: 0} =
             Oban.drain_queue(queue: ExpireStaleHolds.__opts__()[:queue])

    assert %{state: "completed"} = Repo.get!(Oban.Job, job_id)
  end

  defp reloaded(id) do
    HoldRequest
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!(authorize?: false)
  end

  defp assert_expired(id) do
    assert %{status: :expired} = reloaded(id)
  end

  defp oban_config_queues do
    :xaas
    |> Application.get_env(Oban)
    |> Keyword.fetch!(:queues)
    |> Keyword.keys()
  end

  defp write_telemetry!(tmp, entries) do
    path = Path.join(tmp, "loop.ndjson")
    now = DateTime.utc_now()

    lines =
      entries
      |> Enum.with_index()
      |> Enum.map(fn {entry, i} ->
        ts = DateTime.add(now, -(i + 1) * 60, :second) |> DateTime.to_iso8601()
        Jason.encode!(Map.put(entry, "ts", ts)) <> "\n"
      end)

    File.write!(path, lines)
    path
  end

  defp recurring_classified(n) do
    for i <- 1..n,
        do: %{
          "kind" => "ultracode-wave-loop/1",
          "tick" => i,
          "outcome" => "blocked",
          "step" => "dispatch",
          "residual_shape" => "toolchain_pin_missing"
        }
  end

  defp self_orders do
    WorkOrder
    |> Ash.read!(authorize?: false)
    |> Enum.filter(&(&1.subject == Xaas.Ultracode.CapitalCensus.SelfDigest.Run.self_subject()))
  end
end
