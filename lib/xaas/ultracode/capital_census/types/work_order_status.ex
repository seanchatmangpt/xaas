defmodule Xaas.Ultracode.CapitalCensus.Types.WorkOrderStatus do
  use Ash.Type.Enum, values: [:open, :admitted, :refuted, :resolved]
end
