defmodule Xaas.Governance.Types.CapabilityClass do
  use Ash.Type.Enum, values: [:observe, :select, :construct, :do]
end
