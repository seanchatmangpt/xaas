defmodule Xaas.Ultracode.GateSurfaceTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Chicago-style qualification that the plugin's host-level PreToolUse gate
  (`priv/zcode_plugin/marketplace/xaas-fabric/scripts/xaas-gate.mjs`) takes its
  argv/tool policy from the runtime-surface JSON "gate" section
  (`priv/ultracode/runtime_surface.json`, or `XAAS_SURFACE_PATH`).

  The real script is run by a real `node` subprocess from its real location,
  fed the same hook JSON a ZCode PreToolUse hook receives on stdin
  (`tool_name` / `tool_input` / `cwd`). Lease state is a real lease file in a
  per-test `TMPDIR` state dir keyed exactly as the gate keys it (sha256 of the
  lease cwd), bound to a real tmp git repository. No arbiter is reachable
  (`XAAS_MCP_URL` points at a closed port): every decision asserted here is made
  locally, before any `admit_tool` HTTP call. Without `node` on PATH every test
  is a named skip.
  """

  @gate Path.expand("priv/zcode_plugin/marketplace/xaas-fabric/scripts/xaas-gate.mjs")
  @surface Path.expand("priv/ultracode/runtime_surface.json")
  @node System.find_executable("node")

  @moduletag skip: if(@node, do: false, else: "node binary not on PATH")

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "xaas-gate-surface-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    tmpdir = Path.join(root, "tmp")
    repo = Path.join(root, "repo")
    File.mkdir_p!(tmpdir)
    File.mkdir_p!(repo)
    on_exit(fn -> File.rm_rf(root) end)

    {_, 0} = System.cmd("git", ["init", "-q"], cd: repo, stderr_to_stdout: true)
    File.write!(Path.join(repo, "x"), "fixture\n")

    %{root: root, tmpdir: tmpdir, repo: repo}
  end

  defp save_lease(%{tmpdir: tmpdir, repo: repo}) do
    state_dir = Path.join(tmpdir, "xaas-fabric")
    File.mkdir_p!(state_dir)
    key = :crypto.hash(:sha256, repo) |> Base.encode16(case: :lower)

    lease = %{
      "lease_token" => "fixture-lease-token",
      "lease_expires_at" =>
        DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_iso8601(),
      "worktree" => repo
    }

    File.write!(Path.join(state_dir, key <> ".json"), Jason.encode!(lease))
  end

  # Runs the real gate. Returns :allow (empty stdout: deferred to the host) or
  # {:deny, reason}.
  defp gate(ctx, tool, input, extra_env \\ []) do
    stdin = Path.join(ctx.root, "stdin-#{System.unique_integer([:positive])}.json")
    File.write!(stdin, Jason.encode!(%{tool_name: tool, tool_input: input, cwd: ctx.repo}))

    env =
      [
        {"XAAS_WORKER", "1"},
        {"XAAS_LEASE_CWD", ctx.repo},
        {"TMPDIR", ctx.tmpdir},
        {"XAAS_LEASE_ID", nil},
        {"XAAS_SWEEP", nil},
        {"XAAS_ALLOW_SUBAGENTS", nil},
        {"XAAS_SURFACE_PATH", nil},
        {"XAAS_MCP_URL", "http://127.0.0.1:1/internal-api/execution/mcp"},
        {"XAAS_MCP_TOKEN", "fixture-mcp-token"},
        {"GITHUB_TOKEN", "fixture-gh"}
      ] ++ extra_env

    {out, 0} =
      System.cmd("sh", ["-c", ~s(exec "$0" "$1" < "$2"), @node, @gate, stdin],
        cd: ctx.repo,
        env: env,
        stderr_to_stdout: true
      )

    case String.trim(out) do
      "" ->
        :allow

      json ->
        %{"hookSpecificOutput" => %{"permissionDecision" => "deny"} = h} = Jason.decode!(json)
        {:deny, h["permissionDecisionReason"]}
    end
  end

  test "the policy file the gate reads by default is the runtime surface with deny_tools" do
    gate = @surface |> File.read!() |> Jason.decode!() |> Map.fetch!("gate")
    assert "WebFetch" in gate["deny_tools"]
    assert "WebSearch" in gate["deny_tools"]
    assert "cat" in gate["read_helpers"]
  end

  test "WebFetch is refused as a forbidden external semantic edge before any lease or admit_tool call",
       ctx do
    # No lease saved and an unreachable arbiter: a refusal that names the edge
    # (not "no live lease", not an admit_tool transport error) proves ordering.
    assert {:deny, reason} = gate(ctx, "WebFetch", %{url: "https://example.com"})
    assert reason =~ "FORBIDDEN_EXTERNAL_SEMANTIC_EDGE"
    assert reason =~ "UltraCode -> SA2A"
    assert reason =~ @surface

    save_lease(ctx)
    assert {:deny, leased} = gate(ctx, "WebSearch", %{query: "anything"})
    assert leased =~ "FORBIDDEN_EXTERNAL_SEMANTIC_EDGE"
    refute leased =~ "admit_tool"
  end

  test "git push is denied by the argv allowlist; git status in the leased repo is not", ctx do
    save_lease(ctx)

    assert {:deny, reason} = gate(ctx, "Bash", %{command: "git push origin main"})
    assert reason =~ "git push is not allowed"

    assert :allow == gate(ctx, "Bash", %{command: "git status"})
    assert :allow == gate(ctx, "Bash", %{command: "cat x"})
  end

  # Court bypass2 OBSERVED_ESCAPE 1: `sh -c 'git push origin main'` was
  # ALLOWED and landed on a scratch remote. Every shell form is now refused.
  test "shell interpreters are refused in every form (SHELL_IS_NOT_AUTHORITY)", ctx do
    save_lease(ctx)
    File.write!(Path.join(ctx.repo, "s.sh"), "git push origin main\n")

    for cmd <- [
          "sh -c 'git push origin main'",
          "bash -c 'curl -s https://example.com'",
          "bash ./s.sh",
          "sh s.sh",
          "zsh -c 'id'",
          "env git push origin main"
        ] do
      assert {:deny, reason} = gate(ctx, "Bash", %{command: cmd}), cmd
      assert reason =~ "SHELL_IS_NOT_AUTHORITY", cmd
    end
  end

  test "only the declared xaas-execution port tools pass; a lookalike is denied", ctx do
    assert :allow == gate(ctx, "mcp__xaas-execution__resolve_capability", %{})
    assert :allow == gate(ctx, "mcp__plugin_xaas-fabric_xaas-execution__surface", %{})

    assert {:deny, reason} = gate(ctx, "mcp__xaas-execution__not_a_real_tool", %{})
    assert reason =~ "not a declared xaas-execution port tool"
  end

  test "XAAS_SURFACE_PATH is actually consulted: read_helpers [] denies cat", ctx do
    save_lease(ctx)

    policy =
      @surface
      |> File.read!()
      |> Jason.decode!()
      |> put_in(["gate", "read_helpers"], [])

    path = Path.join(ctx.root, "surface.json")
    File.write!(path, Jason.encode!(policy))

    assert {:deny, reason} =
             gate(ctx, "Bash", %{command: "cat x"}, [{"XAAS_SURFACE_PATH", path}])

    assert reason =~ "cat is not an allowed command"
    assert :allow == gate(ctx, "Bash", %{command: "git status"}, [{"XAAS_SURFACE_PATH", path}])
  end

  test "an unreadable policy falls back to the built-in floor, never to something wider", ctx do
    save_lease(ctx)
    missing = [{"XAAS_SURFACE_PATH", Path.join(ctx.root, "absent.json")}]

    assert {:deny, reason} = gate(ctx, "WebFetch", %{url: "https://example.com"}, missing)
    assert reason =~ "FORBIDDEN_EXTERNAL_SEMANTIC_EDGE"
    assert reason =~ "policy builtin"

    assert {:deny, _} = gate(ctx, "Bash", %{command: "git push origin main"}, missing)
    assert :allow == gate(ctx, "Bash", %{command: "cat x"}, missing)
  end

  test "an interactive session (XAAS_WORKER unset) is a silent pass-through", ctx do
    assert :allow == gate(ctx, "WebFetch", %{url: "https://example.com"}, [{"XAAS_WORKER", nil}])
  end
end
