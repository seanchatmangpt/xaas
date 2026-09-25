defmodule ExNounVerbCli.Dispatcher do
  @moduledoc """
  Pure, adapter-agnostic dispatch: given a `ExNounVerbCli.Registry`-behaviour
  module and a single argv list, look up the matching verb, parse the
  remaining argv against its `info` schema, and invoke its handler.

  ## Argv shape

  The first two non-flag tokens of `argv` are treated as the noun and verb,
  e.g. `["calc", "add", "--x", "2", "--y", "3"]` dispatches to whatever verb
  is registered under noun `"calc"`, verb `"add"`. Everything after those
  two tokens is parsed with `OptionParser.parse/2`, using the matched verb's
  `info.schema`/`info.aliases` (translated into `OptionParser`'s
  `:strict`/`:aliases` options) as `:strict` switches.

  ## Argument ordering into the handler

  `apply(verb.module, verb.function, args)` is called with `args` built as:
  positional values (mapped, in order, onto `info.positional`) followed by
  the parsed values of every key named in `info.required`, in the order
  `info.required` lists them. This is a real, documented convention -- not
  every possible handler calling convention, but a workable default for the
  toy/POC handlers this v1 targets (e.g. `add(x, y)` driven by `--x`/`--y`
  both marked required).

  ## Errors

  Returns `{:error, %ExNounVerbCli.Error{}}` (never raises) for:

    * `:unknown_verb` -- no verb registered for the given noun/verb pair.
    * `:invalid_option` -- `OptionParser.parse/2` rejected a switch not in
      the schema.
    * `:missing_required_option` -- a key in `info.required` was not
      supplied.
    * `:handler_raised` -- the handler function raised a real exception;
      caught here so a single bad verb never crashes the whole dispatch
      call. The original exception's message and type are captured in
      `detail`.
  """

  alias ExNounVerbCli.{Error, Verb}

  @spec dispatch(module(), [String.t()]) :: {:ok, term()} | {:error, Error.t()}
  def dispatch(registry_module, argv) when is_atom(registry_module) and is_list(argv) do
    {noun, verb, rest} = split_noun_verb(argv)

    case find_verb(registry_module, noun, verb) do
      nil ->
        {:error,
         Error.new(
           :unknown_verb,
           "no verb registered for #{inspect(noun)} #{inspect(verb)}",
           %{noun: noun, verb: verb}
         )}

      %Verb{} = found ->
        do_dispatch(found, rest)
    end
  end

  defp split_noun_verb(argv) do
    case argv do
      [noun, verb | rest] -> {noun, verb, rest}
      [noun] -> {noun, nil, []}
      [] -> {nil, nil, []}
    end
  end

  defp find_verb(registry_module, noun, verb) do
    Enum.find(registry_module.list_verbs(), fn v -> v.noun == noun and v.verb == verb end)
  end

  defp do_dispatch(%Verb{} = found, rest) do
    info = found.info || %{}
    schema = Map.get(info, :schema, [])
    aliases = Map.get(info, :aliases, [])
    positional_names = Map.get(info, :positional, [])
    required = Map.get(info, :required, [])

    {opts, positional_args, invalid} =
      OptionParser.parse(normalize_underscore_flags(rest), strict: schema, aliases: aliases)

    cond do
      invalid != [] ->
        # OptionParser invalid entries are {flag, value} tuples, which Jason
        # cannot encode; this detail flows straight into the JSON error
        # envelope, so it must be stored in an encodable shape -- raw tuples
        # here crashed Jason.encode!/1 inside the escript adapter's error
        # path instead of printing the envelope (real crash, 2026-09-15).
        {:error,
         Error.new(:invalid_option, "unrecognized option(s): #{inspect(invalid)}", %{
           invalid: Enum.map(invalid, fn {flag, value} -> %{"flag" => flag, "value" => value} end)
         })}

      (missing = Enum.filter(required, fn key -> not Keyword.has_key?(opts, key) end)) != [] ->
        {:error,
         Error.new(
           :missing_required_option,
           "missing required option(s): #{inspect(missing)}",
           %{missing: missing}
         )}

      true ->
        positional_values =
          positional_names
          |> Enum.zip(positional_args)
          |> Enum.map(fn {_name, value} -> value end)

        required_values = Enum.map(required, fn key -> Keyword.fetch!(opts, key) end)

        args = positional_values ++ required_values

        invoke(found, args)
    end
  end

  # Mirrors the real Rust `--profile-id`/`--profile_id` dual-acceptance
  # convention (`~/clap-noun-verb/src/cli/registry.rs`, `build_argument`):
  # the canonical long flag is kebab-case, and the verbatim snake_case
  # spelling is kept as a backward-compatible alias for the same field.
  # `OptionParser` only recognizes the kebab-case form natively (it maps
  # `--foo-bar` to `:foo_bar` on its own), so a bare `--profile_id` token
  # is otherwise rejected as unrecognized even though the schema declares
  # `profile_id:`. Normalize any long-flag token's underscores to dashes
  # before parsing so both spellings resolve to the same option.
  defp normalize_underscore_flags(argv) do
    Enum.map(argv, fn
      "--" <> rest = token ->
        case String.split(rest, "=", parts: 2) do
          [name] ->
            if String.contains?(name, "_") and not String.starts_with?(name, "-") do
              "--" <> String.replace(name, "_", "-")
            else
              token
            end

          [name, value] ->
            if String.contains?(name, "_") and not String.starts_with?(name, "-") do
              "--" <> String.replace(name, "_", "-") <> "=" <> value
            else
              token
            end
        end

      other ->
        other
    end)
  end

  defp invoke(%Verb{module: mod, function: fun}, args) do
    {:ok, apply(mod, fun, args)}
  rescue
    exception ->
      {:error,
       Error.new(
         :handler_raised,
         "handler #{inspect(mod)}.#{fun}/#{length(args)} raised: #{Exception.message(exception)}",
         %{exception: inspect(exception.__struct__)}
       )}
  end
end
