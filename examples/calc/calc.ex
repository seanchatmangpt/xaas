defmodule ExNounVerbCli.Examples.Calc do
  @moduledoc """
  Toy verb handlers for the `calc` noun -- the Milestone 1 proof-of-concept
  from the design spec, mirroring clap-noun-verb's own README quickstart
  (`calc add`/`calc multiply`). Real, if trivial, handler functions: not a
  mock, not a fixture -- this is the actual example CLI shipped under
  `examples/calc/`.
  """

  @doc "Adds `x` and `y`."
  @spec add(number(), number()) :: number()
  def add(x, y), do: x + y

  @doc "Multiplies `x` and `y`."
  @spec multiply(number(), number()) :: number()
  def multiply(x, y), do: x * y
end
