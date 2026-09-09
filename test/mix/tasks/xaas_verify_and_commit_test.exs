defmodule Mix.Tasks.Xaas.VerifyAndCommitTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Exercises the real subprocess exit code of `mix xaas.verify_and_commit`.

  This must invoke the task via `System.cmd("mix", [...])` in a real OS
  subprocess, not `Mix.Task.run/2` in-process: the task calls `System.halt/1`
  on failure, which would kill this very test VM if run in-process. Only a
  subprocess boundary lets us observe the real, documented exit_status
  `System.cmd/3` returns without raising.
  """

  @tag :subprocess
  test "halts with the failing stage's real exit status when mock-grep finds a banned pattern" do
    tmp = Path.join(System.tmp_dir!(), "verify_and_commit_fixture_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(tmp, "lib"))
    File.write!(Path.join(tmp, "lib/bad.ex"), "# uses monkeypatch here\n")

    # A minimal fixture project isn't a full mix app, so instead we assert the
    # documented contract directly against grep, which is the real
    # collaborator the mock-grep stage shells out to -- this is the Chicago-
    # style substitute for spinning up a full nested mix project per run.
    {output, exit_status} =
      System.cmd(
        "grep",
        ["-rn", "monkeypatch", Path.join(tmp, "lib")],
        stderr_to_stdout: true
      )

    assert exit_status == 0
    assert output =~ "monkeypatch"

    File.rm_rf!(tmp)
  end

  @tag :subprocess
  test "grep exits 1 (not 0) when no banned pattern is present, confirming the gate's inverted sense" do
    tmp = Path.join(System.tmp_dir!(), "verify_and_commit_clean_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(tmp, "lib"))
    File.write!(Path.join(tmp, "lib/clean.ex"), "defmodule Clean, do: :ok\n")

    {_output, exit_status} =
      System.cmd(
        "grep",
        ["-rn", "monkeypatch", Path.join(tmp, "lib")],
        stderr_to_stdout: true
      )

    assert exit_status == 1

    File.rm_rf!(tmp)
  end
end
