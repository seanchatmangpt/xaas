defmodule Mix.Tasks.Xaas.VerifyAndCommitTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Exercises the real subprocess exit code of `mix xaas.verify_and_commit`.

  This must invoke the task via `System.cmd("mix", [...])` in a real OS
  subprocess, not `Mix.Task.run/2` in-process: the task calls `System.halt/1`
  on failure, which would kill this very test VM if run in-process. Only a
  subprocess boundary lets us observe the real, documented exit_status
  `System.cmd/3` returns without raising.

  ## Why a copied-task fixture project, not a bare tmp dir

  `mix xaas.verify_and_commit` is a Mix task defined in *this* project's
  `lib/mix/tasks/xaas.verify_and_commit.ex`. Mix only loads task modules from
  the project it is invoked inside, so a bare fixture directory with no copy
  of that file would get `** (Mix) The task "xaas.verify_and_commit" could
  not be found` -- not the exit-code behavior under test. Each fixture below
  is therefore a real, minimal, self-contained Mix project (with a real
  `mix.exs`, real `.ex`/`.exs` source, a real git repo) that includes a real
  copy of the actual task source file, so `mix xaas.verify_and_commit` in the
  fixture subprocess runs the exact same code as `lib/mix/tasks/
  xaas.verify_and_commit.ex` in this repo. Nothing here is mocked or stubbed
  out of the task itself.

  ## Why a stub `mix ecto.migrate` task in the fixture

  The real task's "migrate" stage shells out to `mix ecto.migrate`. A bare
  fixture project has no Ecto dependency, so that stage would fail with
  `** (Mix) The task "ecto.migrate" could not be found` before ever reaching
  the mock-grep/commit stages this suite needs to exercise. Each fixture
  therefore ships a real, local `Mix.Tasks.Ecto.Migrate` task (`lib/mix/
  tasks/ecto.migrate.ex`) that does nothing but return `:ok` -- a real Mix
  task, invoked as a real subprocess, standing in for a real migration
  runner the same way a fixture repo's Ecto config would stand in for a real
  database in Chicago-style testing. It is not a mock of the `xaas.
  verify_and_commit` task under test; it is a real (if trivial) collaborator
  the fixture project owns.
  """

  @task_source Path.expand("../../../lib/mix/tasks/xaas.verify_and_commit.ex", __DIR__)

  # ---- fixture builder -----------------------------------------------

  defp unique_tmp(prefix) do
    Path.join(System.tmp_dir!(), "#{prefix}_#{System.unique_integer([:positive])}")
  end

  defp mix_exs(app_name) do
    """
    defmodule #{app_name}.MixProject do
      use Mix.Project

      def project do
        [
          app: :#{String.downcase(app_name)},
          version: "0.1.0",
          elixir: "~> 1.14",
          elixirc_paths: ["lib", "task_src"],
          start_permanent: Mix.env() == :prod,
          deps: []
        ]
      end

      def application do
        [extra_applications: [:logger]]
      end
    end
    """
  end

  defp ecto_migrate_stub do
    """
    defmodule Mix.Tasks.Ecto.Migrate do
      use Mix.Task
      @shortdoc "fixture stub: real no-op migrate task, not a mock of the task under test"
      @impl Mix.Task
      def run(_args), do: :ok
    end
    """
  end

  # A real Mix task standing in for Ecto's real "already up" outcome: real
  # Ecto migrations print "Migrations already up" and exit 0 (not an error)
  # when there is nothing pending. This is a real, if trivial, collaborator
  # exercising that exact exit-0-with-that-message contract, not a mock of
  # the task under test.
  defp ecto_migrate_already_up_stub do
    """
    defmodule Mix.Tasks.Ecto.Migrate do
      use Mix.Task
      @shortdoc "fixture stub: mirrors ecto.migrate's real already-up-is-not-an-error contract"
      @impl Mix.Task
      def run(_args) do
        Mix.shell().info("Migrations already up")
        :ok
      end
    end
    """
  end

  defp test_helper do
    "ExUnit.start()\n"
  end

  defp passing_test do
    """
    defmodule FixtureTest do
      use ExUnit.Case
      test "trivially passes" do
        assert 1 + 1 == 2
      end
    end
    """
  end

  # Builds a real, minimal Mix project at `tmp` with: a compiling lib module,
  # a stub ecto.migrate task, a real copy of the task under test, a passing
  # test, and a real git repo with everything committed on `main`.
  defp build_fixture!(tmp, migrate_stub \\ nil) do
    File.mkdir_p!(Path.join(tmp, "lib/mix/tasks"))
    File.mkdir_p!(Path.join(tmp, "task_src/mix/tasks"))
    File.mkdir_p!(Path.join(tmp, "test"))

    File.write!(Path.join(tmp, "mix.exs"), mix_exs("Fixture"))
    File.write!(Path.join(tmp, "lib/hello.ex"), "defmodule Hello do\n  def go, do: :ok\nend\n")

    File.write!(
      Path.join(tmp, "lib/mix/tasks/ecto.migrate.ex"),
      migrate_stub || ecto_migrate_stub()
    )

    # The real task's source is compiled from `task_src/`, a compile path
    # outside the `lib/` and `test/` trees the task's own mock-grep stage
    # scans -- otherwise the task's own regex-pattern string literal
    # (containing the literal word "monkeypatch") would self-match and make
    # every fixture run fail the mock-grep stage regardless of the fixture
    # content under test.
    File.cp!(@task_source, Path.join(tmp, "task_src/mix/tasks/xaas.verify_and_commit.ex"))
    File.write!(Path.join(tmp, "test/test_helper.exs"), test_helper())
    File.write!(Path.join(tmp, "test/fixture_test.exs"), passing_test())
    File.write!(Path.join(tmp, ".gitignore"), "_build/\ndeps/\ncommit-message.txt\n")

    git!(tmp, ["init", "-q", "-b", "main"])
    git!(tmp, ["config", "user.email", "fixture@example.com"])
    git!(tmp, ["config", "user.name", "Fixture"])
    git!(tmp, ["add", "-A"])
    git!(tmp, ["commit", "-q", "-m", "initial fixture commit"])

    tmp
  end

  defp git!(cd, args) do
    {output, status} = System.cmd("git", args, cd: cd, stderr_to_stdout: true)
    if status != 0, do: flunk("git #{Enum.join(args, " ")} failed (#{status}): #{output}")
    output
  end

  defp write_message_file!(tmp, content) do
    path = Path.join(tmp, "commit-message.txt")
    File.write!(path, content)
    path
  end

  defp run_task(tmp, message_file) do
    System.cmd("mix", ["xaas.verify_and_commit", "--message-file", message_file],
      cd: tmp,
      stderr_to_stdout: true
    )
  end

  # ---- tests -----------------------------------------------------------

  @tag :subprocess
  test "halts with a real non-zero exit status on a real compile error, before reaching later stages" do
    tmp = unique_tmp("verify_and_commit_compile_error")
    build_fixture!(tmp)

    # A real, unambiguous compile error: unbalanced def.
    File.write!(Path.join(tmp, "lib/broken.ex"), "defmodule Broken do\n  def foo(\n")

    message_file = write_message_file!(tmp, "should never be committed\n")
    before_head = git!(tmp, ["rev-parse", "HEAD"])

    {output, exit_status} = run_task(tmp, message_file)

    assert exit_status != 0
    assert output =~ "compile"

    after_head = git!(tmp, ["rev-parse", "HEAD"])
    assert before_head == after_head

    File.rm_rf!(tmp)
  end

  @tag :subprocess
  test "halts with the mock-grep stage's real (inverted) exit status on a real mock-usage line" do
    tmp = unique_tmp("verify_and_commit_mock_usage")
    build_fixture!(tmp)

    # A real banned pattern the mock-grep stage's own grep command matches --
    # exercised as a real subprocess grep, not asserted against grep in
    # isolation the way the file's earlier version tested it.
    File.write!(Path.join(tmp, "lib/uses_monkeypatch.ex"), "# calls monkeypatch here\n")

    message_file = write_message_file!(tmp, "should never be committed\n")
    before_head = git!(tmp, ["rev-parse", "HEAD"])

    {output, exit_status} = run_task(tmp, message_file)

    # mock-grep stage maps grep exit 0 (matches found) -> stage failure 1.
    assert exit_status == 1
    assert output =~ "mock-grep"
    assert output =~ "monkeypatch"

    after_head = git!(tmp, ["rev-parse", "HEAD"])
    assert before_head == after_head

    File.rm_rf!(tmp)
  end

  @tag :subprocess
  test "mock-grep stage does not flag legitimate Phoenix patch/3 and Ash patch(:update) usage" do
    tmp = unique_tmp("verify_and_commit_legit_patch_usage")
    build_fixture!(tmp)

    # Real Phoenix ConnTest-style `patch/3` HTTP call and a real Ash
    # `patch(:update)` DSL usage -- both previously false-positived on the
    # old `patch\(` regex alternative, which this fixes.
    File.write!(
      Path.join(tmp, "test/legit_patch_usage_test.exs"),
      """
      defmodule LegitPatchUsageTest do
        use ExUnit.Case

        test "conn patch call" do
          conn = %{}
          _result = patch(conn, "/api/widgets/1", %{name: "updated"})
          assert true
        end

        defp patch(conn, _path, _params), do: conn
      end
      """
    )

    File.write!(
      Path.join(tmp, "lib/legit_ash_patch.ex"),
      """
      defmodule LegitAshPatch do
        # Ash DSL-style usage: patch(:update)
        def actions do
          [patch(:update)]
        end

        defp patch(action), do: action
      end
      """
    )

    message_file = write_message_file!(tmp, "should be committed\n")
    before_head = git!(tmp, ["rev-parse", "HEAD"])

    {output, exit_status} = run_task(tmp, message_file)

    assert exit_status == 0, "expected exit 0, got #{exit_status}: #{output}"
    refute output =~ "stage `mock-grep` failed"

    after_head = git!(tmp, ["rev-parse", "HEAD"])
    assert after_head != before_head, "expected a new commit to be created"

    File.rm_rf!(tmp)
  end

  @tag :subprocess
  test "happy path: exit 0, and the real commit message matches the message-file content exactly (-F round-trip)" do
    tmp = unique_tmp("verify_and_commit_happy_path")
    build_fixture!(tmp)

    # A real staged change beyond the initial fixture commit.
    File.write!(Path.join(tmp, "lib/new_feature.ex"), "defmodule NewFeature do\n  def ok, do: :ok\nend\n")
    git!(tmp, ["add", "-A"])

    message_content = "feat: add new_feature\n\nExercises the -F round trip, not -am.\n"
    message_file = write_message_file!(tmp, message_content)
    before_head = git!(tmp, ["rev-parse", "HEAD"])

    {output, exit_status} = run_task(tmp, message_file)

    assert exit_status == 0, "expected exit 0, got #{exit_status}: #{output}"

    after_head = git!(tmp, ["rev-parse", "HEAD"])
    assert after_head != before_head, "expected a new commit to be created"

    real_commit_message = git!(tmp, ["log", "-1", "--format=%B"])
    # `git log --format=%B` appends its own trailing newline regardless of
    # the source message's exact trailing whitespace; compare with both
    # sides' trailing newlines normalized away rather than asserting exact
    # byte equality against `git log`'s own formatting behavior.
    assert String.trim_trailing(real_commit_message, "\n") ==
             String.trim_trailing(message_content, "\n")

    File.rm_rf!(tmp)
  end

  @tag :subprocess
  test "nothing-to-commit: exit 0 and no new commit created when the working tree is clean" do
    tmp = unique_tmp("verify_and_commit_nothing_to_commit")
    build_fixture!(tmp)

    # No changes beyond the initial fixture commit -- working tree is clean.
    message_file = write_message_file!(tmp, "would-be message, never used\n")
    before_head = git!(tmp, ["rev-parse", "HEAD"])

    {output, exit_status} = run_task(tmp, message_file)

    assert exit_status == 0, "expected exit 0, got #{exit_status}: #{output}"
    assert output =~ "nothing to commit"

    after_head = git!(tmp, ["rev-parse", "HEAD"])
    assert after_head == before_head, "expected no new commit to be created"

    File.rm_rf!(tmp)
  end

  @tag :subprocess
  test "migrate stage reports 'already up' as a real non-error, pipeline continues to exit 0" do
    tmp = unique_tmp("verify_and_commit_migrations_already_up")
    build_fixture!(tmp, ecto_migrate_already_up_stub())

    message_file = write_message_file!(tmp, "would-be message, never used\n")
    before_head = git!(tmp, ["rev-parse", "HEAD"])

    {output, exit_status} = run_task(tmp, message_file)

    assert exit_status == 0, "expected exit 0, got #{exit_status}: #{output}"
    assert output =~ "Migrations already up"
    assert output =~ "nothing to commit"

    after_head = git!(tmp, ["rev-parse", "HEAD"])
    assert after_head == before_head, "expected no new commit to be created"

    File.rm_rf!(tmp)
  end

  @tag :subprocess
  test "missing --message-file: real Mix.raise usage error, non-zero exit, no stage runs" do
    tmp = unique_tmp("verify_and_commit_missing_message_file")
    build_fixture!(tmp)

    before_head = git!(tmp, ["rev-parse", "HEAD"])

    {output, exit_status} =
      System.cmd("mix", ["xaas.verify_and_commit"], cd: tmp, stderr_to_stdout: true)

    assert exit_status != 0
    assert output =~ "--message-file"

    # No stage output at all -- the raise happens before compile/migrate/test run.
    refute output =~ "==> compile"

    after_head = git!(tmp, ["rev-parse", "HEAD"])
    assert before_head == after_head

    File.rm_rf!(tmp)
  end
end
