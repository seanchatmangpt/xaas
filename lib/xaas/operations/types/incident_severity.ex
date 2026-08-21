defmodule Xaas.Operations.Types.IncidentSeverity do
  @moduledoc """
  Real enum, mirroring platform-console's `IncidentSeverity` union.
  """
  use Ash.Type.Enum, values: [:minor, :major, :critical]
end
