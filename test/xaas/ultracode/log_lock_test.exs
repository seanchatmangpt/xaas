defmodule Xaas.Ultracode.LogLockTest do
  @moduledoc """
  Real `flock(2)` locks held by real helper OS processes on real files; no doubles.

  Contract (`Xaas.Ultracode.LogLock`): mutual exclusion across concurrent takers,
  release by the kernel when the holder dies (no stale lock to steal), a typed
  refusal instead of a hang or a raise when the lock cannot be taken.
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.LogLock

  setup do
    dir = Path.join(System.tmp_dir!(), "xaas-loglock-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    %{dir: dir}
  end

  test "runs the function and returns its result under the lock", %{dir: dir} do
    assert {:ok, :done} = LogLock.with_lock(dir, fn -> :done end)
    assert File.exists?(Path.join(dir, LogLock.lock_file()))
  end

  test "concurrent takers never overlap", %{dir: dir} do
    journal = Path.join(dir, "journal")

    dir
    |> then(fn dir ->
      1..5
      |> Task.async_stream(
        fn i ->
          LogLock.with_lock(dir, fn ->
            File.write!(journal, "in-#{i}\n", [:append])
            Process.sleep(40)
            File.write!(journal, "out-#{i}\n", [:append])
          end)
        end,
        max_concurrency: 5,
        timeout: 60_000
      )
      |> Enum.to_list()
    end)
    |> Enum.each(&assert({:ok, {:ok, :ok}} = &1))

    lines = journal |> File.read!() |> String.split("\n", trim: true)
    assert length(lines) == 10

    for [entered, left] <- Enum.chunk_every(lines, 2) do
      "in-" <> i = entered
      assert left == "out-" <> i
    end
  end

  test "a holder killed while holding the lock frees it (the kernel releases, nothing is stale)",
       %{dir: dir} do
    parent = self()

    holder =
      spawn(fn ->
        LogLock.with_lock(dir, fn ->
          send(parent, :holding)
          Process.sleep(:infinity)
        end)
      end)

    assert_receive :holding, 30_000

    # while it holds, a second taker times out and does not run its function
    assert {:error, :lock_timeout} =
             LogLock.with_lock(dir, 400, fn -> flunk("ran under a held lock") end)

    ref = Process.monitor(holder)
    Process.exit(holder, :kill)
    assert_receive {:DOWN, ^ref, :process, ^holder, :killed}

    assert {:ok, :taken_after_kill} = LogLock.with_lock(dir, 30_000, fn -> :taken_after_kill end)
  end

  test "a function that raises still releases the lock", %{dir: dir} do
    assert_raise RuntimeError, "boom", fn -> LogLock.with_lock(dir, fn -> raise "boom" end) end
    assert {:ok, :again} = LogLock.with_lock(dir, 30_000, fn -> :again end)
  end

  test "without perl the lock is refused, not skipped", %{dir: dir} do
    original = System.get_env("PATH")
    System.put_env("PATH", "/nonexistent-path-for-test")

    try do
      assert {:error, :perl_unavailable} =
               LogLock.with_lock(dir, fn -> flunk("ran without a lock") end)
    after
      System.put_env("PATH", original)
    end
  end
end
