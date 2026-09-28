defmodule Xaas.ResearchRuntime.PolyEvidence do
  @moduledoc false
  def combine(evidence, hypothesis) when is_list(evidence) and evidence != [], do: {:ok, %{evidence: evidence, hypothesis: hypothesis}}
  def combine(evidence, hypothesis), do: {:refused, :boundary_violation}
end
