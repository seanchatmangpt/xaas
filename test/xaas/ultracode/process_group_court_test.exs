defmodule Xaas.Ultracode.ProcessGroupCourtTest do
  @moduledoc """
  W984dj4 — real-OS court for `Xaas.Ultracode.ProcessGroup`.

  Chicago-style: every subject is a real `perl` child that calls `setpgrp(0,0)`
  (the exact wrapper shape Dispatch/ZcodePackage use), observed through real
  `/bin/kill -0` semantics — no mocks, no stubs.
  """

  use ExUnit.Case, async: true

  alias Xaas.Ultracode.ProcessGroup

  @perl "/usr/bin/perl"

  defp spawn_group(script) do
    port =
      Port.open({:spawn_executable, @perl}, [
        :exit_status,
        :binary,
        :use_stdio,
        :stderr_to_stdout,
        args: ["-e", script]
      ])

    os_pid = Port.info(port) |> Keyword.fetch!(:os_pid)

    # wait for the child to say READY (i.e. setpgrp already ran)
    ready =
      receive do
        {^port, {:data, "READY" <> _}} -> true
      after
        5_000 -> false
      end

    unless ready, do: flunk("child #{os_pid} never became READY")
    {port, os_pid}
  end

  defp live_group do
    spawn_group("""
    $|=1;
    setpgrp(0,0);
    print "READY\\n";
    sleep 60;
    """)
  end

  defp term_immune_group do
    spawn_group("""
    $|=1;
    setpgrp(0,0);
    $SIG{TERM} = 'IGNORE';
    print "READY\\n";
    sleep 60;
    """)
  end

  defp reap(port) do
    if Port.info(port), do: Port.close(port)
    :ok
  end

  # Subject-independent liveness probe: does any live process carry pgid?
  defp group_live?(os_pid) do
    {out, 0} = System.cmd("/bin/ps", ["-axo", "pgid="])
    Enum.any?(String.split(out), fn tok -> tok == Integer.to_string(os_pid) end)
  end

  # Hard-kill the group out-of-band (bypassing the module under test), then
  # wait until the OS itself agrees no process in the group remains.
  defp hard_reap(os_pid) do
    _ = System.cmd("/bin/kill", ["-KILL", "--", "-#{os_pid}"])
    wait_until(fn -> not group_live?(os_pid) end)
    :ok
  end

  test "TERM reaps a live group: kill/2 returns :ok and the group is gone" do
    {port, os_pid} = live_group()
    assert ProcessGroup.alive?(os_pid), "precondition: group is alive"

    assert ProcessGroup.kill(os_pid, 2_000, 1_000) == :ok
    refute ProcessGroup.alive?(os_pid), "group must be gone after TERM"

    # the port really exited with a signal-terminated nonzero status
    assert_receive {^port, {:exit_status, status}}, 5_000
    assert status != 0
  end

  test "TERM-immune group escalates to KILL and is still reaped" do
    {port, os_pid} = term_immune_group()
    assert ProcessGroup.alive?(os_pid)

    # grace_ms small: the TERM is ignored, so the budget expires and the
    # KILL escalation must do the actual reaping.
    assert ProcessGroup.kill(os_pid, 500, 1_000) == :ok
    refute ProcessGroup.alive?(os_pid), "KILL escalation must reap a TERM-immune group"

    assert_receive {^port, {:exit_status, status}}, 5_000
    # SIGKILL: shell-style 137 == 128 + 9; Erlang reports the raw signal? It
    # reports the wait status word; either way nonzero and not a clean 0.
    assert status != 0
  end

  test "killing an already-gone group is a safe no-op returning :ok" do
    {port, os_pid} = live_group()
    reap(port)
    hard_reap(os_pid)

    assert ProcessGroup.kill(os_pid, 200, 200) == :ok
    refute ProcessGroup.alive?(os_pid)
  end

  test "alive?/1 distinguishes a live group from a dead one" do
    {port, os_pid} = live_group()
    assert ProcessGroup.alive?(os_pid) == true
    refute group_live?(os_pid) == false, "precondition: ps agrees the group is live"

    reap(port)
    hard_reap(os_pid)
    assert ProcessGroup.alive?(os_pid) == false
    refute group_live?(os_pid), "postcondition: ps agrees the group is gone"
  end

  test "kill/3 guards reject non-positive and non-integer os_pids" do
    assert_raise FunctionClauseError, fn -> ProcessGroup.kill(0) end
    assert_raise FunctionClauseError, fn -> ProcessGroup.kill(-5) end
    assert_raise FunctionClauseError, fn -> ProcessGroup.kill("123") end
    assert_raise FunctionClauseError, fn -> ProcessGroup.kill(1.5) end
  end

  defp wait_until(fun, tries \\ 50)
  defp wait_until(_fun, 0), do: flunk("condition never became true")
  defp wait_until(fun, tries) do
    if fun.(), do: :ok, else: (Process.sleep(100) && wait_until(fun, tries - 1))
  end
end
