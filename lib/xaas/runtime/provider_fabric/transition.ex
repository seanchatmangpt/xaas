defmodule Xaas.Runtime.ProviderFabric.Transition do
  @moduledoc "Provider fabric transition primitive."
  defstruct from: nil, to: nil

  def allowed?(t),
    do:
      {t.from, t.to} in [
        {:ready, :dispatching},
        {:dispatching, :recovering},
        {:dispatching, :complete},
        {:dispatching, :exhausted}
      ]
end
