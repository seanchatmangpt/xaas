defmodule Xaas.Ultracode.CapitalCensus.Types.ResolutionOutcome do
  use Ash.Type.Enum, values: [:resolved, :refuted, :blocked]
end
