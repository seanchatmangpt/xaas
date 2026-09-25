defmodule Xaas.Ultracode.TargetSuitesTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Qualification of the non-APS target suites (`Xaas.Ultracode.TargetSuites`).

  Two layers, both Chicago-style (no mocks, real subprocesses, real git):

    * the registration-time admission gate: the code-declared suites must pass
      `validate/1`, and mutations of them -- a bad command (empty, non-binary,
      or placeholder-embedded argv element) or a bad timeout (missing, zero,
      negative, over the cap) -- must be REFUSED;
    * the runtime opt-in wiring: the `:ultracode_target_suites` module value is
      resolved by `Verifier` only when it names a loadable module;
    * a hermetic RED -> restore -> GREEN witness through the real
      `Verifier.run/2` (real git worktree, real process-group-spawned
      script): the same suite that passes at a green head must fail after a
      breaking commit and pass again after the revert, proving the suite
      tracks the head under test rather than the machine.

  The machine-specific RED/GREEN witnesses for the REAL suites (`nounverb-dod`
  against a mutated `ex_noun_verb_cli` worktree, `eds-dod` against a mutated
  `eds` worktree) are out-of-test evidence: they compile and test real target
  repos with a pinned toolchain and a dependency fetch, which is exactly the
  network/toolchain footprint tests here must not have. Commands and exits are
  recorded in the wave ticket.
  """

  alias Xaas.Ultracode.{TargetSuites, Verifier}

  setup do
    original = %{
      suites: Application.get_env(:xaas, :ultracode_verifier_suites),
      targets: Application.get_env(:xaas, :ultracode_target_suites),
      root: Application.get_env(:xaas, :ultracode_worktree_root)
    }

    root = canonical(mktmp("root"))
    Application.put_env(:xaas, :ultracode_worktree_root, root)

    on_exit(fn ->
      Application.put_env(:xaas, :ultracode_verifier_suites, original.suites)
      Application.put_env(:xaas, :ultracode_target_suites, original.targets)
      Application.put_env(:xaas, :ultracode_worktree_root, original.root)
      File.rm_rf(root)
    end)

    %{root: root}
  end

  test "the code-declared target suites pass the registration admission gate" do
    devs = TargetSuites.devs()

    assert MapSet.new(Map.keys(devs)) == MapSet.new(["eds-dod", "nounverb-dod", "spr-dod"])
    assert TargetSuites.validate(devs) == :ok
  end

  test "a bad command is refused: empty argv, non-binary element, embedded placeholder" do
    embedded =
      put_in(TargetSuites.devs(), ["eds-dod", Access.key!(:steps), Access.at(0), :argv], [
        "python3",
        "-m",
        "pytest {worktree}"
      ])

    assert {:error, problems} = TargetSuites.validate(embedded)
    assert Enum.any?(problems, &(&1 =~ "embedded placeholder"))

    non_binary =
      put_in(TargetSuites.devs(), ["eds-dod", Access.key!(:steps), Access.at(0), :argv], [
        "python3",
        3
      ])

    assert {:error, problems} = TargetSuites.validate(non_binary)
    assert Enum.any?(problems, &(&1 =~ "binaries"))

    assert {:error, problems} =
             TargetSuites.validate(%{
               "empty-argv" => %{steps: [%{id: "x", argv: [], timeout_ms: 100}]}
             })

    assert problems == ["suite \"empty-argv\": x: argv must be a non-empty list of elements"]

    assert {:error, problems} =
             TargetSuites.validate(%{"no-steps" => %{steps: []}})

    assert problems == ["suite \"no-steps\": steps must be a non-empty list"]
  end

  test "a bad timeout is refused: missing, zero, negative, non-integer, over the cap" do
    base = %{"t" => hd(Map.values(TargetSuites.devs()))}

    for bad <- [0, -1, "300000", 3_600_001] do
      mutated =
        put_in(base, ["t", Access.key!(:steps), Access.at(0), :timeout_ms], bad)

      assert {:error, problems} = TargetSuites.validate(mutated)
      assert Enum.any?(problems, &(&1 =~ "bad timeout_ms" or &1 =~ "timeout_ms is required"))
    end

    missing =
      update_in(base, ["t", Access.key!(:steps)], fn [step] ->
        [Map.delete(step, :timeout_ms)]
      end)

    assert {:error, problems} = TargetSuites.validate(missing)
    assert Enum.any?(problems, &(&1 =~ "timeout_ms is required"))
  end

  test "the runtime opt-in resolves the module value, and only a loadable one" do
    Application.put_env(:xaas, :ultracode_target_suites, TargetSuites)
    assert Verifier.registered?("eds-dod")
    assert Verifier.registered?("nounverb-dod")
    assert "eds-dod" in Verifier.suite_names()

    # A module that does not exist fails closed to the configured registry.
    Application.put_env(:xaas, :ultracode_target_suites, NoSuch.TargetSuites)
    refute Verifier.registered?("eds-dod")

    # Unset: registry unchanged (the fail-closed default everywhere else).
    Application.delete_env(:xaas, :ultracode_target_suites)
    refute Verifier.registered?("eds-dod")
  end

  test "hermetic RED/restore/GREEN witness: the suite judges the head, not the machine", %{
    root: root
  } do
    worktree = scripted_repo(root)
    green_head = git_head(worktree)

    suite = %{
      env: %{
        "PATH" => "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin",
        "GIT_AUTHOR_NAME" => "t",
        "GIT_AUTHOR_EMAIL" => "t@t",
        "GIT_COMMITTER_NAME" => "t",
        "GIT_COMMITTER_EMAIL" => "t@t"
      },
      max_output_bytes: 65_536,
      toolchain: [["git", "--version"]],
      steps: [%{id: "dod", timeout_ms: 10_000, argv: ["/bin/sh", "dod.sh"]}]
    }

    Application.put_env(:xaas, :ultracode_verifier_suites, %{"scripted-dod" => suite})
    ctx = %{worktree: worktree, head: green_head, run_id: "r1", epoch_id: "e1"}

    assert {:ok, %{"status" => "pass", "steps" => [%{"id" => "dod", "exit" => 0}]}} =
             Verifier.run("scripted-dod", ctx)

    # RED: a committed breaking change at a new head must be judged fail.
    File.write!(Path.join(worktree, "dod.sh"), "#!/bin/sh\nexit 3\n")
    red_head = git_commit_all(worktree, "break dod")

    assert {:ok,
            %{"status" => "fail", "steps" => [%{"id" => "dod", "exit" => 3, "status" => "fail"}]}} =
             Verifier.run("scripted-dod", %{ctx | head: red_head})

    # Restore the fix: the new head passes again (the suite judged the head,
    # not the machine).
    File.write!(Path.join(worktree, "dod.sh"), "#!/bin/sh\nexit 0\n")
    fixed_head = git_commit_all(worktree, "restore dod")

    assert {:ok, %{"status" => "pass", "steps" => [%{"exit" => 0}]}} =
             Verifier.run("scripted-dod", %{ctx | head: fixed_head})

    assert red_head != green_head and fixed_head != red_head
  end

  # ------------------------------------------------------------------

  defp scripted_repo(root) do
    dir = Path.join(root, "wt-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    {_, 0} = System.cmd("git", ["-C", dir, "init", "--quiet"], stderr_to_stdout: true)
    File.write!(Path.join(dir, "dod.sh"), "#!/bin/sh\nexit 0\n")
    git_commit_all(dir, "green dod")
    canonical(dir)
  end

  defp git_commit_all(dir, message) do
    {_, 0} = System.cmd("git", ["-C", dir, "add", "-A"], stderr_to_stdout: true)

    {_, 0} =
      System.cmd("git", ["-C", dir, "commit", "-q", "-m", message],
        stderr_to_stdout: true,
        env: [
          {"GIT_AUTHOR_NAME", "t"},
          {"GIT_AUTHOR_EMAIL", "t@t"},
          {"GIT_COMMITTER_NAME", "t"},
          {"GIT_COMMITTER_EMAIL", "t@t"}
        ]
      )

    git_head(dir)
  end

  defp git_head(dir) do
    {out, 0} = System.cmd("git", ["-C", dir, "rev-parse", "HEAD"])
    String.trim(out)
  end

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-target-suites-test-#{label}-#{System.unique_integer([:positive])}"
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
