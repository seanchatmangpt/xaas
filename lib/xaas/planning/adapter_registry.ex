defmodule Xaas.Planning.AdapterRegistry do
  @moduledoc """
  The "planner capability registry" from the ticket
  (`docs/jira/v26.9.11/planning-regime-router.md`).

  This is a real, checkable registry, not a stub that always claims
  capability: `@adapters` is the literal source of truth for which
  formalisms currently have a real, admitted `Xaas.Planning.Adapter`
  implementation wired in. It is empty on purpose. Building a real PDDL
  planner, a real HDDL/HTN decomposer, a real FOND solver, a real MDP/POMDP
  solver, a real SAT/SMT/CP or LP/MILP/QP solver, or a real SCM/causal
  admission engine is each its own substantial body of work (existing OSS
  solvers should be wrapped, per prior-art-first doctrine, not
  hand-reinvented) and is explicitly out of scope for this slice -- see
  `Xaas.Planning.RegimeRouter` for the UNSUPPORTED contract this registry
  being empty produces end-to-end.

  Registering a real adapter later is exactly: add `{formalism, module}` to
  `@adapters` where `module` implements `Xaas.Planning.Adapter`. Nothing
  else in the router needs to change -- this is the seam the ticket's
  "planner capability registry" component names.
  """

  alias Xaas.Planning.Formalism

  @adapters %{}

  @spec all() :: %{Formalism.t() => module()}
  def all, do: @adapters

  @spec capable?(Formalism.t()) :: boolean()
  def capable?(formalism), do: Map.has_key?(@adapters, formalism)

  @spec adapter_for(Formalism.t()) :: {:ok, module()} | {:error, :no_adapter_registered}
  def adapter_for(formalism) do
    case Map.fetch(@adapters, formalism) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, :no_adapter_registered}
    end
  end
end
