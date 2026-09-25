defmodule Mix.Tasks.ExNounVerbCliTest do
  use ExUnit.Case, async: false

  import Igniter.Test
  import ExUnit.CaptureIO

  alias ExNounVerbCli.Test.CalcRegistry

  setup do
    previous = Application.get_env(:ex_noun_verb_cli, :registry)
    Application.put_env(:ex_noun_verb_cli, :registry, CalcRegistry)

    on_exit(fn ->
      if previous do
        Application.put_env(:ex_noun_verb_cli, :registry, previous)
      else
        Application.delete_env(:ex_noun_verb_cli, :registry)
      end
    end)

    :ok
  end

  test "dispatches through the real core and folds the JSON envelope into an Igniter notice" do
    igniter =
      test_project()
      |> Igniter.compose_task(Mix.Tasks.ExNounVerbCli, ["calc", "add", "--x", "2", "--y", "3"])

    assert_has_notice(igniter, fn notice ->
      Jason.decode!(notice) == %{"status" => "ok", "result" => 5}
    end)
  end

  test "an unknown verb still folds an error envelope into a notice, not an issue" do
    igniter =
      test_project()
      |> Igniter.compose_task(Mix.Tasks.ExNounVerbCli, ["calc", "unknown-verb"])

    assert_has_notice(igniter, fn notice ->
      match?(
        %{"status" => "error", "error" => %{"code" => "unknown_verb"}},
        Jason.decode!(notice)
      )
    end)
  end

  test "info/2 returns a real %Igniter.Mix.Task.Info{} struct, not a bare map" do
    info = Mix.Tasks.ExNounVerbCli.info([], nil)

    assert %Igniter.Mix.Task.Info{} = info
    assert info.positional == [:noun, :verb]
    assert info.extra_args? == true
  end

  # Igniter's own global options (`Igniter.Mix.Task.Info.global_options/0`)
  # are real, standing flags every `Igniter.Mix.Task` inherits, exercised
  # against actual subprocess invocations (Chicago-style: a real `mix`
  # subprocess in this real project, matching the escript adapter's own
  # `System.cmd` test style) rather than a stubbed argv list, because the
  # bug this guards against (`--dry-run` leaking into `Dispatcher.dispatch/2`
  # and crashing `Jason.encode!/1` on a raw `OptionParser` tuple) only
  # reproduces through the real `run/1` -> `parse_argv/1` -> `igniter/1`
  # pipeline, not through `Igniter.compose_task/4` directly (which never
  # threads a real `--dry-run` flag through `igniter.args.argv` the same
  # way a real CLI invocation does).
  describe "global options (--dry-run, --yes) via a real subprocess" do
    test "--dry-run still computes and reports the real dispatch result, with zero file mutation" do
      before_status = git_status!()

      {output, exit_code} =
        System.cmd(
          "mix",
          ["ex_noun_verb_cli", "calc", "add", "--x", "2", "--y", "3", "--dry-run"],
          stderr_to_stdout: true
        )

      after_status = git_status!()

      assert exit_code == 0
      assert output =~ ~s({"result":5,"status":"ok"})
      assert before_status == after_status
    end

    test "--yes does not leak into the dispatched verb's own option parsing" do
      {output, exit_code} =
        System.cmd(
          "mix",
          ["ex_noun_verb_cli", "calc", "multiply", "--x", "4", "--y", "5", "--yes"],
          stderr_to_stdout: true
        )

      assert exit_code == 0
      assert output =~ ~s({"result":20,"status":"ok"})
    end

    defp git_status!, do: System.cmd("git", ["status", "--porcelain"]) |> elem(0)
  end

  # Proves real cross-task composition (Igniter's own `compose_task_test`
  # coverage in `test/igniter/mix/task_test.exs` -- "composed tasks do not
  # consume current task args" -- exercises this same mechanism for
  # Igniter's own fixture tasks; this test exercises it for our adapter
  # specifically, per this task's own required verification item).
  test "is genuinely composable via Igniter.compose_task/4 by another real task" do
    previous = Application.get_env(:ex_noun_verb_cli, :registry)
    Application.put_env(:ex_noun_verb_cli, :registry, CalcRegistry)

    igniter =
      test_project()
      |> Igniter.compose_task(ExNounVerbCli.Test.ComposingTaskFixture, [
        "calc",
        "add",
        "--x",
        "10",
        "--y",
        "32"
      ])

    assert_has_notice(igniter, fn notice ->
      Jason.decode!(notice) == %{"status" => "ok", "result" => 42}
    end)

    if previous do
      Application.put_env(:ex_noun_verb_cli, :registry, previous)
    else
      Application.delete_env(:ex_noun_verb_cli, :registry)
    end
  end

  test "delegates --help to mix help, per Igniter.Mix.Task's inherited run/1" do
    Mix.Task.reenable("help")
    Mix.Task.reenable("ex_noun_verb_cli")

    output = capture_io(fn -> Mix.Tasks.ExNounVerbCli.run(["--help"]) end)

    assert output =~ "ex_noun_verb_cli"
  end
end
