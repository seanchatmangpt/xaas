defmodule ExNounVerbCli.Shell do
  @moduledoc """
  Shell policy table, port-shaped from `clap_noun_verb`'s
  `shell::ShellType` (upstream `src/shell.rs` / the `shell_completions`
  example): which shells this library can emit completion scripts for,
  which support command substitution inside completion functions, and
  each shell's line-ending convention.

  The table is data -- `ExNounVerbCli.Completions` reads it; nothing
  guesses. Upstream admits `powershell`/`elvish` as shell *names* with
  real policies; this port does the same but marks them unsupported for
  completion generation rather than approximating scripts it has not
  ported, so `--completions powershell` returns a typed refusal instead
  of a fake script.
  """

  @type t :: :bash | :zsh | :fish | :powershell | :elvish

  @policies %{
    bash: %{supported: true, command_substitution: true, line_ending: "\n"},
    zsh: %{supported: true, command_substitution: true, line_ending: "\n"},
    fish: %{supported: true, command_substitution: true, line_ending: "\n"},
    powershell: %{supported: false, command_substitution: false, line_ending: "\r\n"},
    elvish: %{supported: false, command_substitution: false, line_ending: "\n"}
  }

  @names Map.keys(@policies) |> Enum.map(&to_string/1)

  @doc "Parses a shell name; `{:error, name}` for anything unrecognized."
  @spec parse(String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(name) when name in @names, do: {:ok, String.to_existing_atom(name)}
  def parse(other) when is_binary(other), do: {:error, other}

  @doc "Whether this library emits a completion script for `shell`."
  @spec supported?(t()) :: boolean()
  def supported?(shell) when is_map_key(@policies, shell), do: @policies[shell].supported

  @doc """
  Whether the shell supports command substitution inside its completion
  machinery (upstream: bash yes, powershell no).
  """
  @spec command_substitution?(t()) :: boolean()
  def command_substitution?(shell) when is_map_key(@policies, shell),
    do: @policies[shell].command_substitution

  @doc "The shell's line-ending convention (upstream: powershell `\\r\\n`, others `\\n`)."
  @spec line_ending(t()) :: String.t()
  def line_ending(shell) when is_map_key(@policies, shell), do: @policies[shell].line_ending

  @doc "The shells this library emits completion scripts for, sorted for determinism."
  @spec supported_shells() :: [t()]
  def supported_shells,
    do:
      @names |> Enum.map(&String.to_existing_atom/1) |> Enum.filter(&supported?/1) |> Enum.sort()
end
