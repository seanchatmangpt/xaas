defmodule Xaas.Ultracode.ProviderMesh.Selector do
  @moduledoc "Provider mesh runtime primitive."
  alias Xaas.Ultracode.ProviderMesh.{Capability, PrioritySelector}

  def for_capability(cs, cap),
    do: cs |> Enum.filter(&Capability.supported?(&1.module, cap)) |> PrioritySelector.select()
end
