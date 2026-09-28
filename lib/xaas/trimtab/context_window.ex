defmodule Xaas.Trimtab.ContextWindow do
  alias Xaas.Trimtab.{ContextBudget,Observation,Subject}
  @enforce_keys [:subject,:budget]; defstruct [:subject,:budget,observations:[]]
  def new(%Subject{}=s,%ContextBudget{}=b), do: %__MODULE__{subject:s,budget:b}
  def admit(w,o) do
    cond do
      not Observation.exact?(o,w.subject)->{:error,:subject_mismatch}
      ContextBudget.fit?(w.budget,w.observations++[o])->{:ok,%{w|observations:w.observations++[o]}}
      true->{:error,:context_budget_exceeded}
    end
  end
end