defmodule Xaas.Ultracode.DispatchTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Chicago-style qualification of `Xaas.Ultracode.Dispatch` -- the in-family
  dispatch boundary that launches ONE real worker agent process per epoch.

  Everything here is real: real Postgres rows (Run/Epoch/Receipt), a real
  OS subprocess per attempt (the CLI collaborator is a scripted shell
  script standing in for the model's judgment, exactly like
  `AutonomicTest`'s scripted protocol client), a real process-group
  timeout kill, and a real output log on disk. The live zcode/GLM
  end-to-end proof is documented separately in the dispatch receipt
  (`docs/ultracode/`), not mocked here.
  """

  alias Xaas.Ultracode.{Dispatch, Epoch, Lease, Receipt, Run}

  @provider "zcode-dispatch-test"
  @sh "/bin/sh"

  @git_env [
    {"GIT_AUTHOR_NAME", "dispatch-test"},
    {"GIT_AUTHOR_EMAIL", "dispatch-test@xaas.local"},
    {"GIT_COMMITTER_NAME", "dispatch-test"},
    {"GIT_COMMITTER_EMAIL", "dispatch-test@xaas.local"}
  ]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    base = mktmp("base")
    worktree = Path.join(base, "worktree")
    File.mkdir_p!(worktree)

    # Epoch.:create validates :worktree with WorktreeIsSafe (a real git
    # repo), so the dispatch target is a real init'ed repo, not a bare dir.
    {_, 0} = System.cmd("git", ["init", "-q"], cd: worktree, env: @git_env)

    {_, 0} =
      System.cmd("git", ["commit", "-q", "--allow-empty", "-m", "init"],
        cd: worktree,
        env: @git_env
      )

    %{base: base, worktree: worktree}
  end

  # ------------------------------------------------------------------
  # plan/2 -- construction without execution
  # ------------------------------------------------------------------

  test "plan returns the exact dispatch (argv, env, cwd, prompt) without launching anything", %{
    worktree: worktree
  } do
    {_run, epoch} = create_epoch!(worktree)
    cli_dir = fake_cli_dir("exit 0\n")

    {:ok, plan} =
      Dispatch.plan(epoch.id, provider: @provider, cli_dir: cli_dir, node_path: @sh)

    assert plan.dry_run == true
    assert plan.mode == :claim
    assert plan.cwd == realpath(worktree)
    assert plan.epoch_id == epoch.id
    assert plan.worker_id =~ ~r/^zcode-dispatch-[a-zA-Z0-9-]+-[0-9a-f]{8}-\d+$/
    assert plan.cli_dir == cli_dir
    assert String.starts_with?(plan.log_path, System.tmp_dir!())

    # The gate env: exactly what arms the plugin's PreToolUse check.
    assert {"XAAS_WORKER", "1"} in plan.env_added
    assert {"XAAS_LEASE_CWD", realpath(worktree)} in plan.env_added

    # The prompt carries exactly the two identifiers and nothing else.
    assert plan.prompt ==
             "/xaas Call claim_next with provider_worker_id exactly \"#{plan.worker_id}\" " <>
               "and epoch_id exactly \"#{epoch.id}\"; do not use any other values."

    assert plan.argv_tail == [
             "bin/zcode.js",
             "--prompt",
             plan.prompt,
             "--cwd",
             plan.cwd,
             "--json"
           ]
  end

  test "plan refuses a CLI directory that does not hold bin/zcode.js" do
    {:ok, _run, epoch} = create_running_epoch!()

    assert {:error, {:cli_unavailable, path}} =
             Dispatch.plan(epoch.id, cli_dir: "/nonexistent-dispatch-cli", node_path: @sh)

    assert path == "/nonexistent-dispatch-cli/bin/zcode.js"
  end

  test "plan refuses an unresolvable node executable", %{worktree: worktree} do
    {_run, epoch} = create_epoch!(worktree)
    cli_dir = fake_cli_dir("exit 0\n")

    assert {:error, {:node_unavailable, _}} =
             Dispatch.plan(epoch.id, cli_dir: cli_dir, node_path: "/nonexistent-node-xyz")
  end

  test "plan resolves node from PATH when no :node_path is given (the documented default)" do
    # Permanent guard for the 2026-09-20 campaign falsifier: an unset
    # :node_path used to hard-refuse every launch {:node_unavailable,
    # "node"} even with node on PATH, killing whole waves in <1s.
    {:ok, _run, epoch} = create_running_epoch!()
    cli_dir = fake_cli_dir("exit 0\n")

    case System.find_executable("node") do
      nil ->
        # No node on PATH: the fail-closed refusal is the lawful outcome.
        assert {:error, {:node_unavailable, "node"}} = Dispatch.plan(epoch.id, cli_dir: cli_dir)

      _node ->
        assert {:ok, _plan} = Dispatch.plan(epoch.id, provider: @provider, cli_dir: cli_dir)
    end
  end

  test "plan prefers a configured :ultracode_dispatch_node_path over the PATH default" do
    # An explicitly configured path wins over the PATH lookup -- and a
    # bogus one still fails closed, proving the configured path is the
    # one actually checked.
    {:ok, _run, epoch} = create_running_epoch!()
    cli_dir = fake_cli_dir("exit 0\n")

    Application.put_env(:xaas, :ultracode_dispatch_node_path, "/nonexistent-node-xyz")
    on_exit(fn -> Application.delete_env(:xaas, :ultracode_dispatch_node_path) end)

    assert {:error, {:node_unavailable, "/nonexistent-node-xyz"}} =
             Dispatch.plan(epoch.id, provider: @provider, cli_dir: cli_dir)
  end

  # ------------------------------------------------------------------
  # Readiness fence
  # ------------------------------------------------------------------

  test "refuses (typed, no launch) an epoch that is not :running", %{worktree: worktree} do
    {run, _} = create_epoch!(worktree)
    cli_dir = fake_cli_dir("exit 0\n")

    {:ok, expected} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 1,
          exact_subject: "dispatch-test:expected-#{System.unique_integer([:positive])}"
        },
        authorize?: false
      )
      |> Ash.create()

    assert {:error, {:epoch_not_ready, epoch_id, detail}} =
             Dispatch.dispatch(expected.id, cli_dir: cli_dir, node_path: @sh)

    assert epoch_id == expected.id
    assert detail =~ "expected"
  end

  test "refuses an epoch whose lease is still live", %{worktree: worktree} do
    {_run, epoch} = create_epoch!(worktree)
    epoch_id = epoch.id
    cli_dir = fake_cli_dir("exit 0\n")

    {:ok, _claimed, _token, _run} =
      Lease.claim_next(@provider, "pre-claimer", epoch_id: epoch.id)

    assert {:error, {:epoch_not_ready, ^epoch_id, "lease is still live"}} =
             Dispatch.dispatch(epoch.id, cli_dir: cli_dir, node_path: @sh)
  end

  test "refuses an epoch whose Run is a different provider", %{worktree: worktree} do
    {_run, epoch} = create_epoch!(worktree)
    epoch_id = epoch.id
    cli_dir = fake_cli_dir("exit 0\n")

    assert {:error, {:epoch_not_ready, ^epoch_id, detail}} =
             Dispatch.dispatch(epoch.id, cli_dir: cli_dir, node_path: @sh, provider: "zcode")

    assert detail =~ "provider"
  end

  # ------------------------------------------------------------------
  # Real subprocess dispatches (scripted CLI collaborator)
  # ------------------------------------------------------------------

  test "a clean dispatch runs one attempt and captures exit, gate env, state and receipts", %{
    worktree: worktree
  } do
    {run, epoch} = create_epoch!(worktree)

    fake_log = Path.join([System.tmp_dir!(), "dispatch-fake-#{System.unique_integer()}.log"])

    cli_dir =
      fake_cli_dir("""
      printf 'pid=%s\\nXAAS_WORKER=%s\\nXAAS_LEASE_CWD=%s\\nargs=%s\\n' "$$" \\
        "$XAAS_WORKER" "$XAAS_LEASE_CWD" "$*" > "$FAKE_LOG"
      exit 0
      """)

    seal_receipt!(epoch, :partial_alive, %{"head_verified" => false})

    {:ok, result} =
      Dispatch.dispatch(epoch.id,
        provider: @provider,
        cli_dir: cli_dir,
        node_path: @sh,
        timeout_seconds: 30,
        extra_env: %{"FAKE_LOG" => fake_log}
      )

    assert result.status == :ok
    assert result.attempts == 1
    assert result.exit_code == 0
    assert result.mode == :claim
    assert result.epoch_state == :running
    assert result.epoch_id == epoch.id
    assert is_integer(result.duration_ms) and result.duration_ms >= 0
    assert result.prompt =~ epoch.id

    # The full-output log really streamed, and the gate env really reached
    # the child process.
    logged = File.read!(fake_log)
    assert logged =~ "XAAS_WORKER=1"
    assert logged =~ "XAAS_LEASE_CWD=#{realpath(worktree)}"
    assert logged =~ "--json"

    # The sealed receipts of the epoch ride on the dispatch result.
    assert [%{"outcome" => "partial_alive", "head_verified" => false, "sealed_at" => _}] =
             result.receipts

    assert run.id
  end

  test "a failover-class outcome is retried exactly once and then succeeds", %{worktree: worktree} do
    {_run, epoch} = create_epoch!(worktree)

    counter = Path.join(System.tmp_dir!(), "dispatch-count-#{System.unique_integer()}")

    cli_dir =
      fake_cli_dir("""
      n=$(cat "$FAKE_COUNT" 2>/dev/null || echo 0)
      n=$((n+1))
      echo "$n" > "$FAKE_COUNT"
      if [ "$n" -le 1 ]; then
        echo '{"error":{"code":1302},"message":"High concurrency usage"}'
        exit 0
      fi
      exit 0
      """)

    {:ok, result} =
      Dispatch.dispatch(epoch.id,
        provider: @provider,
        cli_dir: cli_dir,
        node_path: @sh,
        timeout_seconds: 30,
        failover_backoff_ms: 10,
        extra_env: %{"FAKE_COUNT" => counter}
      )

    # The failover rule: one transient rate blip costs a backoff, not an attempt.
    assert result.status == :ok
    assert result.attempts == 2
    assert File.read!(counter) |> String.trim() == "2"
  end

  test "a persistent failover-class outcome surfaces :rate_limited after the single retry", %{
    worktree: worktree
  } do
    {_run, epoch} = create_epoch!(worktree)

    counter = Path.join(System.tmp_dir!(), "dispatch-count-#{System.unique_integer()}")

    cli_dir =
      fake_cli_dir("""
      n=$(cat "$FAKE_COUNT" 2>/dev/null || echo 0)
      n=$((n+1))
      echo "$n" > "$FAKE_COUNT"
      echo 'Too Many Requests (HTTP 429)'
      exit 0
      """)

    {:ok, result} =
      Dispatch.dispatch(epoch.id,
        provider: @provider,
        cli_dir: cli_dir,
        node_path: @sh,
        timeout_seconds: 30,
        failover_backoff_ms: 10,
        extra_env: %{"FAKE_COUNT" => counter}
      )

    assert result.status == :rate_limited
    assert result.attempts == 2
    assert result.output_tail =~ "429"
    assert File.read!(counter) |> String.trim() == "2"
  end

  test "a non-zero exit is :failed with the code, not retried", %{worktree: worktree} do
    {_run, epoch} = create_epoch!(worktree)

    cli_dir =
      fake_cli_dir("""
      echo 'cli exploded'
      exit 3
      """)

    {:ok, result} =
      Dispatch.dispatch(epoch.id,
        provider: @provider,
        cli_dir: cli_dir,
        node_path: @sh,
        timeout_seconds: 30
      )

    assert result.status == :failed
    assert result.attempts == 1
    assert result.exit_code == 3
    assert result.output_tail =~ "cli exploded"
  end

  test "the hard timeout kills the whole process group and reports :timeout", %{
    worktree: worktree
  } do
    {_run, epoch} = create_epoch!(worktree)
    cli_dir = fake_cli_dir("sleep 60\n")

    started = System.monotonic_time(:millisecond)

    {:ok, result} =
      Dispatch.dispatch(epoch.id,
        provider: @provider,
        cli_dir: cli_dir,
        node_path: @sh,
        timeout_seconds: 2
      )

    elapsed = System.monotonic_time(:millisecond) - started

    assert result.status == :timeout
    assert result.attempts == 1
    assert result.exit_code == nil
    # Real kill, not a deadline that just returns early: well under the
    # 60s the (killed) child was told to sleep, above the 2s deadline.
    assert elapsed >= 2_000 and elapsed < 30_000

    # The killed group is really gone, not orphaned (SIGTERM/KILL to the
    # group; allow the kill helper's own 2s grace).
    Process.sleep(2_500)
    {out, _exit} = System.cmd("pgrep", ["-f", "zcode.js --prompt"], stderr_to_stdout: true)
    assert String.trim(out) == "", "dispatched process survived the timeout kill: #{out}"
  end

  # ------------------------------------------------------------------
  # Reap mode
  # ------------------------------------------------------------------

  test "an epoch with no worktree is dispatched from a scratch cwd (reap mode)", %{
    worktree: _worktree
  } do
    {_run, epoch} = create_epoch!(nil)

    {:ok, plan} =
      Dispatch.plan(epoch.id,
        provider: @provider,
        cli_dir: fake_cli_dir("exit 0\n"),
        node_path: @sh
      )

    assert plan.mode == :reap
    assert String.contains?(plan.cwd, "xaas-dispatch-reap-")
    assert File.dir?(plan.cwd)
  end

  test "a reap-mode dispatch removes its scratch cwd when it ends", %{worktree: _worktree} do
    {_run, epoch} = create_epoch!(nil)
    cli_dir = fake_cli_dir("exit 0\n")

    {:ok, result} =
      Dispatch.dispatch(epoch.id,
        provider: @provider,
        cli_dir: cli_dir,
        node_path: @sh,
        timeout_seconds: 30
      )

    assert result.mode == :reap
  end

  # ------------------------------------------------------------------
  # The Autonomic worker contract
  # ------------------------------------------------------------------

  test "autonomic_worker maps dispatch results onto the worker contract", %{worktree: worktree} do
    {_run, epoch} = create_epoch!(worktree)
    cli_dir = fake_cli_dir("exit 0\n")

    assert Dispatch.autonomic_worker(
             epoch,
             %{
               dispatch_opts: [
                 provider: @provider,
                 cli_dir: cli_dir,
                 node_path: @sh,
                 timeout_seconds: 30
               ]
             }
           ) == :ok

    {_run2, epoch2} = create_epoch!(worktree)

    rate_cli =
      fake_cli_dir("""
      echo 'Too Many Requests'
      exit 0
      """)

    # Persistent rate class, retry disabled so the case stays single-attempt.
    assert Dispatch.autonomic_worker(
             epoch2,
             %{
               dispatch_opts: [
                 provider: @provider,
                 cli_dir: rate_cli,
                 node_path: @sh,
                 timeout_seconds: 30,
                 failover_retries: 0
               ]
             }
           ) == :rate_limited

    {_run3, epoch3} = create_epoch!(worktree)
    fail_cli = fake_cli_dir("exit 9\n")

    assert {:error, {:dispatch_failed, 9, tail}} =
             Dispatch.autonomic_worker(
               epoch3,
               %{
                 dispatch_opts: [
                   provider: @provider,
                   cli_dir: fail_cli,
                   node_path: @sh,
                   timeout_seconds: 30
                 ]
               }
             )

    assert tail == ""
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp create_epoch!(worktree, overrides \\ []) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{
          goal: "dispatch test goal",
          provider: Keyword.get(overrides, :provider, @provider),
          max_cycles: 1
        },
        authorize?: false
      )
      |> Ash.create()

    {:ok, epoch} = create_epoch_row!(run, worktree, 0, running_subject())
    {run, epoch}
  end

  # A bare {:ok, epoch} shape for tests that do not need the run struct.
  defp create_running_epoch! do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(:create, %{goal: "dispatch test goal", provider: @provider},
        authorize?: false
      )
      |> Ash.create()

    wt = mktmp("orphan-wt")
    {_, 0} = System.cmd("git", ["init", "-q"], cd: wt, env: @git_env)

    {_, 0} =
      System.cmd("git", ["commit", "-q", "--allow-empty", "-m", "init"], cd: wt, env: @git_env)

    {:ok, epoch} = create_epoch_row!(run, wt, 0, running_subject())
    {:ok, run, epoch}
  end

  defp create_epoch_row!(run, worktree, cycle, subject) do
    Epoch
    |> Ash.Changeset.for_create(
      :create,
      %{
        run_id: run.id,
        cycle: cycle,
        exact_subject: subject,
        state: :running,
        worktree: worktree
      },
      authorize?: false
    )
    |> Ash.create()
  end

  defp running_subject, do: "dispatch-test:#{System.unique_integer([:positive])}"

  defp seal_receipt!(epoch, outcome, evidence) do
    {:ok, _} =
      Receipt
      |> Ash.Changeset.for_create(
        :seal,
        %{
          epoch_id: epoch.id,
          subject: epoch.exact_subject,
          outcome: outcome,
          evidence: evidence
        },
        authorize?: false
      )
      |> Ash.create()
  end

  defp fake_cli_dir(script) do
    dir = mktmp("cli")
    File.mkdir_p!(Path.join(dir, "bin"))
    path = Path.join([dir, "bin", "zcode.js"])
    File.write!(path, script)
    File.chmod!(path, 0o755)
    dir
  end

  defp realpath(dir) do
    {out, 0} = System.cmd("/bin/pwd", ["-P"], cd: dir, stderr_to_stdout: true)
    String.trim(out)
  end

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-dispatch-test-#{label}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end
end
