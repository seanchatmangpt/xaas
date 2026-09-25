defmodule ExNounVerbCli.GraphProvider do
  @moduledoc """
  The seam between this library and a real RDF/SPARQL graph engine.

  `ex_noun_verb_cli` never implements a graph engine itself — no oxigraph,
  no `ggen_igniter` dependency, per the approved design's explicit decision
  (see `docs/superpowers/specs/2026-09-11-ex-noun-verb-cli-design.md`,
  section "Graph coupling"). This behaviour is the contract a consumer
  implements to plug in a real engine.

  A conforming consumer implementation might wrap
  `GgenIgniter.Ontology.load!/1` + `GgenIgniter.Query.run/2` (real oxigraph
  NIF-backed SPARQL) behind `load!/1` and `query/2`. This library's own test
  suite instead uses a genuine, tiny, in-memory list-of-triples
  implementation (`ExNounVerbCliTest.Fixtures.InMemoryGraphProvider`) to
  prove the contract is real and callable without pulling in any graph
  engine dependency.

  ## Callbacks

  - `load!/1` — given an opaque, provider-defined `source` (a file path, a
    connection string, an in-memory term, whatever the provider needs), load
    and return an opaque, provider-defined graph handle. Raises on failure —
    callers should treat a raised exception as "the source could not be
    admitted," not catch and continue.
  - `query/2` — given a graph handle returned by `load!/1` and an opaque,
    provider-defined `query` term (e.g. a SPARQL string, or a pattern term
    for a simpler provider), return a list of binding maps. Each map mirrors
    the row shape real SPARQL engines return, e.g.
    `%{"subject" => "...", "predicate" => "...", "object" => "..."}` — string
    keys naming the query's bound variables.
  """

  @typedoc "An opaque, provider-defined graph handle returned by `load!/1`."
  @type graph :: term()

  @typedoc "An opaque, provider-defined query term accepted by `query/2`."
  @type query :: term()

  @typedoc "One result row: a map of bound-variable name to bound value."
  @type binding :: map()

  @doc """
  Loads `source` into a provider-defined graph handle.

  Raises if `source` cannot be admitted (missing file, malformed content,
  unreachable endpoint — whatever "cannot be admitted" means for the
  concrete provider).
  """
  @callback load!(source :: term()) :: graph()

  @doc """
  Runs `query` against `graph` and returns a list of binding maps.

  Returns an empty list when nothing matches — never `nil`, never raises on
  a merely-empty result set.
  """
  @callback query(graph :: graph(), query :: query()) :: [binding()]
end
