defmodule Xaas.SelfDigest.Gap do
  @enforce_keys [:subject, :claim, :falsifier]
  defstruct [:subject, :claim, :falsifier, :priority, :evidence, :dependencies, status: :open]

  def new(subject, claim, falsifier, opts \\ []) do
    %__MODULE__{
      subject: subject,
      claim: claim,
      falsifier: falsifier,
      priority: Keyword.get(opts, :priority, 0),
      evidence: [],
      dependencies: Keyword.get(opts, :dependencies, [])
    }
  end

  def rank(gap) do
    (gap.priority || 0) * 100 + length(gap.evidence || []) * 5 -
      length(gap.dependencies || []) * 10
  end

  def admit(gap, evidence), do: %{gap | evidence: evidence, status: :admitted}
  def refuse(gap, reason), do: %{gap | status: {:refused, reason}}
end
