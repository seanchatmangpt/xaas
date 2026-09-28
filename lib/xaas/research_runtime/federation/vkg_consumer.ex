defmodule Xaas.ResearchRuntime.VkgConsumer do
  @moduledoc false
  def consume(binding, query) when binding != nil and query != nil, do: {:ok, %{binding: binding, query: query}}
  def consume(binding, query), do: {:refused, :boundary_violation}
end
