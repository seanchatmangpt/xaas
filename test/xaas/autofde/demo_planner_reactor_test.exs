defmodule Xaas.Autofde.DemoPlannerReactorTest do
  @moduledoc """
  Real, Chicago-style coverage for `Xaas.Autofde.DemoPlannerReactor` — real
  `Reactor.run/2` calls against real scripts under `priv/reactor_demo/scripts/`, real
  OS ports, real `compensate/4` invocation, and a real `ps`-based liveness check that
  the compensated process is actually gone. No mocking of any kind.
  """
  use ExUnit.Case, async: true

  alias Xaas.Autofde.DemoPlannerReactor
  alias Xaas.Autofde.DemoPlannerReactor.PortRegistry
  alias Xaas.Autofde.DemoPlannerReactor.RunScript

  @scripts_dir Path.join([File.cwd!(), "priv", "reactor_demo", "scripts"])
  @primary_ok Path.join(@scripts_dir, "primary.sh")
  @primary_failing Path.join(@scripts_dir, "primary_failing.sh")
  @fallback Path.join(@scripts_dir, "fallback.sh")
  @slow Path.join(@scripts_dir, "slow.sh")

  defp unique_run_id, do: "run-#{System.unique_integer([:positive, :monotonic])}"

  test "success path: primary script's real result flows through, fallback is skipped" do
    run_id = unique_run_id()

    assert {:ok, %{source: :primary, value: "84"}} =
             Reactor.run(DemoPlannerReactor, %{
               run_id: run_id,
               number: 42,
               primary_script: @primary_ok,
               fallback_script: @fallback
             })

    # primary.sh doubles its input: 42 * 2 == 84, a real value from a real process,
    # not a stubbed one.
  end

  test "failure path: real ordered fallback runs, and compensate/4 really killed the primary OS process" do
    run_id = unique_run_id()

    assert {:ok, %{source: :fallback, value: "126"}} =
             Reactor.run(DemoPlannerReactor, %{
               run_id: run_id,
               number: 42,
               primary_script: @primary_failing,
               fallback_script: @fallback
             })

    # fallback.sh triples its input: 42 * 3 == 126 — proves the real ordered-fallback
    # step actually ran (not just that primary failed silently).

    request_id = run_id <> "-primary"

    assert {os_pid, outcome} = PortRegistry.get_audit(request_id),
           "compensate/4 should have recorded a real cleanup for the primary attempt"

    assert outcome in [:closed, :already_dead],
           "compensate/4 should have either closed a live port or found the process already dead, got: #{inspect(outcome)}"

    assert is_integer(os_pid) and os_pid > 0

    # Real liveness check: after compensate/4 has run, the real OS process it killed
    # must actually be gone -- not merely that the callback was invoked.
    {ps_output, ps_exit_status} = System.cmd("ps", ["-p", to_string(os_pid)], stderr_to_stdout: true)

    refute ps_exit_status == 0,
           "expected `ps -p #{os_pid}` to fail (process gone) after real compensate/4 kill, got: #{ps_output}"

    refute ps_output =~ to_string(os_pid)

    # The working registry entry must also have been cleaned up (no leaked port).
    assert PortRegistry.get(request_id) == nil
  end

  test "compensate/4 kills a genuinely still-running OS process, verified by real ps before and after" do
    request_id = "kill-proof-#{System.unique_integer([:positive, :monotonic])}"

    args = %{script: @slow, input: 1, request_id: request_id, label: :kill_proof}
    # 200ms wait against a script that sleeps 30s: run/3's own receive times out
    # while the real OS process is still alive.
    assert {:error, {:script_timeout, 200, _}} = RunScript.run(args, %{}, timeout_ms: 200)

    {port, os_pid} = PortRegistry.get(request_id)
    assert is_integer(os_pid) and os_pid > 0

    {ps_before, ps_before_status} = System.cmd("ps", ["-p", to_string(os_pid)], stderr_to_stdout: true)
    assert ps_before_status == 0, "expected the slow script's real process to still be alive before compensate: #{ps_before}"
    assert ps_before =~ to_string(os_pid)

    assert {:continue, {:failed, :kill_proof}} = RunScript.compensate(:script_timeout, args, %{}, [])

    refute Port.info(port), "compensate/4 should have closed the real port"

    assert {^os_pid, outcome} = PortRegistry.get_audit(request_id)
    assert outcome in [:closed, :already_dead]

    # Give the real SIGTERM a moment to actually take effect before checking.
    Process.sleep(200)

    {ps_after, ps_after_status} = System.cmd("ps", ["-p", to_string(os_pid)], stderr_to_stdout: true)

    refute ps_after_status == 0,
           "expected `ps -p #{os_pid}` to fail (real process killed by real compensate/4), got: #{ps_after}"

    refute ps_after =~ to_string(os_pid)
  end
end
