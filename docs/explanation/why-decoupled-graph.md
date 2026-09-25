# Explanation: why the capability layer is decoupled from any graph engine (v26.9.15)

`ex_noun_verb_cli` ships a capability-standing layer —
`ExNounVerbCli.Capability` (packages, proof surfaces, standing
derivation), `ExNounVerbCli.CapabilityRegistry` (dependency closure with
a real topological `dependency_order/1`), both ported field-for-field
from the Rust `clap-noun-verb/src/capability/` modules — but the library
deliberately contains **no RDF engine**: no oxigraph, no `ggen_igniter`
dependency, nothing.

Instead, `ExNounVerbCli.GraphProvider` is a behaviour: whoever needs
capability standing backed by a real graph implements
`load_ontology!/1` + `run_query/2` (or the full callback set) against
the engine of their choice, and supplies it at runtime.

Why:

- **Different release cadences.** `ggen_igniter` (the natural provider)
  carries NIFs, engines, and a heavy dependency tree. Coupling every CLI
  to it would make a toy `greet` binary compile a graph engine. The
  decoupling was proven for real: `ggen-marketplace`'s `marketplace-cli`
  wraps `ggen_igniter`'s real `Ontology.load!/1` + `Query.run/2` behind a
  `GraphProvider`, and its `marketplace_cli.catalog`/`validate` commands
  run the full 318-pack marketplace through this library's dispatch core
  (verified again on 2026-09-15 under elixir 1.20.3 / erlang 28.5.0.2).
- **The port's charter.** The design spec's milestone split keeps
  noun-verb dispatch (milestone 1, this package) independent of graph
  standing (milestone 2, consumer-side composition).
- **Honest dependency hygiene.** The one optional compile-time coupling
  this library has (`:igniter`, for the `Igniter.Mix.Task` adapter) is
  guarded by `Code.ensure_loaded?` precisely so igniter-less consumers
  compile clean — the graph layer gets the same discipline by having no
  coupling at all.
