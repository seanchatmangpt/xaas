defmodule Xaas.Ultracode.CapitalCensus.Types.RecurrenceClass do
  use Ash.Type.Enum,
    values: [
      :semantic,
      :structural,
      :procedural,
      :nondeterministic,
      :projection,
      :routing,
      :observation,
      :selection,
      :verification,
      :runtime
    ]
end
