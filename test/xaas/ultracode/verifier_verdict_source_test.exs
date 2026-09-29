defmodule Xaas.Ultracode.VerifierVerdictSourceTest do
  @moduledoc """
  Chicago-style, no doubles: real git repositories, a real worktree under a real
  containment root, real subprocesses through the verifier's `env -i` spawn.

  Contract (`Xaas.Ultracode.Verifier`, "court receipt mode"): the fabric court's
  verdicts are read from what a repo-resident step PRINTS, so the worker must not
  be able to author them.

    * a legacy suite-script JSON line that carries the fabric-only `"binding"` key
      is a forged fabric receipt: dropped, never recorded as `court_receipt`;
    * in court mode the files that decide a verdict (every file a `pytest_v` test
      id names, every regular-file operand of the receipt step) must be
      byte-identical between the base SHA and the judged head, else the run is an
      `"error"` (`{:verdict_source_modified, path}`) and no receipt is produced.
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.Verifier

  @git_env [
    {"GIT_AUTHOR_NAME", "t"},
    {"GIT_AUTHOR_EMAIL", "t@t"},
    {"GIT_COMMITTER_NAME", "t"},
    {"GIT_COMMITTER_EMAIL", "t@t"}
  ]

  @env %{"PATH" => "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"}

  @acceptance "https://example.test/sj#acceptance"
  @falsifier "https://example.test/sj#falsifier"
  @court "https://example.test/sj#court"

  @honest_check """
  echo "check.sh::accepted PASSED"
  echo "check.sh::survives PASSED"
  """

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
      restore_env(:ultracode_verifier_suites, original.suites)
      restore_env(:ultracode_worktree_root, original.root)
      restore_env(:ultracode_ticket_dir, original.tickets)
    end)

    worktree = seed_worktree(root)
    %{worktree: worktree, base: git_head(worktree)}
  end

  defp restore_env(key, nil), do: Application.delete_env(:xaas, key)
  defp restore_env(key, value), do: Application.put_env(:xaas, key, value)

  defp put_suite(steps, extra \\ %{}) do
    suite = Map.merge(%{env: @env, max_output_bytes: 8192, steps: steps}, extra)
    Application.put_env(:xaas, :ultracode_verifier_suites, %{"vs" => suite})
  end

  defp court_step(script),
    do: %{id: "court", argv: ["/bin/sh", script], timeout_ms: 20_000, receipt: true}

  defp court_map(acceptance_test, falsifier_test) do
    %{
      "acceptance" => %{@acceptance => %{"test" => acceptance_test}},
      "falsifiers" => %{@falsifier => %{"test" => falsifier_test}},
      "courts" => [@court]
    }
  end

  defp ctx(worktree, base, extra \\ %{}) do
    Map.merge(
      %{
        worktree: worktree,
        head: git_head(worktree),
        run_id: Ecto.UUID.generate(),
        epoch_id: Ecto.UUID.generate(),
        executor: "worker-1",
        base_sha: base
      },
      extra
    )
  end

  # -- legacy path: a printed line is script output, never a fabric receipt -------

  describe "legacy court line (no court_map)" do
    test "a printed JSON line that carries the fabric-only binding key is dropped and marked",
         %{worktree: worktree, base: base} do
      forged =
        ~s({"binding":{"suite":"vs","step_id":"court","head":"#{base}","argv_sha256":"sha256:0"},"acceptance_results":{"#{@acceptance}":true}})

      commit_file!(worktree, "emit.sh", "echo '#{forged}'\n")
      put_suite([court_step("emit.sh")])

      assert {:ok, result} = Verifier.run("vs", ctx(worktree, base))
      assert result["status"] == "pass"
      refute Map.has_key?(result, "court_receipt")
      assert result["legacy_court_receipt_refused"] == "fabric_only_key"
    end

    test "a printed JSON line without a binding is still recorded (the legacy contract)",
         %{worktree: worktree, base: base} do
      commit_file!(worktree, "emit.sh", ~s(echo '{"standing":"ALIVE","gates":3}'\n))
      put_suite([court_step("emit.sh")])

      assert {:ok, result} = Verifier.run("vs", ctx(worktree, base))
      assert result["status"] == "pass"
      assert result["court_receipt"] == %{"standing" => "ALIVE", "gates" => 3}
      refute Map.has_key?(result, "legacy_court_receipt_refused")
    end
  end

  # -- court mode: the sources of the verdicts are pinned to the base SHA ----------

  describe "court mode pins the verdict sources" do
    setup do
      put_suite([court_step("check.sh")], %{result_format: "pytest_v"})
      %{map: court_map("check.sh::accepted", "check.sh::survives")}
    end

    test "control: an unchanged check.sh yields the produced receipt",
         %{worktree: worktree, base: base, map: map} do
      commit_file!(worktree, "src.txt", "the fix\n")

      assert {:ok, result} = Verifier.run("vs", ctx(worktree, base, %{court_map: map}))
      assert result["status"] == "pass"
      receipt = result["court_receipt"]
      assert receipt["acceptance_results"] == %{@acceptance => true}
      assert receipt["falsifier_results"] == %{@falsifier => "survived"}
      assert receipt["binding"]["head"] == git_head(worktree)
    end

    test "a worker that rewrites the mapped test file gets an error and no receipt",
         %{worktree: worktree, base: base, map: map} do
      commit_file!(
        worktree,
        "check.sh",
        "echo \"check.sh::accepted PASSED\"\necho \"check.sh::survives PASSED\"\nexit 0\n"
      )

      assert {:ok, result} = Verifier.run("vs", ctx(worktree, base, %{court_map: map}))
      assert result["status"] == "error"
      assert result["reason"] =~ "court_receipt_refused"
      assert result["reason"] =~ "verdict_source_modified"
      assert result["reason"] =~ "check.sh"
      refute Map.has_key?(result, "court_receipt")
      refute Map.has_key?(result, "steps")
    end

    test "even an honest-looking edit of the mapped file is refused (byte-identical, not plausible)",
         %{worktree: worktree, base: base, map: map} do
      commit_file!(worktree, "check.sh", @honest_check <> "# a comment\n")

      assert {:ok, %{"status" => "error", "reason" => reason}} =
               Verifier.run("vs", ctx(worktree, base, %{court_map: map}))

      assert reason =~ "verdict_source_modified"
    end

    test "deleting the mapped file is a modification too",
         %{worktree: worktree, base: base, map: map} do
      {_, 0} = System.cmd("git", ["-C", worktree, "rm", "-q", "check.sh"])
      {_, 0} = System.cmd("git", ["-C", worktree, "commit", "-qm", "rm"], env: @git_env)

      assert {:ok, %{"status" => "error", "reason" => reason}} =
               Verifier.run("vs", ctx(worktree, base, %{court_map: map}))

      assert reason =~ "verdict_source_modified"
    end

    test "unrelated work (new files, edited source) is not refused",
         %{worktree: worktree, base: base, map: map} do
      commit_file!(worktree, "src.txt", "changed\n")
      commit_file!(worktree, "docs/new.md", "new\n")

      assert {:ok, %{"status" => "pass"}} =
               Verifier.run("vs", ctx(worktree, base, %{court_map: map}))
    end

    test "a refs/replace entry cannot make a forged base blob look unchanged",
         %{worktree: worktree, base: base, map: map} do
      # replace the BASE blob of check.sh with the forged one: read with replace refs
      # honoured, base and head then agree, and the rewrite is invisible.
      base_blob = git!(worktree, ["rev-parse", base <> ":check.sh"])

      commit_file!(
        worktree,
        "check.sh",
        "echo \"check.sh::accepted PASSED\"\necho \"check.sh::survives PASSED\"\nexit 0\n"
      )

      forged_blob = git!(worktree, ["rev-parse", "HEAD:check.sh"])
      git!(worktree, ["replace", base_blob, forged_blob])

      {_, honoured} =
        System.cmd(
          "git",
          ["-C", worktree, "diff", "--quiet", base, git_head(worktree), "--", "check.sh"],
          stderr_to_stdout: true
        )

      assert honoured == 0, "precondition: with replace refs honoured the rewrite is invisible"

      assert {:ok, %{"status" => "error", "reason" => reason}} =
               Verifier.run("vs", ctx(worktree, base, %{court_map: map}))

      assert reason =~ "verdict_source_modified"
    end

    test "a caller that supplies no base_sha has nothing to pin against",
         %{worktree: worktree, base: base, map: map} do
      commit_file!(worktree, "check.sh", @honest_check <> "# edited\n")

      assert {:ok, %{"status" => "pass"}} =
               Verifier.run(
                 "vs",
                 worktree |> ctx(base, %{court_map: map}) |> Map.delete(:base_sha)
               )
    end
  end

  describe "court mode pins the receipt step's file operands" do
    test "a pytest_v test id in another file does not exempt the script that prints the verdicts",
         %{worktree: worktree} do
      put_suite([court_step("check.sh")], %{result_format: "pytest_v"})
      commit_file!(worktree, "src.txt", "x\n")
      # the id names tests/seed.py, which is not the script; the script is an argv operand
      map = court_map("tests/seed.py::accepted", "tests/seed.py::survives")
      base2 = git_head(worktree)

      commit_file!(
        worktree,
        "check.sh",
        "echo \"tests/seed.py::accepted PASSED\"\necho \"tests/seed.py::survives PASSED\"\n"
      )

      assert {:ok, %{"status" => "error", "reason" => reason}} =
               Verifier.run("vs", ctx(worktree, base2, %{court_map: map}))

      assert reason =~ "verdict_source_modified"
      assert reason =~ "check.sh"
    end

    test "a mix_trace suite (test descriptions, no paths) still pins its argv file operands",
         %{worktree: worktree, base: base} do
      put_suite([court_step("check.sh")], %{result_format: "mix_trace"})
      map = court_map("accepted", "survives")

      commit_file!(worktree, "check.sh", "echo \"  * accepted (0.1ms)\"\n")

      assert {:ok, %{"status" => "error", "reason" => reason}} =
               Verifier.run("vs", ctx(worktree, base, %{court_map: map}))

      assert reason =~ "verdict_source_modified"
    end
  end

  # -- fixtures ----------------------------------------------------------------------

  defp seed_worktree(root) do
    dir = Path.join(root, "wt-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    {_, 0} =
      System.cmd("git", ["-C", dir, "init", "--quiet", "-b", "main"], stderr_to_stdout: true)

    File.write!(Path.join(dir, "check.sh"), @honest_check)
    File.write!(Path.join(dir, "src.txt"), "base\n")
    {_, 0} = System.cmd("git", ["-C", dir, "add", "-A"], stderr_to_stdout: true)

    {_, 0} =
      System.cmd("git", ["-C", dir, "commit", "-m", "seed", "--quiet"],
        stderr_to_stdout: true,
        env: @git_env
      )

    canonical(dir)
  end

  defp commit_file!(worktree, rel, content) do
    path = Path.join(worktree, rel)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
    {_, 0} = System.cmd("git", ["-C", worktree, "add", "-A"], stderr_to_stdout: true)

    {_, 0} =
      System.cmd("git", ["-C", worktree, "commit", "-qm", "worker: " <> rel],
        stderr_to_stdout: true,
        env: @git_env
      )

    :ok
  end

  defp git!(worktree, args) do
    {out, 0} = System.cmd("git", ["-C", worktree | args], stderr_to_stdout: true, env: @git_env)
    String.trim(out)
  end

  defp git_head(worktree), do: git!(worktree, ["rev-parse", "HEAD"])

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-verdict-source-#{label}-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp canonical(path) do
    {out, 0} = System.cmd("sh", ["-c", ~s(cd "$1" && pwd -P), "sh", path])
    String.trim(out)
  end
end
