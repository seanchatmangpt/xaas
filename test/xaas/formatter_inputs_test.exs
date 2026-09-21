defmodule Xaas.FormatterInputsTest do
  @moduledoc """
  Guard for the `mix format --check-formatted` gate (xaas#56).

  `.formatter.exs` builds its `:inputs` with `Path.wildcard/2`. `Path.wildcard/1` skips
  dotfiles while `Mix.Tasks.Format` expands with `match_dot: true`, so a rewrite that
  dropped `match_dot: true` silently removed `.formatter.exs` and `.dialyzer_ignore.exs`
  from the gate and hid an unformatted `.formatter.exs`. Real files on disk, state-based
  assertions, no doubles.
  """
  use ExUnit.Case, async: true

  @root_dotfiles [".formatter.exs", ".dialyzer_ignore.exs"]

  defp formatter_opts do
    {opts, _bindings} = Code.eval_file(".formatter.exs")
    opts
  end

  test "root dotfiles stay inside the formatter inputs" do
    inputs = Keyword.fetch!(formatter_opts(), :inputs)

    for dotfile <- @root_dotfiles do
      assert File.regular?(dotfile), "#{dotfile} is expected at the repo root"
      assert dotfile in inputs, "#{dotfile} dropped out of the format gate"
    end
  end

  test "generated projection stays outside the formatter inputs" do
    inputs = Keyword.fetch!(formatter_opts(), :inputs)

    generated =
      Enum.filter(inputs, &String.starts_with?(&1, "lib/xaas/generated/"))

    assert generated == []
    assert length(inputs) > 100
  end

  test "root dotfiles are themselves formatted" do
    for dotfile <- @root_dotfiles do
      source = File.read!(dotfile)
      formatted = source |> Code.format_string!() |> IO.iodata_to_binary()

      assert formatted <> "\n" == source, "#{dotfile} is not mix-format clean"
    end
  end
end
