defmodule Xaas.Fabric.Contract do
  @moduledoc """
  Semantic declaration of a capability. A realization is implementation; this is semantics.
  Two realizations of one URI are interchangeable (QRI) iff `qri_key/1` is equal.
  """

  @effect_rank %{observe: 0, select: 1, construct: 2, do: 3}

  @enforce_keys [:uri, :semantic_id, :realization, :effect_class]
  defstruct [
    :uri,
    :semantic_id,
    :realization,
    :effect_class,
    accepted_subjects: [],
    invariants: [],
    refusal_conditions: [],
    evidence_requirements: []
  ]

  @type effect_class :: :observe | :select | :construct | :do
  @type t :: %__MODULE__{}

  @spec qri_key(t()) :: tuple()
  def qri_key(%__MODULE__{} = c),
    do: {c.uri, c.semantic_id, c.effect_class, Enum.sort(c.invariants), Enum.sort(c.evidence_requirements)}

  @doc "A capability may only be driven up to its declared effect class."
  @spec permit(t(), effect_class()) :: :ok | {:error, {:authority_refusal, String.t()}}
  def permit(%__MODULE__{effect_class: declared}, op) do
    if @effect_rank[op] <= @effect_rank[declared],
      do: :ok,
      else: {:error, {:authority_refusal, "#{op}_EXCEEDS_#{declared}"}}
  end
end
