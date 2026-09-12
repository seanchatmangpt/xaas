defmodule Xaas.Planning.ProblemFeatures do
  @moduledoc """
  Admitted problem-feature record for the planning-regime router
  (`docs/jira/v26.9.11/planning-regime-router.md`).

  This is the "problem-feature ontology" the ticket asks for, expressed as a
  plain typed struct rather than an Ash resource or RDF graph: at this slice
  the router's whole job is to turn an admitted feature set into a formalism
  choice, and there is no persisted/queried state yet that would justify an
  Ash resource. If a durable, queryable problem-feature graph becomes a real
  requirement later, this struct is the seam to project from/to.

  Each field is a boolean admission of one classification axis from the
  ticket's dispatch table. A caller building this struct is asserting these
  features have already been admitted (observed/derived and believed true),
  not asking the router to discover them -- discovery (e.g. real causal
  identification for `empirical_causal?`) is out of scope for this module and
  for this slice; see `Xaas.Planning.RegimeRouter` moduledoc for what is
  UNSUPPORTED.
  """

  @enforce_keys [
    :deterministic?,
    :hierarchical?,
    :nondeterministic?,
    :stochastic?,
    :partially_observed?,
    :constraint_heavy?,
    :optimization?,
    :empirical_causal?
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          deterministic?: boolean(),
          hierarchical?: boolean(),
          nondeterministic?: boolean(),
          stochastic?: boolean(),
          partially_observed?: boolean(),
          constraint_heavy?: boolean(),
          optimization?: boolean(),
          empirical_causal?: boolean()
        }

  @axes @enforce_keys

  @spec axes() :: [atom()]
  def axes, do: @axes

  @doc """
  Builds an admitted `t:t/0` from a map/keyword list of the eight axes.

  Every axis must be present and boolean. Returns a typed error (never
  raises) for missing axes or non-boolean values, so a caller feeding the
  router unvalidated input gets an explicit admission failure instead of a
  `KeyError`/`FunctionClauseError` deep inside classification.
  """
  @spec new(map() | keyword()) :: {:ok, t()} | {:error, {:invalid_problem_features, term()}}
  def new(attrs) do
    attrs = Map.new(attrs)

    missing = Enum.filter(@axes, &(not Map.has_key?(attrs, &1)))

    non_boolean =
      attrs
      |> Map.take(@axes)
      |> Enum.reject(fn {_k, v} -> is_boolean(v) end)
      |> Enum.map(&elem(&1, 0))

    cond do
      missing != [] ->
        {:error, {:invalid_problem_features, {:missing_axes, missing}}}

      non_boolean != [] ->
        {:error, {:invalid_problem_features, {:non_boolean_axes, non_boolean}}}

      true ->
        {:ok, struct!(__MODULE__, Map.take(attrs, @axes))}
    end
  end
end
