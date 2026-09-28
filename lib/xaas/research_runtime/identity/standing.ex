defmodule Xaas.ResearchRuntime.Standing do
  @moduledoc false
  def classify(receipt, authority) when receipt != nil and authority != nil, do: {:ok, %{receipt: receipt, authority: authority, standing: :candidate}}
  def classify(receipt, authority), do: {:refused, :boundary_violation}
end
