defmodule Xaas.ResearchRuntime.Event do
  @moduledoc false
  def new(id, object_ids) when id != nil and is_list(object_ids), do: {:ok, %{id: id, objects: object_ids}}
  def new(id, object_ids), do: {:refused, :boundary_violation}
end
