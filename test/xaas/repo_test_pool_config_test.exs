defmodule Xaas.RepoTestPoolConfigTest do
  @moduledoc """
  Guard for the test-env Repo queue settings (see the comment in `config/test.exs`).

  Under the SQL Sandbox in shared mode concurrent slot workers all queue on one connection.
  With DBConnection's default 50ms `queue_target` the waiters are dropped and
  `Xaas.Ultracode.EngineTest` "fill dispatches exactly the free slots ..." flaked with
  `:handed_off` instead of `:done`. The second test proves the behaviour, not just the
  config: many concurrent Repo users queue on the shared sandbox connection and none is
  dropped. Real Postgres, no doubles.
  """
  use ExUnit.Case, async: false

  test "test-env Repo tolerates queueing on the shared sandbox connection" do
    config = Application.fetch_env!(:xaas, Xaas.Repo)

    assert Keyword.fetch!(config, :queue_target) >= 1_000
    assert Keyword.fetch!(config, :queue_interval) >= 1_000
  end

  test "concurrent Repo users sharing the sandbox connection are all served" do
    # Scoped start_owner!/stop_owner, the same pattern as engine_test.exs: no global
    # Sandbox.mode/2 flip that could clobber another async: false module's shared mode.
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    results =
      1..20
      |> Task.async_stream(
        fn n -> Xaas.Repo.query!("SELECT pg_sleep(0.02), $1::int", [n]).rows end,
        max_concurrency: 20,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, [[_, n]]} -> n end)

    assert Enum.sort(results) == Enum.to_list(1..20)
  end
end
