defmodule Xaas.ResearchRuntime.GenerationFence do
  @moduledoc false
  def admit(receipt_epoch, active_epoch) when receipt_epoch == active_epoch, do: {:ok, :same_generation}
  def admit(receipt_epoch, active_epoch), do: {:refused, :boundary_violation}
end
