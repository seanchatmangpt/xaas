defmodule Xaas.ResearchRuntime.BoundedDo do
  @moduledoc false
  def admit(work, authority) when work.remaining > 0 and authority == :execute, do: {:ok, %{work: work, do: :admitted}}
  def admit(work, authority), do: {:refused, :boundary_violation}
end
