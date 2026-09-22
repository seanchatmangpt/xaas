defmodule Xaas.Actuation.Refusal do
  @moduledoc """
  Typed machine refusal raised by a consequential action's own admission court.

  An action that is reached through `Xaas.Actuation.run/4` may refuse the DO after the
  control plane has already admitted the intent (its own policy court found a violated
  condition). Returning this error from the action -- as a changeset/action-input error --
  makes `Xaas.Actuation.Kernel.seal/2` record the intent and receipt as `:refused`
  (a status both resources already declare) instead of the generic `:failed`, so a
  refusal is distinguishable from an execution fault in the durable ledger.

  Classified `:forbidden`: a refusal is a policy outcome, not a validation typo.
  """

  use Splode.Error, fields: [:code, :detail], class: :forbidden

  @type t :: %__MODULE__{code: atom(), detail: term()}

  def message(%{code: code, detail: detail}),
    do: "actuation refused (#{code}): #{inspect(detail)}"

  @doc "Builds a refusal error value."
  @spec new(atom(), term()) :: t()
  def new(code, detail \\ nil) when is_atom(code), do: exception(code: code, detail: detail)

  @doc "Finds the first `Xaas.Actuation.Refusal` in an Ash error class (or a bare error)."
  @spec find(term()) :: t() | nil
  def find(%__MODULE__{} = refusal), do: refusal
  def find(%{errors: errors}) when is_list(errors), do: Enum.find_value(errors, &find/1)
  def find(_other), do: nil

  @spec refusal?(term()) :: boolean()
  def refusal?(term), do: find(term) != nil
end
