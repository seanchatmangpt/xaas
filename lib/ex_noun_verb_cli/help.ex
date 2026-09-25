defmodule ExNounVerbCli.Help do
  @moduledoc """
  Human-readable help as a pure projection of the introspection
  manifest -- the same data `--introspect` returns, rendered for people.
  No help string exists in this library that the manifest does not imply
  (an ARD falsifier).
  """

  @doc """
  Renders plain-text help for `command` from `manifest`
  (`ExNounVerbCli.Introspect.manifest/1` output): usage, the per-noun
  command table (verb, doc, options with types and required markers,
  positional names), and the chaining quick reference from the
  manifest's own `chaining` section.
  """
  @spec render(map(), String.t()) :: String.t()
  def render(manifest, command) do
    supported = manifest["chaining"]

    [
      """
      Usage:
        #{command} <noun> <verb> [options]
        #{command} --introspect [<noun>]
        #{command} --help [<noun>]
        #{command} --completions <bash|zsh|fish>
      """,
      command_table(manifest),
      chaining_reference(supported)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp command_table(manifest) do
    manifest["nouns"]
    |> Map.keys()
    |> Enum.sort()
    |> Enum.map(fn noun ->
      rows =
        manifest["verbs"]
        |> Enum.filter(&(&1["noun"] == noun))
        |> Enum.map(&verb_row/1)

      [noun <> ":", rows]
    end)
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp verb_row(record) do
    doc_line = if record["doc"] != "", do: ["         #{record["doc"]}"], else: []
    options = options_line(record)
    positional = positional_line(record)

    [
      "  #{pad(record["verb"])}#{positional}",
      doc_line,
      options
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 == ""))
  end

  defp options_line(record) do
    case Enum.map(record["schema"], fn {flag, type} ->
           suffix = if flag in record["required"], do: " (required)", else: ""
           "--#{flag} <#{type}>#{suffix}"
         end) do
      [] -> []
      options -> ["         options: " <> Enum.join(options, "  ")]
    end
  end

  defp positional_line(record) do
    case record["positional"] do
      [] -> ""
      names -> " <" <> Enum.join(names, "> <") <> ">"
    end
  end

  defp chaining_reference(chaining) do
    tokens =
      Enum.map(chaining["tokens"], fn %{"token" => token, "meaning" => meaning} ->
        "  #{pad(token)}#{meaning}"
      end)

    """
    Chaining (#{chaining["group_separator"]} separates groups):
    #{Enum.join(tokens, "\n")}
    """
  end

  defp pad(text), do: String.pad_trailing(text, 12)
end
