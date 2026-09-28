defmodule Xaas.Runtime.ProviderFabric.Circuit do
  @moduledoc "Provider fabric circuit primitive."
  defstruct failures: 0, threshold: 3
  def fail(c), do: %{c|failures: c.failures+1}
    def open?(c), do: c.failures>=c.threshold
end
