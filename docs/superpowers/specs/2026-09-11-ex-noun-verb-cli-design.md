# `ex_noun_verb_cli` — Design Spec

## 1. Charter

A generator-first (proof-of-concept), better-architected Elixir port of the
useful parts of `~/clap-noun-verb` (a Rust `linkme`+proc-macro noun-verb CLI
framework): compile-time-registered noun/verb dispatch, a declarative arg
schema, JSON-by-default output, command chaining/stdin extraction, and a
capability-standing/RDF-graph layer — with a concrete secondary goal of
displacing real Python tooling in `~/ggen-marketplace`
(`scripts/marketplace.py`, `run-sparql-queries.py`).

This is architectural (new package, new interfaces other code will depend
on) — approved via the brainstorming skill's clarifying-questions process
this session; this document is that approved design, written down before
implementation per the skill's own process (compressed on explicit user
instruction — "ultracode finish the entire project" — rather than a separate
spec-review round-trip).

## 2. Decisions made (from the brainstorming Q&A)

- **Primary use case**: generator-first proof of concept, but designed for
  genuinely better architecture, not a literal port.
- **Dispatch model**: dispatch-agnostic core + two thin adapters (single-binary
  escript, and `Igniter.Mix.Task`) — not locked to either alone.
- **Registration**: generated explicit registry module is the v1-primary
  mechanism (ggen already knows every verb it emits, so no runtime
  reflection is needed for the generator path); a reflection-based fallback
  registry (BEAM module-attribute scan) is a real, but v2, convenience for
  hand-authored verbs.
- **V1 scope** (all in, per explicit selection): noun/verb dispatch +
  declarative arg schema; JSON-by-default output; capability standing / RDF
  graph ops; command chaining + stdin extraction.
- **Location/name**: standalone repo `~/ex_noun_verb_cli`, module
  `ExNounVerbCli`.
