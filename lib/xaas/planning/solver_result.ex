defmodule Xaas.Planning.SolverResult do
  @moduledoc """
  The "common validation interface" / "solver-result normalization" +
  "common explanation projection" the ticket asks for
  (`docs/jira/v26.9.11/planning-regime-router.md`).

  Every per-formalism adapter (`Xaas.Planning.Adapter` behaviour) that can
  actually solve something must return one of these, regardless of which
  formalism handled it -- this is the shape that stops two adapters from
  returning incompatible result shapes to a shared caller (one of the
  ticket's named falsifiers). At this slice no adapter is registered
  (`Xaas.Planning.AdapterRegistry.all/0` is empty), so this struct currently
  only round-trips through tests exercising the shape itself; it becomes
  load-bearing the moment a real adapter is registered.
  """

  @enforce_keys [:formalism, :status, :explanation]
  defstruct formalism: nil, status: nil, explanation: nil, plan: nil

  @type status :: :solved | :unsolvable | :timeout
  @type t :: %__MODULE__{
          formalism: Xaas.Planning.Formalism.t(),
          status: status(),
          explanation: String.t(),
          plan: term() | nil
        }

  @spec new(Xaas.Planning.Formalism.t(), status(), String.t(), term()) ::
          {:ok, t()} | {:error, {:invalid_solver_result, term()}}
  def new(formalism, status, explanation, plan \\ nil) do
    cond do
      not Xaas.Planning.Formalism.valid?(formalism) ->
        {:error, {:invalid_solver_result, {:unknown_formalism, formalism}}}

      status not in [:solved, :unsolvable, :timeout] ->
        {:error, {:invalid_solver_result, {:unknown_status, status}}}

      not is_binary(explanation) ->
        {:error, {:invalid_solver_result, {:non_binary_explanation, explanation}}}

      true ->
        {:ok,
         %__MODULE__{formalism: formalism, status: status, explanation: explanation, plan: plan}}
    end
  end
end
