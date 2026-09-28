defmodule Xaas.ResearchRuntime.ExecutionEnvelope do
  @moduledoc false
  def new(subject, evidence, provider) when subject != nil and evidence != nil, do: {:ok, %{subject: subject, evidence: evidence, provider: provider}}
  def new(subject, evidence, provider), do: {:refused, :boundary_violation}
end
