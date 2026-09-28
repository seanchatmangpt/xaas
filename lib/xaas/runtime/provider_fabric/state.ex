defmodule Xaas.Runtime.ProviderFabric.State do
  @moduledoc "Provider fabric state primitive."
  defstruct phase: :ready, attempt: 0
  def dispatch(s), do: %{s | phase: :dispatching, attempt: s.attempt + 1}
end
