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
      # nil = unset before this test: DELETE, never put_env(key, nil) --
      # a literal nil poisons later `get_env(key, %{})` readers
      # (see target_suites_test's restore_env note).
      restore_env(:ultracode_verifier_suites, original.suites)
      restore_env(:ultracode_worktree_root, original.root)
      restore_env(:ultracode_ticket_dir, original.tickets)
      File.rm_rf(root)
    end)

    worktree = git_worktree(root)
    %{root: root, worktree: worktree, ctx: ctx(worktree)}
  end

  defp restore_env(key, nil), do: Application.delete_env(:xaas, key)
  defp restore_env(key, value), do: Application.put_env(:xaas, key, value)

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
  # Court receipt mode (IRI-keyed verdicts) -- see Xaas.Ultracode.CourtReceipt
  # for the ggen consumer contract. The suite output here is a scripted
  # replica of real `pytest -v` lines; the REAL eds-dod RED/GREEN witness on
  # a real eds worktree is out-of-test evidence (recorded in the wave
  # ticket), per this file's Chicago-style law on toolchain footprints.
  # ------------------------------------------------------------------

  @sj "https://ggen-igniter.dev/ontology/semantic-jira"
  @court_iri @sj <> "#exact-head-projection-court"
  @acc_iri @sj <> "#obs-275a1f5e4de7-acceptance-delta"
  @fal_iri @sj <> "#obs-275a1f5e4de7-falsifier-delta"

  @delta_test "tests/seed.py::test_delta"

  @git_env [
    {"GIT_AUTHOR_NAME", "t"},
    {"GIT_AUTHOR_EMAIL", "t@t"},
    {"GIT_COMMITTER_NAME", "t"},
    {"GIT_COMMITTER_EMAIL", "t@t"}
  ]

  defp court_map,
    do: %{
      "acceptance" => %{@acc_iri => %{"test" => @delta_test}},
      "falsifiers" => %{@fal_iri => %{"test" => @delta_test}},
      "courts" => [@court_iri]
    }

  defp verdict_script(marker) do
    ~s(echo #{marker}-MODE; if [ -f broken.flag ]; then echo "#{@delta_test} FAILED [100%]"; exit 1; else echo "#{@delta_test} PASSED [100%]"; fi)
  end

  defp put_receipt_suite do
    put_suite(
      "t",
      suite(
        [
          sh("probe", verdict_script("PLAIN"), %{
            receipt: true,
            receipt_argv: ["/bin/sh", "-c", verdict_script("VERBOSE")]
          })
        ],
        %{result_format: "pytest_v"}
      )
    )
  end

  test "court mode: the receipt argv runs and the receipt is IRI-keyed", %{ctx: ctx} do
    put_receipt_suite()

    assert {:ok, result} = Verifier.run("t", Map.put(ctx, :court_map, court_map()))
    assert result["status"] == "pass"

    [%{"output_tail" => tail}] = result["steps"]
    assert tail =~ "VERBOSE-MODE"

    receipt = result["court_receipt"]
    assert receipt["acceptance_results"][@acc_iri] == true
    assert receipt["falsifier_results"][@fal_iri] == "survived"

    court = receipt["court_results"][@court_iri]
    assert court["passed"] == true
    assert court["step_id"] == "probe"
    assert court["head"] == ctx.head

    assert receipt["binding"] == %{
             "suite" => "t",
             "step_id" => "probe",
             "head" => ctx.head,
             "argv_sha256" => result["argv_sha256"]
           }
  end

  test "court mode RED: a failing predicate fires the falsifier in the receipt", %{
    ctx: ctx,
    worktree: worktree
  } do
    put_receipt_suite()
    File.write!(Path.join(worktree, "broken.flag"), "x")
    {_, 0} = System.cmd("git", ["-C", worktree, "add", "broken.flag"])
    {_, 0} = System.cmd("git", ["-C", worktree, "commit", "-qm", "broken"], env: @git_env)
    red_ctx = %{ctx | head: git_head(worktree)}

    assert {:ok, result} = Verifier.run("t", Map.put(red_ctx, :court_map, court_map()))
    assert result["status"] == "fail"

    receipt = result["court_receipt"]
    assert receipt["acceptance_results"][@acc_iri] == false
    assert receipt["falsifier_results"][@fal_iri] == "failed"
    assert receipt["court_results"][@court_iri]["passed"] == false
  after
    System.cmd("git", ["-C", worktree, "reset", "-q", "--hard", "HEAD~1"], env: @git_env)
  end

  test "court mode: a mapped test with no observed verdict makes the run error", %{ctx: ctx} do
    put_suite(
      "t",
      suite(
        [sh("probe", ~s(echo "tests/other.py::test_other PASSED [100%]"), %{receipt: true})],
        %{result_format: "pytest_v"}
      )
    )

    assert {:ok, %{"status" => "error", "reason" => reason}} =
             Verifier.run("t", Map.put(ctx, :court_map, court_map()))

    assert reason =~ "court_receipt_refused"
    assert reason =~ "missing_verdict"
  end

  test "court mode: a court_map naming no receipt step in the suite is refused", %{ctx: ctx} do
    put_suite("t", suite([sh("probe", "true")]))

    assert {:ok, %{"status" => "error", "reason" => reason}} =
             Verifier.run("t", Map.put(ctx, :court_map, court_map()))

    assert reason =~ "receipt_step_undeclared"
  end

  test "court mode: a malformed court_map is a typed refusal", %{ctx: ctx} do
    put_receipt_suite()

    assert {:ok, %{"status" => "error", "reason" => reason}} =
             Verifier.run("t", Map.put(ctx, :court_map, %{"bogus" => %{}}))

    assert reason =~ "refused_court_map"
  end

  test "without a court_map the plain argv runs and no court_receipt is produced", %{ctx: ctx} do
    put_receipt_suite()

    assert {:ok, result} = Verifier.run("t", ctx)
    assert result["status"] == "pass"

    [%{"output_tail" => tail}] = result["steps"]
    assert tail =~ "PLAIN-MODE"
    refute Map.has_key?(result, "court_receipt")
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

  # run_uid law (dispatch_test): System.unique_integer restarts per BEAM while
  # $TMPDIR is machine-wide -- qualify per-run paths with wall clock too.
  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-verifier-test-#{label}-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
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
