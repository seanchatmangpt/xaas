defmodule Xaas.Ultracode.ProcessGroup do
  @moduledoc """
  Verified group-wide kill for a child that led its own process group
  (`setpgrp(0,0)` in the perl wrapper `Dispatch` and `ZcodePackage` both
  use): TERM the whole group, poll until it is gone or the grace budget
  expires, then KILL and poll again. The kill is verified, not assumed --
  observed 2026-09-20: under test load a forked child sat pre-exec for
  seconds, so a blind grace sleep let a straggler outlive its own result.

  Extracted from `Xaas.Ultracode.Dispatch` so the `node --version` probe
  (`Xaas.Ultracode.ZcodePackage`) reaps a hung shim with the same mechanics
  instead of a second, weaker copy. Safe when the group is already gone.
  """

  require Logger

  @default_grace_ms 2_000
  @default_kill_confirm_ms 1_000

  @spec kill(pos_integer(), non_neg_integer(), non_neg_integer()) :: :ok
  def kill(os_pid, grace_ms \\ @default_grace_ms, kill_confirm_ms \\ @default_kill_confirm_ms)
      when is_integer(os_pid) and os_pid > 0 do
    _ = System.cmd("/bin/kill", ["-TERM", "--", "-#{os_pid}"], stderr_to_stdout: true)
    await_gone(os_pid, System.monotonic_time(:millisecond) + grace_ms)

    unless alive?(os_pid) do
      :ok
    else
      _ = System.cmd("/bin/kill", ["-KILL", "--", "-#{os_pid}"], stderr_to_stdout: true)
      await_gone(os_pid, System.monotonic_time(:millisecond) + kill_confirm_ms)

      if alive?(os_pid) do
        # A same-uid KILL cannot be ignored; reaching here means the group
        # identity itself is misbehaving. Say so loudly, never silently.
        Logger.warning("[ultracode] process group -#{os_pid} still alive after KILL")
      end

      :ok
    end
  end

  @doc "Is any member of the process group `os_pid` still alive?"
  @spec alive?(pos_integer()) :: boolean()
  def alive?(os_pid) do
    match?({_, 0}, System.cmd("/bin/kill", ["-0", "--", "-#{os_pid}"], stderr_to_stdout: true))
  end

  defp await_gone(os_pid, deadline) do
    if alive?(os_pid) and System.monotonic_time(:millisecond) < deadline do
      Process.sleep(100)
      await_gone(os_pid, deadline)
    end
  end
end
