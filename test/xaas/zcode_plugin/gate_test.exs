defmodule Xaas.ZcodePlugin.GateTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Real Chicago-style qualification for the plugin's host-level PreToolUse
  gate (template `priv/zcode_plugin/templates/script-xaas-gate.mjs.tmpl`).

  The gate is the committed ggen projection
  (`priv/zcode_plugin/marketplace/xaas-fabric/scripts/xaas-gate.mjs`),
  executed by a real `node` subprocess fed the same JSON a ZCode PreToolUse hook receives on stdin. Its
  arbiter is the REAL execution-fabric controller (`XaasWeb.Endpoint` served
  over a real Bandit socket, real `admit_tool` against a real lease row in the
  sandboxed Postgres), and its lease state is written by the REAL rendered
  `xaas-lease.mjs save`. Nothing is mocked or stubbed: each assertion is on the
  decision the gate actually emitted (empty stdout = deferred/allowed; a
  `permissionDecision: deny` JSON = blocked).

  Not asserted here: that ZCode itself invokes the hook. That is a property of
  the host runtime, checked by the live worker trials in
  docs/ultracode/FAILOVER-RUNBOOK.md.
  """

  alias Xaas.Ultracode.{Epoch, Lease, Run}

  @scripts "priv/zcode_plugin/marketplace/xaas-fabric/scripts"

  setup_all do
    dir = Path.join(System.tmp_dir!(), "xaas-gate-plugin-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    for name <- ["xaas-gate.mjs", "xaas-lease.mjs"] do
      File.write!(
        Path.join(dir, name),
        File.read!(Path.join(@scripts, name))
      )
    end

    on_exit(fn -> File.rm_rf(dir) end)
    %{plugin_dir: dir}
  end

  setup %{plugin_dir: plugin_dir} do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    {:ok, server} = Bandit.start_link(plug: XaasWeb.Endpoint, port: 0, ip: :loopback)
    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)

    worktree = make_git_worktree()

    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "Gate qualification.", provider: "zcode-gate-test"},
        authorize?: false
      )
      |> Ash.create()

    {:ok, _epoch} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "gate qualification",
          state: :running,
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()

    {:ok, epoch, token, _run} = Lease.claim_next("zcode-gate-test", "gate-worker")

    ctx = %{
      gate: Path.join(plugin_dir, "xaas-gate.mjs"),
      lease_script: Path.join(plugin_dir, "xaas-lease.mjs"),
      url: "http://127.0.0.1:#{port}/internal-api/execution/mcp",
      worktree: worktree
    }

    save_lease(ctx, worktree, %{
      lease_token: token,
      lease_expires_at: DateTime.to_iso8601(epoch.lease_expires_at),
      epoch_id: epoch.id,
      worktree: worktree,
      goal: "Gate qualification."
    })

    %{ctx: ctx}
  end

  test "an interactive session (XAAS_WORKER unset) is a silent pass-through", %{ctx: ctx} do
    assert :allow ==
             gate(ctx, "Write", %{file_path: "/etc/anything"}, [{"XAAS_WORKER", nil}])
  end

  test "lease-protocol MCP tools are deferred, even with no lease at all", %{ctx: ctx} do
    bare = make_plain_dir()

    assert :allow ==
             gate(ctx, "mcp__xaas-execution__claim_next", %{}, [{"XAAS_LEASE_CWD", bare}])

    assert :allow ==
             gate(ctx, "mcp__plugin_xaas-fabric_xaas-execution__close_candidate", %{}, [
               {"XAAS_LEASE_CWD", bare}
             ])
  end

  describe "before a lease is saved" do
    setup %{ctx: ctx} do
      %{bare: make_plain_dir(), ctx: ctx}
    end

    test "consequential tools are denied for want of a live lease", %{ctx: ctx, bare: bare} do
      assert {:deny, reason} =
               gate(ctx, "Write", %{file_path: Path.join(bare, "x.txt")}, [
                 {"XAAS_LEASE_CWD", bare}
               ])

      assert reason =~ "no live lease"

      assert {:deny, reason} =
               gate(ctx, "Bash", %{command: "git status"}, [{"XAAS_LEASE_CWD", bare}])

      assert reason =~ "no live lease"
    end

    test "reading and saving the lease are still possible", %{ctx: ctx, bare: bare} do
      env = [{"XAAS_LEASE_CWD", bare}]
      assert :allow == gate(ctx, "Read", %{file_path: Path.join(bare, "a.txt")}, env)

      assert :allow ==
               gate(
                 ctx,
                 "Bash",
                 %{
                   command:
                     "node \"#{ctx.lease_script}\" save '{\"goal\":\"it'\\''s; a & b > c\"}'"
                 },
                 env
               )

      assert {:deny, _} =
               gate(ctx, "Bash", %{command: "node \"#{ctx.lease_script}\" save x; rm y"}, env)

      assert {:deny, reason} = gate(ctx, "Bash", %{command: "node other.mjs"}, env)
      assert reason =~ "only allowed for the plugin's xaas-lease.mjs"

      assert :allow ==
               gate(ctx, "Bash", %{command: "node \"#{ctx.lease_script}\" get"}, env)
    end

    test "an expired lease admits nothing", %{ctx: ctx, bare: bare} do
      save_lease(ctx, bare, %{
        lease_token: "expired-token",
        lease_expires_at: DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), -60, :second)),
        worktree: bare
      })

      assert {:deny, reason} =
               gate(ctx, "Write", %{file_path: Path.join(bare, "x.txt")}, [
                 {"XAAS_LEASE_CWD", bare}
               ])

      assert reason =~ "no live lease"
    end
  end

  describe "with a live lease: non-Bash tools go through the real admit_tool" do
    test "an admitted tool writing inside the worktree is allowed", %{ctx: ctx} do
      assert :allow == gate(ctx, "Write", %{file_path: Path.join(ctx.worktree, "agent.txt")})
      assert :allow == gate(ctx, "Edit", %{file_path: "nested/dir/file.txt"})
      assert :allow == gate(ctx, "Read", %{file_path: Path.join(ctx.worktree, "agent.txt")})
      assert :allow == gate(ctx, "TodoWrite", %{todos: []})
    end

    test "zcode's Agent tool maps to the server's Task and is admitted", %{ctx: ctx} do
      assert :allow == gate(ctx, "Agent", %{prompt: "x"})
    end

    test "a tool the server does not know is refused by the real arbiter", %{ctx: ctx} do
      assert {:deny, reason} = gate(ctx, "WebSearch", %{query: "x"})
      assert reason =~ "unknown_tool_class"
    end

    test "writes outside the worktree, or inside .git, are denied before admission", %{ctx: ctx} do
      assert {:deny, r1} = gate(ctx, "Write", %{file_path: "/tmp/xaas-gate-escape.txt"})
      assert r1 =~ "outside the leased worktree"

      assert {:deny, r2} = gate(ctx, "Edit", %{file_path: "../escape.txt"})
      assert r2 =~ "outside the leased worktree"

      assert {:deny, r3} = gate(ctx, "Write", %{file_path: ".git/hooks/pre-commit"})
      assert r3 =~ ".git"
    end

    test "a symlink pointing out of the worktree does not smuggle a write past containment",
         %{ctx: ctx} do
      outside = make_plain_dir()
      File.ln_s!(outside, Path.join(ctx.worktree, "link"))

      assert {:deny, reason} = gate(ctx, "Write", %{file_path: "link/pwned.txt"})
      assert reason =~ "outside the leased worktree"
    end

    test "credential directories cannot be read", %{ctx: ctx} do
      assert {:deny, reason} =
               gate(ctx, "Read", %{
                 file_path: Path.join(System.user_home!(), ".zcode/cli/config.json")
               })

      assert reason =~ "not allowed"
    end
  end

  describe "with a live lease: Bash is an argv allowlist" do
    test "worktree-local git verbs are allowed", %{ctx: ctx} do
      for cmd <- [
            "git status",
            "git add -A",
            "git commit -m \"agent commit (ok)\"",
            "git rev-parse HEAD",
            "git log --oneline",
            "git -C #{ctx.worktree} diff"
          ] do
        assert :allow == gate(ctx, "Bash", %{command: cmd}), "expected #{cmd} to be allowed"
      end
    end

    test "push, config injection, and other repos are denied", %{ctx: ctx} do
      for cmd <- [
            "git push origin main",
            "git -c core.hooksPath=/tmp/x status",
            "git commit -F /etc/passwd",
            "git -C /tmp status",
            "git remote add x y"
          ] do
        assert {:deny, _} = gate(ctx, "Bash", %{command: cmd}), "expected #{cmd} to be denied"
      end
    end

    test "chaining, pipes, redirection, substitution and globs are all denied", %{ctx: ctx} do
      for cmd <- [
            "git status; rm -rf x",
            "git status && curl http://evil",
            "git status | sh",
            "echo hi > agent.txt",
            "echo $(whoami)",
            "echo `whoami`",
            "ls *",
            "ls ~",
            "FOO=1 git status"
          ] do
        assert {:deny, reason} = gate(ctx, "Bash", %{command: cmd}),
               "expected #{cmd} to be denied"

        assert reason =~ "not a single simple command" or reason =~ "not an allowed command"
      end
    end

    test "arbitrary programs and out-of-worktree reads are denied", %{ctx: ctx} do
      assert {:deny, r1} = gate(ctx, "Bash", %{command: "curl http://example.com"})
      assert r1 =~ "not an allowed command"

      assert {:deny, r2} = gate(ctx, "Bash", %{command: "cat /etc/passwd"})
      assert r2 =~ "inside the leased worktree"

      assert :allow == gate(ctx, "Bash", %{command: "ls"})
    end
  end

  test "an unreachable arbiter fails closed", %{ctx: ctx} do
    assert {:deny, reason} =
             gate(ctx, "Write", %{file_path: Path.join(ctx.worktree, "a.txt")}, [
               {"XAAS_MCP_URL", "http://127.0.0.1:1/internal-api/execution/mcp"}
             ])

    assert reason =~ "failing closed"
  end

  test "an unparseable hook payload fails closed", %{ctx: ctx} do
    {out, 0} =
      System.cmd("sh", ["-c", ~s(printf '%s' 'not json' | node "$GATE")],
        env: base_env(ctx, []),
        cd: ctx.worktree
      )

    assert %{"hookSpecificOutput" => %{"permissionDecision" => "deny"}} = Jason.decode!(out)
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp base_env(ctx, overrides) do
    defaults = [
      {"XAAS_WORKER", "1"},
      {"XAAS_LEASE_CWD", ctx.worktree},
      {"XAAS_MCP_URL", ctx.url},
      {"XAAS_MCP_TOKEN", System.fetch_env!("INTERNAL_API_TOKEN")},
      {"GATE", ctx.gate}
    ]

    Enum.reduce(overrides, defaults, fn {k, v}, acc -> List.keystore(acc, k, 0, {k, v}) end)
  end

  defp gate(ctx, tool, input, overrides \\ []) do
    payload = Jason.encode!(%{hookEventName: "PreToolUse", toolName: tool, toolInput: input})

    {out, 0} =
      System.cmd("sh", ["-c", ~s(printf '%s' "$PAYLOAD" | node "$GATE")],
        env: base_env(ctx, [{"PAYLOAD", payload} | overrides]),
        cd: ctx.worktree
      )

    case String.trim(out) do
      "" ->
        :allow

      json ->
        %{
          "hookSpecificOutput" => %{
            "permissionDecision" => "deny",
            "permissionDecisionReason" => reason
          }
        } = Jason.decode!(json)

        {:deny, reason}
    end
  end

  defp save_lease(ctx, cwd, lease) do
    {"saved\n", 0} =
      System.cmd("node", [ctx.lease_script, "save", Jason.encode!(lease), "--force"], cd: cwd)
  end

  defp make_plain_dir do
    dir = Path.join(System.tmp_dir!(), "xaas-gate-bare-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    canonical(dir)
  end

  defp make_git_worktree do
    dir = make_plain_dir()
    System.cmd("git", ["-C", dir, "init", "--quiet"], stderr_to_stdout: true)

    System.cmd("git", ["-C", dir, "commit", "--allow-empty", "-m", "init", "--quiet"],
      stderr_to_stdout: true,
      env: [
        {"GIT_AUTHOR_NAME", "test"},
        {"GIT_AUTHOR_EMAIL", "test@test"},
        {"GIT_COMMITTER_NAME", "test"},
        {"GIT_COMMITTER_EMAIL", "test@test"}
      ]
    )

    dir
  end

  defp canonical(dir) do
    {out, 0} = System.cmd("sh", ["-c", "cd \"$1\" && pwd -P", "sh", dir])
    String.trim(out)
  end
end
