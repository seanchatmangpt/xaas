defmodule Xaas.Governance.Types.Interface do
  use Ash.Type.Enum, values: [:cli, :api, :mcp, :a2a]
end
