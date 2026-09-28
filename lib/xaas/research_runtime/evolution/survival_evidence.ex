defmodule Xaas.ResearchRuntime.SurvivalEvidence do
  @moduledoc false
  def score(successes, failures) when successes + failures > 0, do: {:ok, successes / (successes + failures)}
  def score(successes, failures), do: {:refused, :boundary_violation}
end
