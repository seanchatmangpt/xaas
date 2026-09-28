defmodule Xaas.ResearchRuntime.PromotionPolicy do
  @moduledoc false
  def decide(delta, threshold) when is_number(delta) and is_number(threshold), do: {:ok, if(delta >= threshold, do: :promote, else: :refuse)}
  def decide(delta, threshold), do: {:refused, :boundary_violation}
end
