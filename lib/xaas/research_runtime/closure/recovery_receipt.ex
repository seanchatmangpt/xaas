defmodule Xaas.ResearchRuntime.RecoveryReceipt do
  @moduledoc false
  def seal(subject, failed_edge) when subject != nil and failed_edge != nil, do: {:ok, %{subject: subject, failed_edge: failed_edge, action: :exclude_and_reselect}}
  def seal(subject, failed_edge), do: {:refused, :boundary_violation}
end
