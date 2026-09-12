defmodule Xaas.Planning.Formalism do
  @moduledoc """
  The fixed formalism vocabulary from the ticket's classification -> dispatch
  table (`docs/jira/v26.9.11/planning-regime-router.md`, Scope section).

  This is intentionally a closed atom enum, not an open string/atom any
  caller can invent -- the router's admission predicates and the adapter
  registry (`Xaas.Planning.AdapterRegistry`) both key off this exact set, so
  keeping it closed here is what makes "unsupported formalism" a real,
  checkable admission failure instead of a typo silently falling through.
  """

  @type t ::
          :pddl
          | :hddl_htn
          | :fond
          | :ppddl_mdp
          | :pomdp
          | :sat_smt_cp
          | :lp_milp_qp
          | :scm_causal

  @all [
    :pddl,
    :hddl_htn,
    :fond,
    :ppddl_mdp,
    :pomdp,
    :sat_smt_cp,
    :lp_milp_qp,
    :scm_causal
  ]

  @spec all() :: [t()]
  def all, do: @all

  @spec valid?(term()) :: boolean()
  def valid?(formalism), do: formalism in @all
end
