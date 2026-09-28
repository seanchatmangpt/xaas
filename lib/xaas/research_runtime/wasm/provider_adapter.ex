defmodule Xaas.ResearchRuntime.ProviderAdapter do
  @moduledoc false
  def route(request, provider) when provider != nil, do: {:ok, %{request: request, provider: provider}}
  def route(request, provider), do: {:refused, :boundary_violation}
end
