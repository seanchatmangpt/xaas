defmodule ExNounVerbCliTest.Support.InMemoryGraphProvider do
  @moduledoc """
  A genuine, tiny, real implementation of `ExNounVerbCli.GraphProvider` —
  deliberately not oxigraph, not `ggen_igniter`, and not a mock: it
  actually performs a linear scan over an in-memory list of `{subject,
  predicate, object}` triples and returns real binding maps, the same shape
  a real SPARQL engine would return for a single-triple-pattern query.

  Exists to prove the `GraphProvider` behaviour contract is real and
  callable from this library's own test suite without depending on any
  graph engine, per the approved design's "Graph coupling" decision.
  """

  @behaviour ExNounVerbCli.GraphProvider

  @typedoc "A subject/predicate/object triple."
  @type triple :: {subject :: term(), predicate :: term(), object :: term()}

  @typedoc """
  A triple pattern to match against: each position is either a literal
  value to match exactly, or `:_` (wildcard, matches anything).
  """
  @type pattern :: {subject :: term() | :_, predicate :: term() | :_, object :: term() | :_}

  @impl ExNounVerbCli.GraphProvider
  @doc """
  Loads `source` (a list of `triple/0`) unchanged as the graph handle.
  """
  @spec load!([triple()]) :: [triple()]
  def load!(source) when is_list(source), do: source

  @impl ExNounVerbCli.GraphProvider
  @doc """
  Runs a real linear scan of `graph` against `query` (a `pattern/0`),
  returning one binding map per matching triple with string keys
  `"subject"`, `"predicate"`, `"object"` — mirroring the row-map shape
  real SPARQL engines return.
  """
  @spec query([triple()], pattern()) :: [map()]
  def query(graph, {subject_pattern, predicate_pattern, object_pattern}) when is_list(graph) do
    graph
    |> Enum.filter(fn {subject, predicate, object} ->
      matches?(subject_pattern, subject) and
        matches?(predicate_pattern, predicate) and
        matches?(object_pattern, object)
    end)
    |> Enum.map(fn {subject, predicate, object} ->
      %{"subject" => subject, "predicate" => predicate, "object" => object}
    end)
  end

  defp matches?(:_, _value), do: true
  defp matches?(pattern, value), do: pattern == value
end
