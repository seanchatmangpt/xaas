defmodule Xaas.SelfDigest.Gap do
  @enforce_keys [:subject, :claim, :falsifier]
  defstruct [:subject, :claim, :falsifier, :priority, :evidence, :dependencies, status: :open]
  def new(subject, claim, falsifier, opts \\ []), do: %__MODULE__{subject: subject, claim: claim, falsifier: falsifier, priority: Keyword.get(opts,:priority,0), evidence: [], dependencies: Keyword.get(opts,:dependencies,[])}
  def rank(g), do: (g.priority || 0) * 100 + length(g.evidence || []) * 5 - length(g.dependencies || []) * 10
  def admit(g, evidence), do: %{g | evidence: evidence, status: :admitted}
  def refuse(g, reason), do: %{g | status: {:refused, reason}}
end
