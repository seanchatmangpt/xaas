defmodule Xaas.Ultracode.CapitalCensus.Experience do
  @moduledoc """
  Machine experience and the inverse-experience index of the Capital
  Census (GC-26926-CENSUS, `docs/sjira/v26.9.26/GC-26926-CENSUS.md`).
  Everything here is a pure function over plain data: no DB, no model
  runs; the OCEL wiring lands separately.

  ## The experience law

  Experience is the 5-tuple (State, Action, Observation, Outcome,
  Evidence); `new/5` builds it as a plain map with the atom keys
  `:state`, `:action`, `:observation`, `:outcome`, `:evidence`.
  `failure_class/1` derives a stable class key from the tuple's outcome
  and action shape: the same logical failure yields the same key
  whatever its observation or evidence, so repeats of one reasoning
  failure are countable. The system-defect law:

      RepeatedFailureReasoning > 1 => SystemDefect

  `system_defect?/1` is that law as a predicate over experience tuples:
  true iff some failure class occurs strictly more than once (2+
  occurrences). Exactly one occurrence is a single failure, not a
  defect -- the boundary is `> 1`, never `>= 1`. First witnessed
  instance: the 2026-09-26 burn-in NULL-worktree / gate-refusal failure,
  promoted same-day once the repeated reasoning failure was named a
  system defect rather than an operator task.

  ## The inverse-experience index (IEC)

  IEC_n is the set of capability keys still requiring model inference.
  The removal criterion is a repeat work order in the same class
  demonstrating `I(W2) < I(W1)` -- the second cycle consumes the first
  cycle's promoted capital, measured as fewer LLM reasoning hops, not
  just success -- and the index law:

      IEC_{n+1} = IEC_n - Promoted(Capital_n)

  `advance/2` is the law; `deficit/1` (the surviving set's size) is the
  retirement metric: a FALLING IEC is the census working -- capability
  capital retiring LLM reasoning into deterministic machinery, cycle
  over cycle -- and `deficit/1 == 0` is `Gap = empty`, LLM reasoning 0
  for that scope. The set only ever shrinks through `advance/2`; nothing
  here re-adds a capability (a regression would be a new cycle's
  finding, not this function's business).
  """

  # The outcome value that marks a reasoning failure. Both spellings the
  # tuples in this family carry are normalized through `outcome_key/1`.
  @failure_outcome "failure"

  @type t :: %{
          required(:state) => term(),
          required(:action) => term(),
          required(:observation) => term(),
          required(:outcome) => term(),
          required(:evidence) => term()
        }

  @type capability :: term()
  @type index :: MapSet.t(capability()) | [capability()]

  @doc """
  The experience tuple: `(State, Action, Observation, Outcome, Evidence)`
  as a plain map keyed `:state`, `:action`, `:observation`, `:outcome`,
  `:evidence`. Values are opaque; only `:outcome` and `:action` shape
  the failure class.
  """
  @spec new(term(), term(), term(), term(), term()) :: t()
  def new(state, action, observation, outcome, evidence) do
    %{
      state: state,
      action: action,
      observation: observation,
      outcome: outcome,
      evidence: evidence
    }
  end

  @doc """
  The stable class key of an experience tuple: `"outcome:action-shape"`
  (e.g. `"failure:mix_compile"`, `"alive:format_check"`). Deterministic
  in the tuple's `:outcome` and `:action` alone -- state, observation
  and evidence never move the key -- so the same reasoning failure seen
  twice lands in one countable class. The action shape is the binary or
  atom action itself; anything else is its `inspect/1` rendering.
  """
  @spec failure_class(t()) :: String.t()
  def failure_class(%{outcome: outcome, action: action}),
    do: outcome_key(outcome) <> ":" <> action_shape(action)

  @doc """
  The system-defect law, `RepeatedFailureReasoning > 1 => SystemDefect`,
  over a collection of experience tuples: true iff any failure class
  (`failure_class/1` of tuples whose outcome marks a failure) occurs
  strictly more than once. Successes are never counted; two failures of
  DIFFERENT classes are still no defect.
  """
  @spec system_defect?(Enumerable.t()) :: boolean()
  def system_defect?(tuples) do
    tuples
    |> failure_counts()
    |> Map.values()
    |> Enum.any?(&(&1 > 1))
  end

  @doc """
  The failure-class counts `system_defect?/1` judges: one entry per
  failure class present among the tuples, its value the number of
  reasoning-failure occurrences of that class. The inspectable half of
  the law -- the classes and their repeat counts.
  """
  @spec failure_counts(Enumerable.t()) :: %{String.t() => pos_integer()}
  def failure_counts(tuples) do
    tuples
    |> Enum.filter(&(outcome_key(&1.outcome) == @failure_outcome))
    |> Enum.frequencies_by(&failure_class/1)
  end

  @doc """
  The index law, `IEC_{n+1} = IEC_n - Promoted(Capital_n)`: `iec_n` (a
  MapSet or list of capability keys still requiring model inference)
  minus exactly the `promoted` capability keys. Promoted keys absent
  from the index are no-ops; nothing else in the index moves. Returns a
  MapSet.
  """
  @spec advance(index(), Enumerable.t()) :: MapSet.t(capability())
  def advance(iec_n, promoted),
    do: MapSet.difference(to_set(iec_n), MapSet.new(Enum.map(List.wrap(promoted), &key/1)))

  # Capability keys arrive as atoms (~w()a) or the binary spelling of one;
  # a binary promotes only an existing atom (never fabricates one).
  defp key(k) when is_atom(k), do: k

  defp key(k) when is_binary(k) do
    try do
      String.to_existing_atom(k)
    rescue
      ArgumentError -> k
    end
  end

  defp key(k), do: k

  @doc """
  The census's retirement metric: how many capability keys still require
  model inference (`MapSet` size of `index`). Falling cycle over cycle
  is the census working; 0 is LLM reasoning 0 for the scope.
  """
  @spec deficit(index()) :: non_neg_integer()
  def deficit(index), do: MapSet.size(to_set(index))

  # ---------------------------------------------------------------------------

  defp outcome_key(outcome) when is_atom(outcome) and not is_nil(outcome),
    do: Atom.to_string(outcome)

  defp outcome_key(outcome) when is_binary(outcome), do: outcome
  defp outcome_key(outcome), do: inspect(outcome)

  defp action_shape(action) when is_binary(action), do: action

  defp action_shape(action) when is_atom(action) and not is_nil(action),
    do: Atom.to_string(action)

  defp action_shape(action), do: inspect(action)

  defp to_set(%MapSet{} = set), do: set
  defp to_set(list) when is_list(list), do: MapSet.new(list)
  defp to_set(nil), do: MapSet.new()
end
