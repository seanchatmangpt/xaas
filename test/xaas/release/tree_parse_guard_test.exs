defmodule Xaas.Release.TreeParseGuardTest do
  @moduledoc """
  v26.9.28 REQ-2: every tracked Elixir source parses under the pinned toolchain.

  Guard for the failure class observed while integrating the v26.9.28 branches:
  machine-generated one-liners (`edge_id:id`, `x!=y`) that only fail at compile.
  """
  use ExUnit.Case, async: true

  @roots ~w(lib test config)

  test "all .ex/.exs files parse" do
    bad =
      for root <- @roots,
          path <- Path.wildcard(Path.join(root, "**/*.{ex,exs}")),
          {:error, {meta, msg, tok}} <- [Code.string_to_quoted(File.read!(path), file: path)] do
        {path, meta[:line], to_string(msg) <> to_string(tok)}
      end

    assert bad == []
  end

  test "no identifier fused to an operator (ident!=x / ident?=x)" do
    fused =
      for path <- Path.wildcard("lib/**/*.{ex,exs}"),
          {line, n} <- path |> File.read!() |> String.split("\n") |> Enum.with_index(1),
          not String.contains?(line, ["\"", "#"]),
          Regex.match?(~r/[A-Za-z0-9_](!=|\?=)[^=]/, line) do
        {path, n}
      end

    assert fused == []
  end
end
