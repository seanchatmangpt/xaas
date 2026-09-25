defmodule Xaas.Ultracode.TickHealthTest do
  @moduledoc """
  Real Chicago-style test for `Xaas.Ultracode.TickHealth.check/1`. No
  mocking of Oban itself: real `%Oban.Job{}` rows are inserted directly
  into the real sandboxed `oban_jobs` table via `Xaas.Repo` (the exact
  repo `config :xaas, Oban` pins in `config/config.exs`), and `check/1`
  is asserted against its real classification of those real, persisted
  rows -- not against a stubbed query result.
  """

  use ExUnit.Case, async: true

  @moduletag :ultracode

  alias Xaas.Ultracode.TickHealth

  @tick_worker Oban.Worker.to_string(Xaas.Ultracode.Run.Workers.Tick)

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # Real `%Oban.Job{}` struct insert (not `Oban.Job.new/2`, which builds an
  # enqueue-time changeset that doesn't permit backdating `state`/
  # `completed_at`/`attempted_at` -- exactly the fields this test needs to
  # control to construct a real stale vs. real fresh row).
  defp insert_job!(attrs) do
    now = DateTime.utc_now()

    %Oban.Job{
      state: "completed",
      queue: "default",
      worker: @tick_worker,
      args: %{},
      meta: %{},
      tags: [],
      errors: [],
      attempt: 1,
      max_attempts: 20,
      priority: 0,
      inserted_at: now,
      scheduled_at: now
    }
    |> Map.merge(Map.new(attrs))
    |> then(&Xaas.Repo.insert!/1)
  end

  test "classifies :healthy when the real most recent completed job is within the threshold" do
    now = DateTime.utc_now()
    completed_at = DateTime.add(now, -30, :second)

    insert_job!(state: "completed", completed_at: completed_at)

    result = TickHealth.check(now: now)

    assert result.status == :healthy
    assert result.worker == @tick_worker
    assert DateTime.compare(result.last_tick_at, completed_at) == :eq
    assert result.elapsed_minutes < result.stale_after_minutes
  end

  test "classifies :stale when the real most recent completed job is older than the threshold" do
    now = DateTime.utc_now()
    stale_completed_at = DateTime.add(now, -3600, :second)

    insert_job!(state: "completed", completed_at: stale_completed_at)

    result = TickHealth.check(now: now, stale_after_minutes: 5)

    assert result.status == :stale
    assert DateTime.compare(result.last_tick_at, stale_completed_at) == :eq
    assert result.elapsed_minutes > 5
  end

  test "classifies :stale with no last_tick_at when the tick worker has never run" do
    result = TickHealth.check(worker: "Nonexistent.Worker.Nobody.Ever.Enqueued")

    assert result.status == :stale
    assert result.last_tick_at == nil
    assert result.elapsed_minutes == nil
  end

  test "a real :executing row counts as recent activity, not only :completed rows" do
    now = DateTime.utc_now()
    attempted_at = DateTime.add(now, -10, :second)

    insert_job!(state: "executing", attempted_at: attempted_at, completed_at: nil)

    result = TickHealth.check(now: now)

    assert result.status == :healthy
    assert DateTime.compare(result.last_tick_at, attempted_at) == :eq
  end

  test "only counts real rows for the matched worker -- a different worker's job is ignored" do
    now = DateTime.utc_now()

    insert_job!(worker: "Some.Other.Worker", state: "completed", completed_at: now)

    result = TickHealth.check(now: now)

    assert result.status == :stale
    assert result.last_tick_at == nil
  end
end
