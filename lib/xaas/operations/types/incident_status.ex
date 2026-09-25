defmodule Xaas.Operations.Types.IncidentStatus do
  @moduledoc """
  Real enum, mirroring platform-console's `IncidentStatus` union.
  """
  use Ash.Type.Enum, values: [:open, :resolved]
end
