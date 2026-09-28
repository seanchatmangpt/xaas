defmodule Xaas.ResearchRuntime.OcelWaveTest do
  @moduledoc false
  def case(receipt_subject, active_subject) when receipt_subject != active_subject, do: {:ok, :refuse_replay}
  def case(receipt_subject, active_subject), do: {:refused, :boundary_violation}
end