- **POC target**: both — a toy `calc add`/`calc multiply` CLI (mirrors
  clap-noun-verb's own README quickstart, proves the core in isolation) AND
  a real `ggen-marketplace` pack generating `marketplace validate`/`catalog`
  noun-verb commands backed by the real oxigraph engine (the actual
  Python-displacement evidence).
- **Graph coupling**: decoupled via a `GraphProvider` behaviour
  (`load!/1`, `query/2`). `ex_noun_verb_cli` itself never depends on
  `ggen_igniter` or the oxigraph NIF — a consumer supplies the
  implementation. `ggen_igniter`-backed implementation lives in the
  consumer (the marketplace-pack POC), not in this library.
- **Arg schema**: reuse `Igniter.Mix.Task.Info`'s exact shape
  (`schema:`/`aliases:`/`positional:`/`required:`), not a new typed DSL —
  one schema struct serves both adapters, no reinvention of validated
  option parsing.

## 3. Architecture

```
lib/ex_noun_verb_cli/
  verb.ex             # Verb struct: noun, verb, module, function, info (Igniter.Mix.Task.Info-shaped map), doc
  registry.ex         # Registry behaviour: list_verbs/0 -> [Verb.t()]
  registry/generated.ex   # v1-primary: a ggen-emitted module implementing Registry
  registry/reflection.ex  # v2 fallback: BEAM module-attribute scan implementing Registry
  dispatcher.ex       # dispatch(registry, argv) :: {:ok, term} | {:error, Error.t()} -- pure, adapter-agnostic
  chaining.ex         # argv preprocessing: `++` split, `@{path}` / `@-` / `@-::json.path` resolution
  json_output.ex      # {:ok, term} | {:error, Error.t()} -> Jason-encodable envelope
  error.ex            # typed Error struct (code, message, detail)
  graph_provider.ex   # behaviour: load!/1, query/2 -- capability-standing hook point, no default impl
  capability.ex       # CapabilityPackage/ProofSurface/Standing, driven via a GraphProvider impl
lib/ex_noun_verb_cli_escript.ex   # single-binary adapter (Mix.install-able escript main/1)
lib/mix/tasks/ex_noun_verb_cli.ex # Igniter.Mix.Task adapter (one task; noun/verb come from positional args)
```

**Data flow**: raw `argv` → `Chaining.expand/1` (split on `++`, resolve
`@{...}`/`@-`/`@-::json.path` references) → for each resulting argv,
`Dispatcher.dispatch/2` (registry lookup by noun/verb → `OptionParser`
validate against the verb's `info` → invoke handler) → `JsonOutput.encode/1`
wraps the result — then each adapter emits it its own way (escript: print to
stdout, exit code from `{:ok,_}`/`{:error,_}`; Igniter adapter: fold into the
`Igniter.t()` being built, since an Igniter task composes rather than prints
and exits).

## 4. Testing

Chicago-style, matching this ecosystem's standing discipline (real
collaborators, state-based assertions, no `Mox`/`Mimic`/`:meck`/`Patch`):

- `Dispatcher`/`Chaining`/`JsonOutput`: pure-function tests against a real,
  small, hand-written `Registry` fixture module (not a mock — a genuine,
  simple implementation of the `Registry` behaviour, same "real object with
  real if simple behavior" distinction this ecosystem's own testing
  discipline docs already draw).
- `GraphProvider`: the core library's own test suite uses a real small
  in-memory graph fixture implementation (kept NIF-free deliberately — this
  library itself never depends on oxigraph). The real `ggen_igniter`-backed
  `GraphProvider` implementation is tested in the *consumer* (the
  marketplace-pack POC's own test suite), which is where a real
  `ggen_igniter` dependency actually belongs.
- Escript adapter: a real `System.cmd` subprocess test.
- Igniter adapter: `Igniter.Test` (this ecosystem's own established pattern
  for testing `Igniter.Mix.Task`s in-memory, no scaffolded project needed).

## 5. Two POC milestones

1. **Toy CLI** — `examples/calc/` inside this repo, `calc add`/`calc
   multiply`, escript adapter only. Proves dispatch + schema + JSON +
   chaining end-to-end in isolation.
2. **Real port** — a new `ggen-marketplace` pack (`packs/noun-verb-cli-pack/`
   or similar) that generates `marketplace validate`/`catalog` as noun-verb
   `Igniter.Mix.Task`s backed by a real `GraphProvider` implementation
   wrapping `GgenIgniter.Ontology.load!/1` + `GgenIgniter.Query.run/2` — the
   concrete Python-displacement evidence for `scripts/marketplace.py`.

## 6. Non-goals for v1

- Dynamic shell completions (clap-noun-verb has this; real but deferred).
- `--introspect` LLM self-description (real but deferred).
- Reflection-based registry as anything but an opt-in convenience — the
  generated-registry path is what's actually exercised/tested in v1.
- Full parity with clap-noun-verb's frontier features (semantic composition,
  economic simulation, quantum-ready crypto-agility, etc.) — those are
  real capabilities in the Rust project but out of scope for this port's
  charter (noun-verb dispatch + JSON + chaining + capability standing).
- Actually publishing to Hex.pm for real — this pass ends at
  `mix hex.publish --dry-run` (a real, verified dry-run build/package step),
  not a real publish.

## 7. Versioning

Following this ecosystem's own CalVer convention (`YY.M.P`, matching
`ggen_igniter`/`ggen-marketplace`): this proof-of-concept ships as `26.9.11`.

> **Release amendment (2026-09-15).** The `26.9.11` date-version was the
> scaffold only and was never published. The design shipped publicly as
> **v26.9.15** — the first release on Hex.pm — carrying this charter plus
> the post-scaffold fixes recorded in `CHANGELOG.md` (Igniter
> global-option stripping, the optional-Igniter compile guard, the
> CapabilityRegistry port, snake_case flag aliases, and the
> always-serializable error envelope). This document remains the design
> charter; the Diataxis doc set under `docs/` is the release-era
> documentation.
