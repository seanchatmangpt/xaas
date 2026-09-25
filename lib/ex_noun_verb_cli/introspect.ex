defmodule ExNounVerbCli.Introspect do
  @moduledoc """
  Machine-readable self-description of a registry: the agent-facing 80/20.

  An LLM/agent (or a shell-completion generator, or a test harness) that
  can execute the binary can discover every noun, verb, option schema,
  required flag, and chaining token as pure data via `manifest/1` --
  without reading prose docs or parsing `--help` output. The escript
  adapter exposes this as a leading `--introspect` flag:

      $ ./my_cli --introspect            # full manifest, JSON envelope
      $ ./my_cli --introspect calc       # one noun's verbs only

  The manifest is wrapped in the standard
  `{"result": ..., "status" => "ok"}` envelope by the adapter, and is
  JSON-encodable by construction (string keys, atoms stringified).
  """

  alias ExNounVerbCli.Verb

  @manifest_schema "https://ggen.dev/ex-noun-verb-cli/introspect/v1"

  @doc """
  Builds the full manifest for `registry`'s verb table, or, when `noun` is
  given, the manifest filtered to that noun's verbs alone.
  """
  @spec manifest(module()) :: map()
  @spec manifest(module(), String.t() | nil) :: map()
  def manifest(registry, noun \\ nil)

  def manifest(registry, nil) when is_atom(registry) do
    verbs =
      registry
      |> list_verbs()
      |> Enum.sort_by(&{&1.noun, &1.verb})
      |> Enum.map(&verb_record/1)

    %{
      "schema" => @manifest_schema,
      "registry" => inspect(registry),
      "nouns" => nouns_index(verbs),
      "verbs" => verbs,
      "chaining" => chaining_doc()
    }
  end

  def manifest(registry, noun) when is_atom(registry) and is_binary(noun) do
    full = manifest(registry, nil)
    verbs = Enum.filter(full["verbs"], &(&1["noun"] == noun))
    %{full | "nouns" => nouns_index(verbs), "verbs" => verbs}
  end

  defp list_verbs(registry), do: registry.list_verbs()

  # One JSON-ready record per verb. Handler arity is derivable from the
  # info map (positional + required values, in that invocation order), so
  # an agent can tell exactly what a handler consumes without loading the
  # module.
  defp verb_record(%Verb{} = verb) do
    info = verb.info || %{}

    %{
      "noun" => verb.noun,
      "verb" => verb.verb,
      "doc" => verb.doc || "",
      "handler" =>
        "#{inspect(verb.module)}.#{verb.function}/#{length(listify(info[:positional])) + length(listify(info[:required]))}",
      "schema" => schema_map(info[:schema]),
      "required" => Enum.map(listify(info[:required]), &flag_name/1),
      "positional" => Enum.map(listify(info[:positional]), &flag_name/1),
      "aliases" => alias_map(info[:aliases])
    }
  end

  defp nouns_index(verbs) do
    verbs
    |> Enum.group_by(& &1["noun"], & &1["verb"])
    |> Enum.into(%{}, fn {noun, verb_names} -> {noun, verb_names} end)
  end

  defp chaining_doc do
    %{
      "group_separator" => "++",
      "tokens" => [
        %{
          "token" => "@-",
          "meaning" => "the entire contents of stdin, verbatim (read once per expand/1 call)"
        },
        %{
          "token" => "@-::a.b.c",
          "meaning" => "dotted path into stdin parsed as JSON; a missing path resolves to \"\""
        },
        %{
          "token" => "@{N.path}",
          "meaning" =>
            "dotted path into the JSON envelope of an already-run chained group N (0-based), e.g. @{0.result}; a missing path or out-of-range N resolves to \"\""
        }
      ]
    }
  end

  defp listify(nil), do: []
  defp listify(list) when is_list(list), do: list

  # Schema keys are atoms in OptionParser's underscore form (:profile_id),
  # but the canonical CLI spelling users (and completion scripts) need is
  # the kebab-case long flag (--profile-id) -- the same normalization
  # Dispatcher.apply/2 performs before parsing. Required/positional names
  # reference schema keys, so they follow the same spelling.
  defp flag_name(atom), do: atom |> to_string() |> String.replace("_", "-")

  defp schema_map(nil), do: %{}

  defp schema_map(schema) when is_list(schema) do
    Enum.into(schema, %{}, fn {name, type} -> {flag_name(name), to_string(type)} end)
  end

  defp alias_map(nil), do: %{}

  defp alias_map(aliases) when is_list(aliases) do
    Enum.into(aliases, %{}, fn {short, canonical} ->
      {to_string(short), flag_name(canonical)}
    end)
  end
end
