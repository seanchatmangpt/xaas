defmodule Xaas.ResearchRuntime.OsirisBoundary do
  @moduledoc false
  def steer(context, authority) when authority in [:none, :construct], do: {:ok, %{context: context, authority: authority, do: false}}
  def steer(context, authority), do: {:refused, :boundary_violation}
end
