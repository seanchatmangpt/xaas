defmodule Xaas.Operations.Types.IncidentPostmortemStatus do
  @moduledoc """
  Real enum, mirroring platform-console's real postmortem draft/final states.
  """
  use Ash.Type.Enum, values: [:draft, :final]
end
