defmodule Xaas.Ultracode.VerifierTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Chicago-style qualification of the fabric-executed verifier
  (`Xaas.Ultracode.Verifier`): real git worktrees under a real containment
  root, real subprocesses through `/usr/bin/env -i` and the perl process-group
  leader, real signals, real files. Nothing mocked or stubbed; every assertion
  is on the returned result map or on observable OS/filesystem state.
  """

  alias Xaas.Ultracode.Verifier

  setup do
    original = %{
      suites: Application.get_env(:xaas, :ultracode_verifier_suites),
      root: Application.get_env(:xaas, :ultracode_worktree_root),
      tickets: Application.get_env(:xaas, :ultracode_ticket_dir)
    }

    root = canonical(mktmp("root"))
    Application.put_env(:xaas, :ultracode_worktree_root, root)
    Application.put_env(:xaas, :ultracode_ticket_dir, Path.join(root, "tickets"))

    on_exit(fn ->
      Application.put_env(:xaas, :ultracode_verifier_suites, original.suites)
      Application.put_env(:xaas, :ultracode_worktree_root, original.root)
      Application.put_env(:xaas, :ultracode_ticket_dir, original.tickets)
      File.rm_rf(root)
    end)

    worktree = git_worktree(root)
    %{root: root, worktree: worktree, ctx: ctx(worktree)}
  end

  @env %{
    "PATH" => "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin",
    "GIT_AUTHOR_NAME" => "t",
    "GIT_AUTHOR_EMAIL" => "t@t",
    "GIT_COMMITTER_NAME" => "t",
    "GIT_COMMITTER_EMAIL" => "t@t"
  }

  defp suite(steps, extra \\ %{}) do
    Map.merge(%{env: @env, steps: steps}, extra)
  end

  defp put_suite(name, suite) do
    Application.put_env(:xaas, :ultracode_verifier_suites, %{name => suite})
    name
  end

  defp sh(id, script, extra \\ %{}) do
    Map.merge(%{id: id, argv: ["/bin/sh", "-c", script], timeout_ms: 10_000}, extra)
  end

  test "a passing suite is pass with per-step evidence and a stable argv digest", %{ctx: ctx} do
    put_suite("t", suite([sh("ok", "echo hello")]))

    assert {:ok, result} = Verifier.run("t", ctx)
    assert result["status"] == "pass"
    assert result["head"] == ctx.head

    assert [%{"id" => "ok", "exit" => 0, "status" => "pass", "output_tail" => tail}] =
             result["steps"]

    assert tail =~ "hello"
    assert result["argv_sha256"] =~ ~r/^[0-9a-f]{64}$/

    {:ok, again} = Verifier.run("t", ctx)
    assert again["argv_sha256"] == result["argv_sha256"]
  end

  test "a port that already closed has no os_pid: nil, never a crash" do
    port = Port.open({:spawn_executable, "/usr/bin/true"}, [:exit_status, :hide])
    ref = Port.monitor(port)
    assert_receive {^port, {:exit_status, 0}}, 5_000
    assert_receive {:DOWN, ^ref, :port, ^port, _reason}, 5_000

    assert Verifier.port_os_pid(port) == nil
  end

  @tag timeout: 180_000
  test "fast steps stay pass when the caller is descheduled past the step's lifetime (loaded scheduler)",
       %{ctx: ctx} do
    put_suite("t", suite([sh("quick", "true")]))

    burners =
      for _ <- 1..(System.schedulers_online() * 2) do
        spawn(fn -> burn() end)
      end

    try do
      results =
        1..160
        |> Task.async_stream(
          fn _ ->
            {:ok, result} = Verifier.run("t", Map.put(ctx, :epoch_id, Ecto.UUID.generate()))
            {result["status"], result["reason"], Enum.map(result["steps"], & &1["reason"])}
          end,
          max_concurrency: System.schedulers_online() * 4,
          timeout: 120_000
        )
        |> Enum.map(fn {:ok, value} -> value end)

      assert Enum.frequencies_by(results, &elem(&1, 0)) == %{"pass" => 160},
             "non-pass verdicts under load: " <>
               inspect(Enum.reject(results, &(elem(&1, 0) == "pass")) |> Enum.take(3))
    after
      Enum.each(burners, &Process.exit(&1, :kill))
    end
  end

  defp burn do
    :erlang.phash2(:erlang.unique_integer())
    burn()
  end

  test "a failing step is fail and later steps do not run", %{ctx: ctx} do
    put_suite("t", suite([sh("bad", "echo boom; exit 1"), sh("never", "echo unreachable")]))

    assert {:ok, result} = Verifier.run("t", ctx)
    assert result["status"] == "fail"
    assert [%{"id" => "bad", "exit" => 1, "status" => "fail"}] = result["steps"]
    assert result["reason"] =~ "step bad: fail"
  end

  test "an infra exit code is error, not fail", %{ctx: ctx} do
    put_suite("t", suite([sh("infra", "exit 2", %{infra_exit_codes: [2]})]))

    assert {:ok, %{"status" => "error", "steps" => [%{"status" => "error", "exit" => 2}]}} =
             Verifier.run("t", ctx)
  end

  test "a timeout is reported and the whole process group, grandchildren included, is killed",
       %{ctx: ctx} do
    pidfile = Path.join(mktmp("pid"), "grandchild.pid")

    put_suite(
      "t",
      suite(
        [sh("hang", ~s(sleep 300 & echo $! > "$PIDFILE"; wait), %{timeout_ms: 500})],
        %{env: Map.put(@env, "PIDFILE", pidfile)}
      )
    )

    assert {:ok, result} = Verifier.run("t", ctx)
    assert result["status"] == "timeout"
    assert [%{"status" => "timeout", "reason" => "step_timeout_500ms"}] = result["steps"]

    pid = pidfile |> File.read!() |> String.trim()
    assert eventually_dead?(pid), "grandchild #{pid} outlived the timeout"
  end

  test "the BEAM environment never reaches the child, only the suite allowlist does", %{ctx: ctx} do
    System.put_env("XAAS_TEST_SECRET", "s3cr3t-value")
    on_exit(fn -> System.delete_env("XAAS_TEST_SECRET") end)

    put_suite("t", suite([sh("env", ~s(echo "secret=[$XAAS_TEST_SECRET] path=[$PATH]"))]))

    assert {:ok, %{"steps" => [%{"output_tail" => tail}]}} = Verifier.run("t", ctx)
    assert tail =~ "secret=[]"
    assert tail =~ "path=[/usr/bin:/bin"
    refute tail =~ "s3cr3t-value"
  end

  test "HOME and TMPDIR point at a per-run temp dir that is removed afterwards", %{ctx: ctx} do
    put_suite("t", suite([sh("home", ~s(echo "$HOME"; echo x > "$HOME/marker"))]))

    assert {:ok, %{"status" => "pass", "steps" => [%{"output_tail" => tail}]}} =
             Verifier.run("t", ctx)

    home = tail |> String.trim() |> String.split("\n") |> hd()
    assert home =~ "xaas-verifier-"
    refute File.exists?(home)
  end

  test "placeholders are substituted only as whole argv elements", %{ctx: ctx} do
    put_suite(
      "t",
      suite([
        %{
          id: "sub",
          timeout_ms: 10_000,
          argv: ["/bin/sh", "-c", ~S(echo "$0|$1|$2"), "{head}", "{executor}", "{run_id}"]
        }
      ])
    )

    assert {:ok, %{"status" => "pass", "steps" => [%{"output_tail" => tail}]}} =
             Verifier.run("t", ctx)

    assert String.trim(tail) == "#{ctx.head}|worker-9|#{ctx.run_id}"

    put_suite("t", suite([%{id: "emb", argv: ["/bin/echo", "x{head}"], timeout_ms: 1000}]))

    assert {:ok,
            %{"status" => "error", "steps" => [%{"reason" => "embedded_placeholder_refused"}]}} =
             Verifier.run("t", ctx)
  end

  test "a receipt-flagged step's last JSON line is surfaced as court_receipt", %{ctx: ctx} do
    put_suite(
      "t",
      suite([
        sh("court", ~s(echo diagnostics; echo '{"standing":"ALIVE","gates":3}'), %{receipt: true})
      ])
    )

    assert {:ok, %{"status" => "pass", "court_receipt" => %{"standing" => "ALIVE", "gates" => 3}}} =
             Verifier.run("t", ctx)
  end

  test "output is bounded to the last max_output_bytes", %{ctx: ctx} do
    put_suite(
      "t",
      suite([sh("loud", "yes abcdefgh | head -c 200000; echo END")], %{max_output_bytes: 1024})
    )

    assert {:ok, %{"steps" => [%{"output_tail" => tail}]}} = Verifier.run("t", ctx)
    assert byte_size(tail) <= 1024
    assert tail =~ "END"
  end

  describe "repository state" do
    test "uncommitted worker changes are a fail, not a pass", %{ctx: ctx, worktree: worktree} do
      File.write!(Path.join(worktree, "left-behind.txt"), "x")
      put_suite("t", suite([sh("ok", "true")]))

      assert {:ok, %{"status" => "fail", "reason" => reason}} = Verifier.run("t", ctx)
      assert reason =~ "worker_left_uncommitted_changes"
      assert reason =~ "left-behind.txt"
    end

    test "a suite that dirties the tree is an error", %{ctx: ctx} do
      put_suite("t", suite([sh("dirty", "echo x > stray.txt")]))

      assert {:ok, %{"status" => "error", "reason" => "suite_dirtied_worktree"}} =
               Verifier.run("t", ctx)
    end

    test "a suite that moves HEAD is an error", %{ctx: ctx} do
      put_suite("t", suite([sh("commit", "git commit --allow-empty -m moved -q")]))

      assert {:ok, %{"status" => "error", "reason" => "head_changed_after_suite"}} =
               Verifier.run("t", ctx)
    end

    test "a claimed head that is not the worktree HEAD is refused before anything runs", %{
      ctx: ctx
    } do
      put_suite("t", suite([sh("ok", "true")]))
      wrong = %{ctx | head: String.duplicate("a", 40)}

      assert {:ok, %{"status" => "error", "reason" => "head_changed_before_suite"} = result} =
               Verifier.run("t", wrong)

      refute Map.has_key?(result, "steps")
    end
  end

  describe "containment" do
    test "no worktree, an unconfigured root, and unknown suites all fail closed", %{ctx: ctx} do
      put_suite("t", suite([sh("ok", "true")]))

      assert {:ok, %{"status" => "error", "reason" => "no_worktree"}} =
               Verifier.run("t", %{ctx | worktree: nil})

      Application.put_env(:xaas, :ultracode_worktree_root, nil)

      assert {:ok, %{"status" => "error", "reason" => "worktree_root_unconfigured"}} =
               Verifier.run("t", ctx)

      assert {:ok, %{"status" => "error", "reason" => "unknown_suite"}} =
               Verifier.run("nope", ctx)
    end

    test "a worktree outside the root is refused and the suite never runs", %{ctx: ctx} do
      marker = Path.join(mktmp("marker"), "ran")

      put_suite(
        "t",
        suite([sh("touch", ~s(touch "$MARKER"))], %{env: Map.put(@env, "MARKER", marker)})
      )

      outside = git_worktree(canonical(mktmp("elsewhere")))
      outside_ctx = %{ctx | worktree: outside, head: git_head(outside)}

      assert {:ok, %{"status" => "error", "reason" => "worktree_outside_root"}} =
               Verifier.run("t", outside_ctx)

      refute File.exists?(marker)
    end

    test "a symlink under the root that points outside it is refused", %{root: root, ctx: ctx} do
      outside = git_worktree(canonical(mktmp("elsewhere")))
      link = Path.join(root, "sneaky")
      File.ln_s!(outside, link)
      put_suite("t", suite([sh("ok", "true")]))

      assert {:ok, %{"status" => "error", "reason" => "worktree_outside_root"}} =
               Verifier.run("t", %{ctx | worktree: link, head: git_head(outside)})
    end

    test "a subdirectory of a repository is not a repository root", %{
      worktree: worktree,
      ctx: ctx
    } do
      sub = Path.join(worktree, "nested")
      File.mkdir_p!(sub)
      put_suite("t", suite([sh("ok", "true")]))

      assert {:ok, %{"status" => "error", "reason" => "worktree_is_not_a_repository_root"}} =
               Verifier.run("t", %{ctx | worktree: sub})
    end
  end

  test "a second verification of the same epoch while one is running is refused", %{ctx: ctx} do
    put_suite("t", suite([sh("slow", "sleep 2")]))

    first = Task.async(fn -> Verifier.run("t", ctx) end)
    Process.sleep(400)

    assert {:ok, %{"status" => "error", "reason" => "verification_in_progress"}} =
             Verifier.run("t", ctx)

    assert {:ok, %{"status" => "pass"}} = Task.await(first, 15_000)
  end

  test "registered?/1 and suite_names/0 read the operator registry only" do
    put_suite("known-suite", suite([sh("ok", "true")]))

    assert Verifier.registered?("known-suite")
    refute Verifier.registered?("unknown-suite")
    refute Verifier.registered?(nil)
    refute Verifier.registered?(:known_suite)
    assert Verifier.suite_names() == ["known-suite"]
  end

  # ------------------------------------------------------------------

  defp ctx(worktree) do
    %{
      worktree: worktree,
      head: git_head(worktree),
      run_id: Ecto.UUID.generate(),
      epoch_id: Ecto.UUID.generate(),
      executor: "worker-9"
    }
  end

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-verifier-test-#{label}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp canonical(path) do
    {out, 0} = System.cmd("sh", ["-c", ~s(cd "$1" && pwd -P), "sh", path])
    String.trim(out)
  end

  defp git_worktree(parent) do
    dir = Path.join(parent, "wt-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    {_, 0} = System.cmd("git", ["-C", dir, "init", "--quiet"], stderr_to_stdout: true)

    {_, 0} =
      System.cmd("git", ["-C", dir, "commit", "--allow-empty", "-m", "init", "--quiet"],
        stderr_to_stdout: true,
        env: [
          {"GIT_AUTHOR_NAME", "t"},
          {"GIT_AUTHOR_EMAIL", "t@t"},
          {"GIT_COMMITTER_NAME", "t"},
          {"GIT_COMMITTER_EMAIL", "t@t"}
        ]
      )

    canonical(dir)
  end

  defp git_head(worktree) do
    {out, 0} = System.cmd("git", ["-C", worktree, "rev-parse", "HEAD"])
    String.trim(out)
  end

  defp eventually_dead?(pid, attempts \\ 40) do
    cond do
      match?({_, code} when code != 0, System.cmd("kill", ["-0", pid], stderr_to_stdout: true)) ->
        true

      attempts == 0 ->
        false

      true ->
        Process.sleep(100)
        eventually_dead?(pid, attempts - 1)
    end
  end
end
