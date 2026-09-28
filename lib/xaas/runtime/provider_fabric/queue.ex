defmodule Xaas.Runtime.ProviderFabric.Queue do
  @moduledoc "Provider fabric queue primitive."
  defstruct items: :queue.new()
  def push(q,x), do: %{q|items: :queue.in(x,q.items)}
    def size(q), do: :queue.len(q.items)
end
