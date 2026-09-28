defmodule Xaas.Ultracode.CapitalCensus.Types.GapStatus do
  use Ash.Type.Enum, values: [:hypothesis, :admitted, :refuted]
end
