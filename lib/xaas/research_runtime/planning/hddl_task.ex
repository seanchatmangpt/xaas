defmodule Xaas.ResearchRuntime.HddlTask do
  @moduledoc false
  def new(name, methods) when is_binary(name) and is_list(methods), do: {:ok, %{name: name, methods: methods}}
  def new(name, methods), do: {:refused, :boundary_violation}
end
