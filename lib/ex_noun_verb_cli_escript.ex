defmodule ExNounVerbCli.Escript do
  @moduledoc """
  Single-binary (escript) adapter for `ex_noun_verb_cli`'s dispatch-agnostic
  core: raw argv -> `ExNounVerbCli.Chaining.expand/1` -> one
  `ExNounVerbCli.Dispatcher.dispatch/2` call per expanded group (with
  `@{N.path}` references resolved between groups via
  `ExNounVerbCli.Chaining.resolve_references/2`) ->
  `ExNounVerbCli.JsonOutput.encode/2` -> a JSON line printed to stdout.
  A leading `--introspect` flag returns the registry's machine-readable
  manifest instead of dispatching (see `ExNounVerbCli.Introspect`).

  `run/2` is the real, testable logic (no process-halting side effect) --
  it takes a registry module and an argv list and returns the JSON string
  that would be printed, plus the exit status that would be used. `main/1`
  is a thin wrapper that calls `run/2`, prints the result, and actually
  halts the VM -- this split exists so tests can exercise the real dispatch
  path without terminating the test VM.

  The registry module `main/1` dispatches against is resolved from
  application config (`:ex_noun_verb_cli, :registry`), since an escript's
  `main/1` has no other way to receive it -- there is no caller passing it
  as an argument in the compiled-binary path.
  """

  alias ExNounVerbCli.{Chaining, Completions, Dispatcher, Help, Introspect, JsonOutput, Shell}

  @doc """
  Runs the full core pipeline (chaining expansion, `@{N.path}` reference
  resolution between groups, dispatch per group, JSON encoding) against
  `registry_module` for the given `argv`, without ever halting the VM or
  touching stdout.

  Leading meta-flags short-circuit dispatch:

    * `--introspect [<noun>]` — the registry's machine-readable manifest,
      wrapped in the standard ok envelope (since v26.9.15).
    * `--help [<noun>]` — the same manifest rendered as plain-text help
      (a human projection; returned as `{:ok, text}`, not JSON).
    * `--completions <shell>` — a sourceable completion script for the
      shells `ExNounVerbCli.Shell` marks supported (bash/zsh/fish),
      generated from the manifest. A missing argument, an unknown shell,
      or a known-but-unported shell (powershell, elvish) returns the
      typed `:invalid_option` error envelope instead of a script.

  With a single expanded group (the common case -- no `"++"` chaining),
  returns `{status, json_string}` where `status` is `:ok` or `:error`
  matching the single dispatch result.

  With multiple expanded groups (chained via `"++"`), each group is
  dispatched in turn -- with every `@{N.path}` reference resolved against
  the envelopes of the groups that already ran -- and the overall status
  is `:error` if any group errored, `:ok` otherwise; the returned JSON string
  is a JSON array of each group's own envelope, in order.
  """
  @spec run(module(), [String.t()]) :: {:ok | :error, String.t()}
  def run(registry_module, ["--introspect" | rest]) when is_atom(registry_module) do
    noun = Enum.at(rest, 0)
    manifest = Introspect.manifest(registry_module, noun)
    {:ok, JsonOutput.encode_string(JsonOutput.encode(:ok, manifest))}
  end

  def run(registry_module, ["--help" | rest]) when is_atom(registry_module) do
    noun = Enum.at(rest, 0)
    {:ok, Help.render(Introspect.manifest(registry_module, noun), command_name())}
  end

  def run(registry_module, ["--completions" | rest]) when is_atom(registry_module) do
    case Shell.parse(Enum.at(rest, 0)) do
      {:ok, shell} ->
        if Shell.supported?(shell) do
          {:ok,
           Completions.script(Introspect.manifest(registry_module, nil), shell, command_name())}
        else
          {:error, unsupported_shell_envelope(Enum.at(rest, 0))}
        end

      {:error, unknown} ->
        {:error, unsupported_shell_envelope(unknown)}
    end
  end

  def run(registry_module, argv) when is_atom(registry_module) and is_list(argv) do
    argv
    |> Chaining.expand()
    |> Enum.reduce({[], []}, fn group, {done, envelopes} ->
      group = Chaining.resolve_references(group, envelopes)

      {status, envelope} =
        case Dispatcher.dispatch(registry_module, group) do
          {:ok, value} -> {:ok, JsonOutput.encode(:ok, value)}
          {:error, error} -> {:error, JsonOutput.encode(:error, error)}
        end

      {done ++ [{status, envelope}], envelopes ++ [envelope]}
    end)
    |> case do
      {[{status, envelope}], _envelopes} ->
        {status, JsonOutput.encode_string(envelope)}

      {many, _envelopes} ->
        overall =
          if Enum.any?(many, fn {status, _} -> status == :error end), do: :error, else: :ok

        {overall, JsonOutput.encode_string(Enum.map(many, fn {_s, env} -> env end))}
    end
  end

  @doc """
  Escript entry point. Normalizes `argv` (escripts may receive either a
  list of charlists or a list of binaries depending on how the runtime
  invokes `main/1`), resolves the registry module from application config,
  runs the core pipeline via `run/2`, prints the resulting JSON to stdout,
  and halts the VM with exit code `0` on `:ok` or `1` on `:error`.
  """
  @spec main([charlist()] | [String.t()]) :: no_return()
  def main(argv) do
    normalized = Enum.map(argv, &normalize_arg/1)
    registry_module = Application.fetch_env!(:ex_noun_verb_cli, :registry)

    {status, json} = run(registry_module, normalized)

    IO.puts(json)

    case status do
      :ok -> System.halt(0)
      :error -> System.halt(1)
    end
  end

  defp normalize_arg(arg) when is_binary(arg), do: arg
  defp normalize_arg(arg) when is_list(arg), do: List.to_string(arg)

  # The name help/completions attach to: a consumer's binary is usually
  # not called `ex_noun_verb_cli`, so it can override via config.
  defp command_name do
    Application.get_env(:ex_noun_verb_cli, :completion_command, "ex_noun_verb_cli")
  end

  defp unsupported_shell_envelope(shell_name) do
    error =
      ExNounVerbCli.Error.new(
        :invalid_option,
        "unsupported shell for --completions: #{inspect(shell_name)} " <>
          "(supported: " <> Enum.map_join(Shell.supported_shells(), ", ", &to_string/1) <> ")",
        %{invalid: [%{"flag" => "--completions", "value" => shell_name}]}
      )

    JsonOutput.encode_string(JsonOutput.encode(:error, error))
  end
end
