defmodule Xaas.Planning.RegimeRouter do
  @moduledoc """
  Planning-regime router: dispatch admitted problems to the narrowest formal
  planner class (`docs/jira/v26.9.11/planning-regime-router.md`).

  ## What this slice actually implements (ALIVE)

  - The problem-feature ontology (`Xaas.Planning.ProblemFeatures`).
  - The formalism vocabulary (`Xaas.Planning.Formalism`).
  - Formalism-admission predicates: `classify/1` below, applying the
    ticket's exact classification -> dispatch table in the ticket's own
    listed priority order (a feature set is classified by the first axis in
    that order that is true; ties are not silently ambiguous -- they resolve
    to the ticket's stated order, and that resolution is itself asserted by
    a real test).
  - The planner capability registry (`Xaas.Planning.AdapterRegistry`).
  - The common validation interface / solver-result normalization /
    explanation projection (`Xaas.Planning.Adapter`, `Xaas.Planning.SolverResult`).
  - `dispatch/2`: the one concrete admission/validation path. It classifies,
    checks the registry, and either calls a real registered adapter or
    returns a typed `{:error, {:unsupported, formalism, reason}}` -- never
    silently falls through to a default/general-purpose planner. This is
    the ticket's key invariant ("the router itself performs no planning --
    it selects the lawful machinery") and its last-listed falsifier ("an
    unsupported problem feature is silently routed to a planner instead of
    a typed unsupported/refused result").
  - `Xaas.Planning.RegimeRouterStep`: a real `Reactor.Step` wiring
    `dispatch/2` into the existing Ash/Reactor boundary this repo uses for
    admitted control-plane work.

  ## What this slice explicitly does NOT implement (UNSUPPORTED)

  `Xaas.Planning.AdapterRegistry.all/0` is empty. No real PDDL planner, no
  real HDDL/HTN decomposer, no real FOND solver, no real PPDDL/MDP or POMDP
  solver, no real SAT/SMT/CP or LP/MILP/QP solver, and no real SCM/causal
  identification engine is implemented here. Each is a substantial body of
  work in its own right (and, per this repo's prior-art-first doctrine,
  should wrap an existing established solver/library rather than be
  hand-rolled) and is out of scope for this bounded slice. `dispatch/2`
  reflects this honestly: every formalism currently returns
  `{:error, {:unsupported, formalism, "no adapter registered - real solver not yet implemented"}}`
  rather than a fabricated plan or a silent fallback to some other planner.
  """

  alias Xaas.Planning.{AdapterRegistry, Formalism, ProblemFeatures}

  @doc """
  Classifies an admitted `t:Xaas.Planning.ProblemFeatures.t/0` into the
  narrowest formalism, per the ticket's dispatch table, in the ticket's
  listed priority order:

      deterministic -> :pddl
      hierarchical -> :hddl_htn
      nondeterministic -> :fond
      stochastic -> :ppddl_mdp
      partially_observed -> :pomdp
      constraint_heavy -> :sat_smt_cp
      optimization -> :lp_milp_qp
      empirical_causal -> :scm_causal

  Returns `{:error, :no_admitted_formalism}` when no axis is set -- an
  all-false feature set is not silently defaulted to any formalism.
  """
  @spec classify(ProblemFeatures.t()) :: {:ok, Formalism.t()} | {:error, :no_admitted_formalism}
  def classify(%ProblemFeatures{} = features) do
    cond do
      features.deterministic? -> {:ok, :pddl}
      features.hierarchical? -> {:ok, :hddl_htn}
      features.nondeterministic? -> {:ok, :fond}
      features.stochastic? -> {:ok, :ppddl_mdp}
      features.partially_observed? -> {:ok, :pomdp}
      features.constraint_heavy? -> {:ok, :sat_smt_cp}
      features.optimization? -> {:ok, :lp_milp_qp}
      features.empirical_causal? -> {:ok, :scm_causal}
      true -> {:error, :no_admitted_formalism}
    end
  end

  @doc """
  Classifies `features`, then either dispatches `problem` to a real
  registered adapter for that formalism, or returns a typed unsupported
  result. The router itself never plans -- it only selects and, if
  available, invokes lawful machinery.
  """
  @spec dispatch(ProblemFeatures.t(), term()) ::
          {:ok, Xaas.Planning.SolverResult.t()}
          | {:error, :no_admitted_formalism}
          | {:error, {:unsupported, Formalism.t(), String.t()}}
          | {:error, {:invalid_problem, Formalism.t(), term()}}
          | {:error, term()}
  def dispatch(%ProblemFeatures{} = features, problem) do
    with {:ok, formalism} <- classify(features) do
      case AdapterRegistry.adapter_for(formalism) do
        {:ok, module} ->
          with :ok <- module.validate(problem) do
            module.solve(problem)
          else
            {:error, reason} -> {:error, {:invalid_problem, formalism, reason}}
          end

        {:error, :no_adapter_registered} ->
          {:error,
           {:unsupported, formalism, "no adapter registered - real solver not yet implemented"}}
      end
    end
  end
end
