defmodule Xaas.Runtime.ProviderFabric.Outcome do
  @moduledoc "Provider fabric outcome primitive."
  defstruct status: :pending, value: nil
  def ok(v), do: %__MODULE__{status: :ok,value: v}
end
