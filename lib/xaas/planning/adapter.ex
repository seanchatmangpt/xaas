defmodule Xaas.Planning.Adapter do
  @moduledoc """
  Behaviour every per-formalism adapter
  (`docs/jira/v26.9.11/planning-regime-router.md` -- "per-formalism adapters"
  and "common validation interface") must implement to be registered in
  `Xaas.Planning.AdapterRegistry`.

  No module implements this behaviour yet in this slice -- see
  `Xaas.Planning.RegimeRouter` moduledoc for why a real PDDL/HDDL/FOND/MDP/
  POMDP/SAT-SMT-CP/LP-MILP-QP/SCM solver is explicitly UNSUPPORTED here
  rather than faked.
  """

  @doc "Validates a raw problem term is well-formed for this formalism, before solving."
  @callback validate(problem :: term()) :: :ok | {:error, term()}

  @doc "Solves an already-validated problem and returns a normalized `Xaas.Planning.SolverResult.t()`."
  @callback solve(problem :: term()) :: {:ok, Xaas.Planning.SolverResult.t()} | {:error, term()}
end
