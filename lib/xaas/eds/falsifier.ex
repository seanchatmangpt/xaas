defmodule Xaas.Eds.Falsifier do
  @moduledoc """
  A first-class falsifier for an `Xaas.Eds.ExecutableResearchClaim`, per
  `docs/research/executable-design-science.md` Section 9.

  The paper's invariant this module exists to enforce:

      NoExecutableFalsifier => LimitedExecutableStanding

  A falsifier is a deterministic predicate over observed evidence that
  *can* return `:falsified` -- a claim whose falsifier can never fire
  (e.g. `fn _ -> :survived end`) is rejected at construction, because a
  research instrument incapable of producing contradictory evidence is not
  a strong falsifier per the paper's own doctrine.

  ## UNSUPPORTED (real, disclosed gap)

  This module cannot verify that a falsifier predicate is *semantically*
  capable of returning `:falsified` for some real input (that is
  undecidable in general -- see the paper's Section 4.6 on Rice's theorem
  as an epistemic fence). It only rejects the two mechanically detectable
  degenerate cases: a falsifier that is not a 1-arity function, and a
  falsifier explicitly marked `vacuous: true` by its author. A predicate
  that is accidentally always-true in practice, but not marked as such,
  will not be caught here -- that is a real limitation, not glossed over.
  """

  @enforce_keys [:id, :description, :predicate]
  defstruct [:id, :description, :predicate, vacuous: false]

  @type verdict :: :survived | :falsified
  @type t :: %__MODULE__{
          id: String.t(),
          description: String.t(),
          predicate: (map() -> verdict()),
          vacuous: boolean()
        }

  @doc """
  Construct a falsifier. Refuses (returns `{:error, reason}`) rather than
  silently accepting a degenerate, always-passing falsifier.
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(%{id: id, description: description, predicate: predicate} = attrs)
      when is_binary(id) and byte_size(id) > 0 and
             is_binary(description) and byte_size(description) > 0 do
    vacuous = Map.get(attrs, :vacuous, false)

    cond do
      not is_function(predicate, 1) ->
        {:error, "falsifier predicate must be a 1-arity function of observed evidence"}

      vacuous == true ->
        {:error,
         "falsifier explicitly marked vacuous: true -- cannot falsify anything by construction"}

      true ->
        {:ok, %__MODULE__{id: id, description: description, predicate: predicate, vacuous: false}}
    end
  end

  def new(_), do: {:error, "falsifier requires :id, :description, and a 1-arity :predicate"}

  @doc """
  Run the falsifier against observed evidence. Never raises to the
  caller -- an exception inside the predicate is itself evidence
  (a malformed falsifier), surfaced as `{:error, ...}`, not silently
  treated as `:survived`.
  """
  @spec run(t(), map()) :: {:ok, verdict()} | {:error, String.t()}
  def run(%__MODULE__{predicate: predicate}, evidence) when is_map(evidence) do
    case predicate.(evidence) do
      :survived ->
        {:ok, :survived}

      :falsified ->
        {:ok, :falsified}

      other ->
        {:error,
         "falsifier predicate returned #{inspect(other)}, expected :survived or :falsified"}
    end
  rescue
    e -> {:error, "falsifier predicate raised: #{Exception.message(e)}"}
  end
end
