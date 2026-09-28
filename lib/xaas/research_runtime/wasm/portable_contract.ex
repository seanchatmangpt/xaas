defmodule Xaas.ResearchRuntime.PortableContract do
  @moduledoc false
  def new(abi, capabilities) when is_binary(abi) and is_list(capabilities), do: {:ok, %{abi: abi, capabilities: capabilities}}
  def new(abi, capabilities), do: {:refused, :boundary_violation}
end
