defmodule ExNounVerbCli.Chaining do
  @moduledoc """
  Argv preprocessing for command chaining: splits a raw argv list on the
  literal token `"++"` into one argv list per chained invocation, then
  resolves stdin-extraction tokens within each resulting group.

  ## Supported tokens (resolved here)

    * `"@-"` -- replaced with the entire contents of stdin (via
      `IO.read(:eof)`), read once as one raw string argument.
    * `"@-::" <> json_path` (e.g. `"@-::a.b.c"`) -- reads stdin, decodes it
      as JSON (`Jason.decode!/1`), then digs the dot-separated path out of
      the decoded map and stringifies the result.

  Both consume stdin at most once *per call to `expand/1`* -- if a single
  argv group contains more than one stdin-reading token, only the first one
  actually gets stdin's contents; every subsequent stdin-reading token in
  that same call reads from an already-exhausted stream and resolves to an
  empty string. This is a real, documented limitation of a single-process,
  single-stdin-stream model, not a bug hidden from callers.

  ## `@{N.path}` -- resolved BETWEEN groups, not here

  A `"@{N.path}"`-shaped token (referencing a *prior chained group's*
  dispatch envelope, e.g. `"@{0.result}"`) cannot be resolved by
  `expand/1`: expansion runs before any group is dispatched, so no
  envelope exists yet. It is resolved between dispatches by the adapter
  via `resolve_references/2` -- after group N's envelope is known and
  before group N+1 dispatches. Missing paths and out-of-range indexes
  resolve to `""`, the same convention `@-::path` uses for missing stdin
  paths.
  """

  @doc """
  Splits `argv` on the literal token `"++"` into a list of argv groups, then
  resolves `"@-"` / `"@-::json.path"` tokens within each group. With no
  `"++"` present, returns a single-element list containing the (resolved)
  original argv.
  """
  @spec expand([String.t()]) :: [[String.t()]]
  def expand(argv) when is_list(argv) do
    argv
    |> split_groups()
    |> Enum.map(&resolve_group/1)
  end

  @inline_reference_regex ~r/@\{(\d+)\.([^}]+)\}/

  @doc """
  Resolves every `"@{N.path}"` reference in `group` against `envelopes` --
  the already-dispatched chained groups' JSON envelope maps, in order (the
  0-based `N` indexes this list). References work whole-token
  (`"@{0.result}"` → the dug value) and inline
  (`"run-@{0.result}-final"` → `"run-5-final"`), spliced left to right
  with the surrounding bytes kept byte-for-byte -- the same semantics the
  Rust upstream preprocessor's `replace_range` loop implements. `path` is
  a dotted JSON path into one envelope (e.g. `"result"` or
  `"error.code"`); the dug value is stringified with the same rules
  `@-::path` uses (binaries as-is, numbers/booleans via `to_string/1`,
  `nil` → `""`, anything else JSON). A missing path, a non-map mid-path,
  or an out-of-range index resolves to `""` rather than raising, so a bad
  reference surfaces as the next group's ordinary
  invalid-option/missing-option envelope instead of a crashed run.
  Tokens containing brace-like text that does not match the reference
  shape pass through untouched.
  """
  @spec resolve_references([String.t()], [map()]) :: [String.t()]
  def resolve_references(group, envelopes) when is_list(group) and is_list(envelopes) do
    Enum.map(group, &resolve_reference(&1, envelopes))
  end

  defp resolve_reference(token, envelopes) when is_binary(token) do
    Regex.replace(@inline_reference_regex, token, fn _full, index, path ->
      case Enum.at(envelopes, String.to_integer(index)) do
        nil -> ""
        envelope -> envelope |> dig(String.split(path, ".")) |> stringify()
      end
    end)
  end

  defp split_groups(argv) do
    argv
    |> Enum.chunk_by(&(&1 == "++"))
    |> Enum.reject(fn chunk -> chunk == ["++"] end)
    |> case do
      [] -> [[]]
      groups -> groups
    end
  end

  defp resolve_group(group) do
    Enum.map(group, &resolve_token/1)
  end

  defp resolve_token("@-"), do: read_stdin_raw()

  defp resolve_token("@-::" <> json_path) do
    stdin = read_stdin_raw()
    decoded = Jason.decode!(stdin)
    path = String.split(json_path, ".")

    decoded
    |> dig(path)
    |> stringify()
  end

  defp resolve_token(token), do: token

  defp read_stdin_raw do
    case IO.read(:eof) do
      :eof -> ""
      data when is_binary(data) -> data
    end
  end

  defp dig(value, []), do: value

  defp dig(map, [key | rest]) when is_map(map) do
    dig(Map.get(map, key), rest)
  end

  defp dig(_value, _path), do: nil

  defp stringify(value) when is_binary(value), do: value
  defp stringify(value) when is_number(value), do: to_string(value)
  defp stringify(value) when is_boolean(value), do: to_string(value)
  defp stringify(nil), do: ""
  defp stringify(value), do: Jason.encode!(value)
end
