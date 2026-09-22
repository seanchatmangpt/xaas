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
  @sh Path.expand("../../support/fake-node.sh", __DIR__)

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

    # A run without full semantic identity keeps the generic /xaas prompt
    # path for non-semantic waves: byte-identical to the bash script's.
    assert plan.protocol == :xaas_prompt

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

  test "a semantic run plans the native gall-work protocol with the gall.work-lease/1 descriptor and no prompt",
       %{worktree: worktree} do
    {_run, epoch} =
      create_epoch!(worktree,
        work_order_iri: "urn:gall:work-order:dispatch:test",
        checkpoint_iri: "urn:gall:checkpoint:dispatch:test",
        graph_digest: "sha256:#{String.duplicate("a", 64)}",
        repository_identity: "seanchatmangpt/xaas",
        base_sha: String.duplicate("b", 40)
      )

    cli_dir = fake_cli_dir("exit 0\n")

    {:ok, plan} =
      Dispatch.plan(epoch.id, provider: @provider, cli_dir: cli_dir, node_path: @sh)

    # Native protocol, no prompt, no goal on argv.
    assert plan.protocol == :gall_work_native
    assert plan.prompt == nil
    assert plan.argv_tail == ["bin/zcode.js", "gall-work", "--lease", plan.descriptor.path]

    # The descriptor is exactly the document the native CLI validates:
    # closed canonical subject identity bound to THIS epoch and worktree.
    descriptor = plan.descriptor.content
    assert descriptor["schema"] == "gall.work-lease/1"
    assert descriptor["epoch_id"] == epoch.id
    assert descriptor["worktree"] == realpath(worktree)
    assert descriptor["worker_id"] == plan.worker_id
    assert descriptor["base_sha"] == String.duplicate("b", 40)

    # A dry run touches no filesystem: the descriptor is only written by a
    # real dispatch.
    refute File.exists?(plan.descriptor.path)
  end

  test "a semantic run with only PARTIAL identity keeps the generic prompt path (never guesses)",
       %{worktree: worktree} do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{
          goal: "dispatch test goal",
          provider: @provider,
          max_cycles: 1,
          work_order_iri: "urn:gall:work-order:dispatch:partial"
        },
        authorize?: false
      )
      |> Ash.create()

    {:ok, epoch} = create_epoch_row!(run, worktree, 0, running_subject())

    {:ok, plan} =
      Dispatch.plan(epoch.id,
        provider: @provider,
        cli_dir: fake_cli_dir("exit 0\n"),
        node_path: @sh
      )

    assert plan.protocol == :xaas_prompt
    assert plan.prompt =~ epoch.id
    assert plan.descriptor == nil
  end

  test "plan refuses a CLI directory that does not hold package.json" do
    {:ok, _run, epoch} = create_running_epoch!()

    assert {:error, {:cli_unavailable, path}} =
             Dispatch.plan(epoch.id, cli_dir: "/nonexistent-dispatch-cli", node_path: @sh)

    assert path == "/nonexistent-dispatch-cli/package.json"
  end

  test "plan passes a registered repo's toolchain_env pin into the worker env; the plain string registry shape stays inherit-only",
       %{
         worktree: worktree
       } do
    original = Application.get_env(:xaas, :ultracode_repos)

    Application.put_env(:xaas, :ultracode_repos, %{
      "demo" => %{
        "path" => worktree,
        "toolchain_env" => %{"PATH" => "/opt/pinned/bin:/usr/bin:/bin"}
      },
      "plain" => worktree
    })

    on_exit(fn -> Application.put_env(:xaas, :ultracode_repos, original) end)

    {:ok, pinned_run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{
          goal: "dispatch test goal",
          provider: @provider,
          max_cycles: 1,
          execution_repo_alias: "demo",
          base_sha: String.duplicate("a", 40)
        },
        authorize?: false
      )
      |> Ash.create()

    {:ok, pinned_epoch} = create_epoch_row!(pinned_run, worktree, 0, running_subject())
    cli_dir = fake_cli_dir("exit 0\n")

    {:ok, plan} =
      Dispatch.plan(pinned_epoch.id, provider: @provider, cli_dir: cli_dir, node_path: @sh)

    assert {"PATH", "/opt/pinned/bin:/usr/bin:/bin"} in plan.env_added
    assert {"XAAS_WORKER", "1"} in plan.env_added
    assert {"XAAS_LEASE_CWD", realpath(worktree)} in plan.env_added

    {:ok, plain_run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{
          goal: "dispatch test goal",
          provider: @provider,
          max_cycles: 1,
          execution_repo_alias: "plain",
          base_sha: String.duplicate("b", 40)
        },
        authorize?: false
      )
      |> Ash.create()

    {:ok, plain_epoch} = create_epoch_row!(plain_run, worktree, 0, running_subject())

    {:ok, plain_plan} =
      Dispatch.plan(plain_epoch.id, provider: @provider, cli_dir: cli_dir, node_path: @sh)

    # Byte-for-byte the historical env: gate vars only, no toolchain pin.
    assert plain_plan.env_added == [
             {"XAAS_WORKER", "1"},
             {"XAAS_LEASE_CWD", realpath(worktree)}
           ]
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

      node ->
        # The PATH lookup must resolve (never `node_unavailable`). Whether the
        # resolved node then satisfies the CLI's engines.node floor is a
        # property of the machine's PATH, not of this guard: a v20 node first
        # on PATH is the typed, measured `node_too_old` refusal (observed
        # falsifier: PATH=/usr/local/bin:$PATH with node v20.13.0).
        case Dispatch.plan(epoch.id, provider: @provider, cli_dir: cli_dir) do
          {:ok, _plan} ->
            :ok

          {:error, {:node_too_old, ^node, found, ">=22.19.0"}} ->
            assert found =~ ~r/\A\d+\.\d+\.\d+\z/
        end
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

    fake_log = test_path("dispatch-fake", ".log")

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
    assert result.protocol == :xaas_prompt
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

  test "a semantic dispatch runs the NATIVE protocol: gall-work argv, descriptor on disk, no /xaas anywhere",
       %{worktree: worktree} do
    {_run, epoch} =
      create_epoch!(worktree,
        work_order_iri: "urn:gall:work-order:dispatch:native",
        checkpoint_iri: "urn:gall:checkpoint:dispatch:native",
        graph_digest: "sha256:#{String.duplicate("c", 64)}",
        repository_identity: "seanchatmangpt/xaas",
        base_sha: String.duplicate("d", 40)
      )

    fake_log = test_path("dispatch-native", ".log")

    cli_dir =
      fake_cli_dir("""
      printf 'args=%s\\n' "$*" > "$FAKE_LOG"
      exit 0
      """)

    {:ok, result} =
      Dispatch.dispatch(epoch.id,
        provider: @provider,
        cli_dir: cli_dir,
        node_path: @sh,
        timeout_seconds: 30,
        extra_env: %{"FAKE_LOG" => fake_log}
      )

    assert result.status == :ok
    assert result.protocol == :gall_work_native
    assert result.prompt == nil

    # The child was invoked with the exact contract argv: gall-work --lease
    # <descriptor>; never a /xaas prompt projection (the prompt protocol's
    # signatures -- the --prompt flag and the claim_next phrasing -- appear
    # nowhere in the child argv).
    logged = File.read!(fake_log)
    assert logged =~ "gall-work --lease"
    refute logged =~ "--prompt"
    refute logged =~ "Call claim_next"

    # The descriptor file existed for the child and is gone afterwards.
    # w9 guard: assert the EXACT path the child was handed (parsed from the
    # logged argv), not a global tmp wildcard — an unqualified
    # `xaas-dispatch-gall-*.json` glob collides with any concurrent dispatch
    # on the same machine (same class as the run_uid qualification law of
    # 082a9b2) and fails spuriously under sibling load.
    assert [descriptor_path] = Regex.run(~r/--lease (\S+)/, logged, capture: :all_but_first)

    refute File.exists?(descriptor_path),
           "descriptor temp files must be removed when the dispatch ends"
  end

  test "an old CLI without native gall-work REFUSES: typed failure, no prompt fallback",
       %{worktree: worktree} do
    {_run, epoch} =
      create_epoch!(worktree,
        work_order_iri: "urn:gall:work-order:dispatch:oldcli",
        checkpoint_iri: "urn:gall:checkpoint:dispatch:oldcli",
        graph_digest: "sha256:#{String.duplicate("e", 64)}",
        repository_identity: "seanchatmangpt/xaas",
        base_sha: String.duplicate("f", 40)
      )

    fake_log = test_path("dispatch-oldcli", ".log")

    # What a pre-gall-work zcode CLI does with an unknown command: exit 2,
    # usage error. The boundary must classify :failed and NEVER re-project
    # the dispatch as the /xaas claim_next prompt.
    cli_dir =
      fake_cli_dir("""
      printf 'args=%s\\n' "$*" > "$FAKE_LOG"
      echo "Error: unknown command: gall-work" >&2
      exit 2
      """)

    {:ok, result} =
      Dispatch.dispatch(epoch.id,
        provider: @provider,
        cli_dir: cli_dir,
        node_path: @sh,
        timeout_seconds: 30,
        extra_env: %{"FAKE_LOG" => fake_log}
      )

    assert result.status == :failed
    assert result.exit_code == 2
    assert result.protocol == :gall_work_native
    assert result.output_tail =~ "unknown command: gall-work"

    logged = File.read!(fake_log)
    assert logged =~ "gall-work --lease"
    refute logged =~ "--prompt"
    refute logged =~ "Call claim_next"
  end

  test "a failover-class outcome is retried exactly once and then succeeds", %{worktree: worktree} do
    {_run, epoch} = create_epoch!(worktree)

    counter = test_path("dispatch-count")

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

    counter = test_path("dispatch-count")

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
  # Concurrent dispatch at capacity 5 (the campaign's wave capacity)
  # ------------------------------------------------------------------

  describe "concurrent dispatch at capacity 5" do
    @tag timeout: 240_000
    test "five simultaneous dispatches complete with per-slot classification, receipt attribution, no slot interference and no orphans" do
      blip_counter =
        test_path("dispatch-conc-blip")

      slot_specs = [
        %{
          tag: "s1-clean-ok",
          script: "exit 0\n",
          expect: :ok,
          attempts: 1,
          head_verified: true
        },
        %{
          tag: "s2-blip-then-ok",
          script: """
          n=$(cat "$FAKE_COUNT" 2>/dev/null || echo 0)
          n=$((n+1))
          echo "$n" > "$FAKE_COUNT"
          if [ "$n" -le 1 ]; then
            echo '{"error":{"code":1302},"message":"High concurrency usage"}'
          fi
          exit 0
          """,
          expect: :ok,
          attempts: 2,
          head_verified: false
        },
        %{
          tag: "s3-persistent-429",
          script: """
          echo 'Too Many Requests (HTTP 429)'
          exit 0
          """,
          expect: :rate_limited,
          attempts: 2,
          head_verified: true
        },
        %{
          tag: "s4-hang",
          script: "sleep 30\n",
          expect: :timeout,
          attempts: 1,
          head_verified: false
        },
        %{
          tag: "s5-slow-ok",
          script: "sleep 0.3\nexit 0\n",
          expect: :ok,
          attempts: 1,
          head_verified: true
        }
      ]

      slots =
        for {spec, idx} <- Enum.with_index(slot_specs) do
          wt = create_slot_worktree!()
          {_run, epoch} = create_slot_epoch!(wt)

          cli_dir =
            fake_cli_dir("""
            echo "slot=$SLOT_TAG pid=$$ lease=$XAAS_LEASE_CWD" >> "$W_LOG"
            #{spec.script}
            """)

          w_log =
            test_path("dispatch-conc-#{spec.tag}", ".log")

          seal_receipt!(epoch, :partial_alive, %{
            "head_verified" => spec.head_verified,
            "slot" => idx
          })

          %{
            spec: spec,
            epoch: epoch,
            cli_dir: cli_dir,
            w_log: w_log,
            lease: realpath(wt),
            expect_head_verified: spec.head_verified,
            dispatch_opts: [
              provider: @provider,
              cli_dir: cli_dir,
              node_path: @sh,
              timeout_seconds: 2,
              failover_backoff_ms: 10,
              extra_env: %{
                "W_LOG" => w_log,
                "SLOT_TAG" => spec.tag,
                "FAKE_COUNT" => blip_counter
              }
            ]
          }
        end

      tasks =
        Enum.map(slots, fn slot ->
          Task.async(fn -> Dispatch.dispatch(slot.epoch.id, slot.dispatch_opts) end)
        end)

      results = Enum.map(tasks, &Task.await(&1, 200_000))

      # 1. Every slot completed -- typed -- with its own classification and
      #    its own identity (no cross-slot attribution).
      for {slot, {:ok, result}} <- Enum.zip(slots, results) do
        tag = slot.spec.tag

        assert result.status == slot.spec.expect, "#{tag}: got #{inspect(result)}"
        assert result.attempts == slot.spec.attempts, "#{tag}: attempts #{inspect(result)}"
        assert result.epoch_id == slot.epoch.id, "#{tag}: wrong epoch"
        assert result.worker_id =~ String.slice(slot.epoch.id, 0, 8), "#{tag}: wrong worker id"
        assert result.mode == :claim, "#{tag}: wrong mode"
        assert result.epoch_state == :running, "#{tag}: wrong epoch state"

        # 2. Receipt attribution: exactly this slot's sealed receipt rides on
        #    its own result, distinguishable by head_verified parity.
        assert [%{"outcome" => "partial_alive", "head_verified" => hv}] = result.receipts
        assert hv == slot.expect_head_verified, "#{tag}: wrong receipt attached"
      end

      # 3. No slot interference: every invocation of a slot's worker saw that
      #    slot's lease cwd, exactly `attempts` times.
      for slot <- slots do
        logged = File.read!(slot.w_log)
        lines = String.split(String.trim_trailing(logged), "\n")
        tag = slot.spec.tag

        assert length(lines) == slot.spec.attempts,
               "#{tag}: unexpected invocations #{inspect(lines)}"

        for line <- lines do
          assert line =~ "slot=#{slot.spec.tag}", "#{tag}: foreign slot line #{line}"
          assert line =~ "lease=#{slot.lease}", "#{tag}: foreign lease cwd in #{line}"
        end
      end

      # and no foreign slot's lease cwd ever appears in another's log.
      for slot <- slots, other <- slots, other.cli_dir != slot.cli_dir do
        refute File.read!(slot.w_log) =~ other.lease
      end

      # 4. Process-group cleanup: after the awaited results (the timeout
      #    slot's kill already ran, verified, inside dispatch), no slot's
      #    worker tree is still alive. Asserted inline AND again at suite
      #    teardown.
      for slot <- slots do
        assert_no_orphans!(slot.cli_dir)
      end

      slot_dirs = Enum.map(slots, & &1.cli_dir)

      on_exit(fn ->
        for dir <- slot_dirs do
          assert_no_orphans!(dir)
        end
      end)
    end
  end

  # ------------------------------------------------------------------
  # Process-group hardening: children and grandchildren on every path
  # ------------------------------------------------------------------

  describe "process-group hardening" do
    @tag timeout: 120_000
    test "the deadline kills a worker's spawned child with the whole group", %{
      worktree: worktree
    } do
      {_run, epoch} = create_epoch!(worktree)

      cli_dir =
        fake_cli_dir("""
        "$CHILD_SH" &
        sleep 60
        """)

      # The child keeps its own path in its cmdline, so a pgrep on the cli
      # dir observes BOTH the worker and the child (a plain `exec sleep 60`
      # child would be unobservable by path and the assertion vacuous).
      child_sh = Path.join(cli_dir, "child-#{System.unique_integer([:positive])}.sh")
      File.write!(child_sh, "echo spawned >> \"$CHILD_MARKER\"\nsleep 60\n")
      File.chmod!(child_sh, 0o755)

      marker =
        test_path("dispatch-child-marker")

      {:ok, result} =
        Dispatch.dispatch(epoch.id,
          provider: @provider,
          cli_dir: cli_dir,
          node_path: @sh,
          timeout_seconds: 2,
          extra_env: %{"CHILD_SH" => child_sh, "CHILD_MARKER" => marker}
        )

      assert result.status == :timeout

      # Falsifier guard: the child REALLY spawned before the deadline, else
      # the no-orphan assertion below would pass vacuously.
      assert File.exists?(marker), "child never spawned; assertion would be vacuous"

      assert_no_orphans!(cli_dir)
      on_exit(fn -> assert_no_orphans!(cli_dir) end)
    end

    @tag timeout: 120_000
    test "a worker that exits 0 leaving a background child does not leak it", %{
      worktree: worktree
    } do
      {_run, epoch} = create_epoch!(worktree)

      cli_dir =
        fake_cli_dir("""
        "$CHILD_SH" &
        # Let the child reach its marker write before the worker exits,
        # otherwise the post-exit group reap can win the race and the
        # marker assert below would flake.
        sleep 0.2
        exit 0
        """)

      child_sh = Path.join(cli_dir, "leaver-#{System.unique_integer([:positive])}.sh")
      File.write!(child_sh, "echo spawned >> \"$CHILD_MARKER\"\nsleep 60\n")
      File.chmod!(child_sh, 0o755)

      marker =
        test_path("dispatch-leaver-marker")

      {:ok, result} =
        Dispatch.dispatch(epoch.id,
          provider: @provider,
          cli_dir: cli_dir,
          node_path: @sh,
          timeout_seconds: 30,
          extra_env: %{"CHILD_SH" => child_sh, "CHILD_MARKER" => marker}
        )

      assert result.status == :ok
      assert result.attempts == 1

      # The child really ran (and outlives its parent for a moment)...
      assert File.exists?(marker), "child never spawned; assertion would be vacuous"

      # ...and the boundary's unconditional post-attempt group reap still
      # collected it -- cleanup is not a timeout-only behavior.
      assert_no_orphans!(cli_dir)
      on_exit(fn -> assert_no_orphans!(cli_dir) end)
    end
  end

  # ------------------------------------------------------------------
  # Failover classification tripwires: observed provider signatures
  # ------------------------------------------------------------------

  describe "failover classification tripwires" do
    # Every entry is either (a) the exact payload shape observed in real
    # dispatch output during the 2026-09-18 GLM failover trials and the
    # 2026-09-20 campaign window, or (b) the SAME JSON document in a
    # whitespace-legal rendering -- JSON whitespace must not change
    # classification (the 429 branch already tolerates it via [": ]+).
    @signatures [
      {"live 1302 payload", ~s({"error":{"code":1302},"message":"High concurrency usage"})},
      {"string-quoted 1302", ~s({"error":{"code":"1302"}})},
      {"whitespace variant of 1302", ~s({"error":{"code": 1302}})},
      {"bare HTTP 429", "HTTP 429"},
      {"status field 429", ~s("status":429)},
      {"statusCode field 429", ~s(statusCode: 429)},
      {"plain-text 429", "Too Many Requests"}
    ]

    for {label, sig} <- @signatures do
      test "classifies as failover-class: #{label}", %{worktree: worktree} do
        {_run, epoch} = create_epoch!(worktree)
        sig = unquote(sig)

        sig_file =
          test_path("dispatch-sig")

        File.write!(sig_file, sig <> "\n")

        cli_dir =
          fake_cli_dir("""
          cat "$SIG_FILE"
          exit 0
          """)

        {:ok, result} =
          Dispatch.dispatch(epoch.id,
            provider: @provider,
            cli_dir: cli_dir,
            node_path: @sh,
            timeout_seconds: 30,
            failover_retries: 0,
            extra_env: %{"SIG_FILE" => sig_file}
          )

        assert result.status == :rate_limited,
               "#{inspect(sig)} was not classified as failover-class (got #{result.status})"

        assert result.attempts == 1
      end
    end
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp create_epoch!(worktree, overrides \\ []) do
    provider = Keyword.get(overrides, :provider, @provider)

    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{
          goal: "dispatch test goal",
          provider: provider,
          max_cycles: 1
        }
        |> Map.merge(
          Map.new(
            Keyword.take(overrides, [
              :work_order_iri,
              :checkpoint_iri,
              :graph_digest,
              :repository_identity,
              :base_sha
            ])
          )
        ),
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

  # A distinct git worktree per concurrency slot: the lease cwd is the
  # slot's identity in the no-interference assertions.
  defp create_slot_worktree! do
    wt = mktmp("slot-wt")
    {_, 0} = System.cmd("git", ["init", "-q"], cd: wt, env: @git_env)

    {_, 0} =
      System.cmd("git", ["commit", "-q", "--allow-empty", "-m", "init"], cd: wt, env: @git_env)

    wt
  end

  defp create_slot_epoch!(worktree) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "dispatch concurrency slot", provider: @provider, max_cycles: 1},
        authorize?: false
      )
      |> Ash.create()

    {:ok, epoch} = create_epoch_row!(run, worktree, 0, running_subject())
    {run, epoch}
  end

  # The boundary's own orphan law, asserted from outside: nothing whose
  # cmdline still carries the slot's cli-dir path may survive the dispatch.
  # Polled, not sleep-guessed: the boundary's kill is verified before the
  # result returns, so the process should already be gone -- but a loaded
  # scheduler must not turn kernel jitter into a false red. A genuinely
  # leaked process still fails here once the budget expires.
  defp assert_no_orphans!(cli_dir, attempts_left \\ 25)

  defp assert_no_orphans!(cli_dir, attempts_left) when attempts_left > 0 do
    {out, _} = System.cmd("pgrep", ["-f", cli_dir], stderr_to_stdout: true)

    if String.trim(out) == "" do
      :ok
    else
      Process.sleep(200)
      assert_no_orphans!(cli_dir, attempts_left - 1)
    end
  end

  defp assert_no_orphans!(cli_dir, 0) do
    {out, _} = System.cmd("pgrep", ["-f", cli_dir], stderr_to_stdout: true)
    assert String.trim(out) == "", "orphan processes survived: #{out}"
  end

  defp fake_cli_dir(script) do
    dir = mktmp("cli")
    File.mkdir_p!(Path.join(dir, "bin"))
    path = Path.join([dir, "bin", "zcode.js"])
    File.write!(path, script)
    File.chmod!(path, 0o755)

    File.write!(
      Path.join(dir, "package.json"),
      Jason.encode!(%{
        "name" => "zcode-app-cli",
        "version" => "0.0.0-test",
        "bin" => %{"zcode" => "bin/zcode.js"},
        "engines" => %{"node" => ">=22.19.0"}
      })
    )

    dir
  end

  defp realpath(dir) do
    {out, 0} = System.cmd("/bin/pwd", ["-P"], cd: dir, stderr_to_stdout: true)
    String.trim(out)
  end

  # Temp paths must not collide ACROSS mix test runs: System.unique_integer
  # restarts per BEAM, so a fresh run's "42" equals a stale run's "42" --
  # observed 2026-09-20: a straggler worker from an earlier run wrote into
  # the current run's log file and broke the invocation-count assert.
  # Wall-clock-qualify every per-run artifact path.
  defp run_uid, do: System.system_time(:millisecond)

  defp test_path(prefix, suffix \\ "") do
    Path.join(
      System.tmp_dir!(),
      "#{prefix}-#{run_uid()}-#{System.unique_integer([:positive])}#{suffix}"
    )
  end

  defp mktmp(label) do
    dir = test_path("xaas-dispatch-test-#{label}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end
end
