defmodule Xaas.Runtime.ProviderFabric.Receipt do
  @moduledoc "Provider fabric receipt primitive."
  defstruct subject: nil, attempts: [], outcome: nil
  def build(s,a,o), do: %__MODULE__{subject: s,attempts: a,outcome: o}
end
