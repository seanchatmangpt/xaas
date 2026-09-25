defmodule ExNounVerbCli.ShellTest do
  use ExUnit.Case, async: true

  alias ExNounVerbCli.Shell

  # Port-shaped from upstream clap-noun-verb's shell_completions example:
  # the admitted names and the load-bearing policy assertions are echoed
  # here against the real table.
  test "parses the five upstream-admitted shell names and refuses anything else" do
    assert Enum.map([:bash, :zsh, :fish, :powershell, :elvish], &Shell.parse(to_string(&1))) ==
             Enum.map([:bash, :zsh, :fish, :powershell, :elvish], &{:ok, &1})

    assert Shell.parse("tcsh") == {:error, "tcsh"}
  end

  test "supported?/1 admits bash/zsh/fish and refuses the unported shells" do
    assert Shell.supported_shells() == [:bash, :fish, :zsh]
    refute Shell.supported?(:powershell)
    refute Shell.supported?(:elvish)
  end

  test "command substitution policy matches upstream: bash yes, powershell no" do
    assert Shell.command_substitution?(:bash)
    refute Shell.command_substitution?(:powershell)
  end

  test "line endings match upstream: powershell CRLF, bash LF" do
    assert Shell.line_ending(:powershell) == "\r\n"
    assert Shell.line_ending(:bash) == "\n"
  end
end
