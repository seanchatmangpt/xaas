defmodule Mix.Tasks.Xaas.VerifyAndCommit do
  @moduledoc """
  Compound task: compile -> migrate -> test -> mock-grep -> commit.

  ## Usage

      mix xaas.verify_and_commit --message-file path/to/commit-message.txt

  `--message-file` is required and must point to an existing, readable file
  containing the full commit message. There is no `--message`/inline-string
  form: per `~/.claude/rules/tools.md`, a commit message is never passed as
  an inline `-m`/`-am` string, because shell/OptionParser tokenization of
  backticks, parentheses, and quotes in prose is a real, recurring source of
  silent corruption or outright parse failure. The file's path is passed to
  `git commit -F <path>` as a literal argv entry (via `System.cmd/3`, not a
  shell), so no content of the message file is ever interpreted by a shell.

  ## Exit-code semantics

    * `0` -- every stage (compile, migrate, test, mock-grep, and commit or
      the no-op "nothing to commit" branch) passed. Process exits 0.
    * non-zero -- the *first* stage to fail halts the VM immediately via
      `System.halt/1` with that stage's real exit status. No later stage
      runs. `--message-file` missing or unreadable halts via `Mix.raise/1`
      before any stage runs (a usage error, not a stage failure).

  ## Mix bootstrap

  Runs with neither `Mix.Task.run("app.start")` nor `Mix.Task.run("app.config")`
  invoked directly by this task: every stage that needs the app compiled or
  configured (`ecto.migrate`, `test`) is itself a full `mix` subprocess via
  `System.cmd/3`, so it performs its own bootstrap in its own BEAM VM. This
  task's own VM only shells out and inspects exit statuses -- it never calls
  application code directly, so no bootstrap is needed on this side.

  ## Why `System.cmd/3` + `into:` instead of the default capture

  `System.cmd/3` by default captures stdout/stderr into the returned string
  and does not print it live. To avoid swallowing output while the pipeline
  runs, every subprocess stage is invoked with `into: IO.stream(:stdio, :line)`,
  which streams each line to this process's stdout as it is produced. With
  `into:` set, `System.cmd/3` returns `{%IO.Stream{}, exit_status}` instead
  of `{binary, exit_status}` -- the stream is already fully consumed by the
  time `System.cmd/3` returns, so only `exit_status` is inspected here.

  `System.cmd/3` never raises on a non-zero exit status (it only raises
  `ErlangError`/`ArgumentError` for a missing executable or bad args) --
  the exit status must be checked explicitly, which is what `run_stage/1`
  does before deciding whether to continue.

  ## Why `System.halt/1`, not `Mix.raise/1`, at a stage-failure point

  `Mix.raise/1` raises `Mix.Error`. When this task is run through the `mix`
  CLI entry point (`Mix.CLI.main/1`), that exception is caught there and
  reported with an exit code of 1 -- but that catching only happens at the
  outermost CLI boundary. If this task were instead invoked in-process
  (e.g. `Mix.Task.run("xaas.verify_and_commit")` from another Mix task, or
  `Mix.Task.rerun/2` from an ExUnit test running in the same BEAM VM),
  `Mix.raise/1` merely raises an exception in that VM -- it does not set an
  OS-level exit status for a parent process, and it does nothing to a
  `System.cmd` result if the raise happens on the parent side rather than
  inside a spawned child OS process.

  `System.halt/1` terminates the *current* BEAM VM immediately with the
  given integer exit code, without guaranteeing `at_exit` callbacks finish.
  That is the only mechanism that reliably produces a real OS exit code
  when this task's VM is itself the subprocess an external caller
  (a shell, CI, or `System.cmd("mix", [...])` from a test) is inspecting.
  Using `System.halt/1` here is therefore correct only because this task is
  meant to be invoked as `mix xaas.verify_and_commit` in its own OS process
  (directly from a shell, or via `System.cmd/3` from a test) -- it must
  never be called via in-process `Mix.Task.run/2` from within a long-lived
  VM (e.g. `iex`, or another task's own process) that should survive the
  call, since `System.halt/1` would kill that VM too.

  `Mix.raise/1` is used instead, before any stage runs, for the one usage
  error this task can detect statically (`--message-file` missing or
  unreadable) -- that failure happens before any subprocess or OS-level
  exit-code contract is in play, so raising through the normal Mix CLI path
  is correct and matches the rest of this codebase's Mix task conventions.
  """
  use Mix.Task

  @shortdoc "compile -> migrate -> test -> mock-grep -> commit, halts on first real failure"

  @impl Mix.Task
  def run(args) do
    {opts, _rest, invalid} = OptionParser.parse(args, strict: [message_file: :string])

    if invalid != [] do
      Mix.raise(
        "usage: mix xaas.verify_and_commit --message-file <path>  (invalid options: #{inspect(invalid)})"
      )
    end

    message_file =
      case Keyword.get(opts, :message_file) do
        nil ->
          Mix.raise("usage: mix xaas.verify_and_commit --message-file <path>")

        path ->
          if File.regular?(path) do
            path
          else
            Mix.raise("xaas.verify_and_commit: --message-file #{inspect(path)} not found")
          end
      end

    repo_root = File.cwd!()

    verify_stages = [
      {"compile", "mix", ["compile", "--force", "--warnings-as-errors"]},
      {"migrate", "mix", ["ecto.migrate"]},
      {"test", "mix", ["test"]},
      {"mock-grep", &mock_grep_stage/0}
    ]

    Enum.each(verify_stages, &run_stage/1)

    run_commit_stage(message_file, repo_root)

    Mix.shell().info("xaas.verify_and_commit: all stages passed")
  end

  # Real grep, real files, real exit code. `-E` (extended regex) is passed
  # explicitly rather than relying on ambient alternation support that
  # varies between grep binaries (GNU grep's default BRE mode does not
  # support unescaped `|` alternation the way a ugrep/ripgrep-compatible
  # binary might) -- with `-E`, unescaped `|` alternation is portable across
  # GNU and BSD/POSIX grep. This stage invokes the system `grep` binary via
  # `System.cmd/3`, not ripgrep.
  defp mock_grep_stage do
    {_output, grep_status} =
      System.cmd(
        "grep",
        [
          "-rnE",
          "--include=*.ex",
          "--include=*.exs",
          "unittest\\.mock|Mock\\(|MagicMock|monkeypatch|Mox\\b|:meck|meck\\.",
          "test/",
          "lib/"
        ],
        into: IO.stream(:stdio, :line),
        stderr_to_stdout: true
      )

    # grep: 0 = matches found (banned pattern present -> this gate fails),
    #       1 = no matches (clean -> this gate passes),
    #      >1 = grep itself errored (bad path/args -> propagate as failure)
    case grep_status do
      0 -> 1
      1 -> 0
      other -> other
    end
  end

  # Real `git status --porcelain` check before committing. A clean working
  # tree means there is nothing for `git commit` to record -- running
  # `git commit -F <file>` against an empty diff would fail (or, with
  # `--allow-empty`, create a misleading empty commit), so this branch
  # reports the HDDL doc's finalize/m-finalize-noop terminal state instead
  # of invoking git commit at all.
  defp run_commit_stage(message_file, repo_root) do
    Mix.shell().info("==> git add -A")

    {_add_output, add_exit} =
      System.cmd("git", ["add", "-A"], cd: repo_root, stderr_to_stdout: true)

    halt_on_failure("git-add", add_exit)

    Mix.shell().info("==> git status --porcelain")

    {status_output, status_exit} =
      System.cmd("git", ["status", "--porcelain"], cd: repo_root, stderr_to_stdout: true)

    halt_on_failure("git-status", status_exit)

    if String.trim(status_output) == "" do
      Mix.shell().info(
        "xaas.verify_and_commit: verify-only, nothing to commit (working tree clean)"
      )
    else
      Mix.shell().info("==> commit: git commit -F #{message_file}")

      {_output, commit_exit} =
        System.cmd("git", ["commit", "-F", message_file],
          cd: repo_root,
          into: IO.stream(:stdio, :line),
          stderr_to_stdout: true
        )

      halt_on_failure("commit", commit_exit)
    end
  end

  # Runs one verify-stage as a real subprocess (or a real local check for
  # mock-grep), streams its output live via `into:`, and halts the VM with
  # the stage's real exit status the instant a stage fails. Never continues
  # past a failing stage.
  defp run_stage({name, cmd, cmd_args}) when is_binary(cmd) do
    Mix.shell().info("==> #{name}: #{cmd} #{Enum.join(cmd_args, " ")}")

    {_output, exit_status} =
      System.cmd(cmd, cmd_args, into: IO.stream(:stdio, :line), stderr_to_stdout: true)

    halt_on_failure(name, exit_status)
  end

  defp run_stage({name, check_fun}) when is_function(check_fun, 0) do
    Mix.shell().info("==> #{name}")
    exit_status = check_fun.()
    halt_on_failure(name, exit_status)
  end

  defp halt_on_failure(_name, 0), do: :ok

  defp halt_on_failure(name, exit_status) do
    Mix.shell().error("xaas.verify_and_commit: stage `#{name}` failed with exit #{exit_status}")
    System.halt(exit_status)
  end
end
