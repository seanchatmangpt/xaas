# `:igniter` is an `optional: true` dependency: consumers that never use
# the Igniter adapter (e.g. ex-noun-verb-cli-pack's `examples/greet-cli`)
# do not depend on `:igniter`, so `Igniter.Mix.Task` is not on their
# compile-time load path at all. `use Igniter.Mix.Task` is a compile-time
# macro -- the module cannot even be *defined* without it -- so this
# adapter only materializes when Igniter is actually loadable, and an
# igniter-less consumer compiles clean instead of failing on this file
# (guarded for real by `test/mix/igniter_optional_compile_test.exs`).
if Code.ensure_loaded?(Igniter.Mix.Task) do
  defmodule Mix.Tasks.ExNounVerbCli do
    @moduledoc """
    A generic `Igniter.Mix.Task` adapter for `ex_noun_verb_cli`'s
    dispatch-agnostic core: `mix ex_noun_verb_cli <noun> <verb> [opts]`
    dispatches through the same `ExNounVerbCli.Dispatcher.dispatch/2` core the
    escript adapter (`ExNounVerbCli.Escript`) uses -- no dispatch logic is
    duplicated here.

    Because this task composes into a larger Igniter pipeline (rather than
    printing to stdout and exiting, like the escript adapter does), the
    JSON-encoded dispatch result is folded into the `Igniter.t()` being built
    via `Igniter.add_notice/2`, so it shows up alongside any other notices a
    composed pipeline accumulates.

    The registry module to dispatch against is resolved from application
    config (`:ex_noun_verb_cli, :registry`) -- the same convention
    `ExNounVerbCli.Escript` uses, so both adapters share one configuration
    point rather than each inventing their own.

    This task accepts arbitrary extra options (`extra_args?: true`,
    no fixed `:schema`) because the real option schema for any given
    noun/verb pair is only known once the registry has been looked up inside
    `ExNounVerbCli.Dispatcher.dispatch/2` -- the task's own `info/2` cannot
    declare it up front.
    """

    use Igniter.Mix.Task

    alias ExNounVerbCli.{Dispatcher, JsonOutput}

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :ex_noun_verb_cli,
        example: "mix ex_noun_verb_cli calc add --x 2 --y 3",
        positional: [:noun, :verb],
        extra_args?: true
      }
    end

    # Igniter's own global options (`Igniter.Mix.Task.Info.global_options/0`)
    # -- `--dry-run`, `--yes`, etc. -- are real, standing CLI flags every
    # Igniter.Mix.Task inherits via `run/1`'s global-schema merge, but they
    # never make it into `igniter.args.options` for a schema-less
    # (`extra_args?: true`, no `:schema`) task like this one: they only
    # affect positional-arg extraction (so they don't get misread as
    # positional values), then remain sitting in the raw `igniter.args.argv`
    # this task's own `dispatch_argv/3` builds `rest` from. Left unstripped,
    # a real invocation like `mix ex_noun_verb_cli calc add --x 2 --y 3
    # --dry-run` forwards `--dry-run` into `Dispatcher.dispatch/2`, which
    # rejects it as an unknown option against the verb's own schema and
    # produces an `OptionParser`-shaped `{"--dry-run", nil}` tuple that
    # `Jason.encode!/1` cannot serialize, crashing the whole task.
    @global_option_switches Igniter.Mix.Task.Info.global_options()[:switches]

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      registry_module = Application.fetch_env!(:ex_noun_verb_cli, :registry)

      %{noun: noun, verb: verb} = igniter.args.positional

      rest =
        igniter.args.argv
        |> dispatch_argv(noun, verb)
        |> reject_global_options()

      envelope =
        case Dispatcher.dispatch(registry_module, [noun, verb | rest]) do
          {:ok, value} -> JsonOutput.encode(:ok, value)
          {:error, error} -> JsonOutput.encode(:error, error)
        end

      Igniter.add_notice(igniter, JsonOutput.encode_string(envelope))
    end

    # The raw argv includes the task name's own positional noun/verb tokens
    # plus whatever options followed them; strip the first two positional
    # tokens (noun, verb) so only the remaining options are handed to
    # `Dispatcher.dispatch/2` (which re-derives noun/verb itself from the
    # `[noun, verb | rest]` list built above).
    defp dispatch_argv(argv, noun, verb) do
      case argv do
        [^noun, ^verb | rest] -> rest
        _ -> Enum.reject(argv, fn token -> token == noun or token == verb end)
      end
    end

    # Strips any of Igniter's own global option flags (and, for the
    # value-taking ones like `--only`/`--scribe`, their following value)
    # out of `argv` using real `OptionParser` semantics against the real
    # global switches schema -- rather than a naive string-equality reject,
    # so a value-taking global flag's value doesn't leak through as a bare
    # positional-looking token either.
    defp reject_global_options([]), do: []

    defp reject_global_options(argv) do
      case OptionParser.next(argv, switches: @global_option_switches) do
        {:error, [token | rest]} ->
          [token | reject_global_options(rest)]

        {tag, key, _value, rest} when tag in [:ok, :invalid, :undefined] ->
          consumed = Enum.count(argv) - Enum.count(rest)

          if Keyword.has_key?(@global_option_switches, key) do
            reject_global_options(rest)
          else
            Enum.take(argv, consumed) ++ reject_global_options(rest)
          end
      end
    end
  end
end
