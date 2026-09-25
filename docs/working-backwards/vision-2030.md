# ExNounVerbCli — Vision 2030

**Repository:** `seanchatmangpt/ex_noun_verb_cli`
**Ecosystem role:** dispatch contract for every pack-rendered CLI
**Depends on:** nothing (leaf library; consumers bind it to registries and, optionally, `:igniter`)
**Standing conferred:** `UNKNOWN` (a contract is proven per-boundary, not globally).

## The one-sentence vision

By 2030, every executable surface the Chatman Ecosystem manufactures —
every ggen pack projection, every generated CLI, every agent tool that
shells out — speaks one dispatch contract: **noun-verb argv in, one
always-serializable JSON envelope out, with a machine-readable
self-description on tap**.

## Why this library exists

The Rust `clap-noun-verb` proved the ergonomics: verbs as data,
composition as syntax. The Elixir port exists because the ecosystem's
manufacturing pipeline (ggen-marketplace packs → ggen_igniter → Igniter
generators) needs the *same contract where the generators live* — and
because a `linkme`-distributed slice cannot be rendered by a template.

## The 2030 end-state

1. **The manifest is the interface.** `--introspect` output is the
   canonical description of any pack-rendered CLI; help text, shell
   completions, MCP tool schemas, and test harnesses are all
   projections of it. No surface ships hand-written documentation that
   the manifest does not imply.
2. **The envelope is the protocol.** Every result — success, expected
   failure, chained array — is one JSON shape. An agent that parses one
   envelope parses every CLI in the ecosystem, forever.
3. **Composition is token-level.** Chaining (`++`), stdin extraction
   (`@-`, `@-::path`), and cross-group value threading (`@{N.path}`,
   inline or whole-token) make multi-step workflows single invocations.
   The 2030 target adds nothing new here; it makes what exists
   unfalsifiably correct.
4. **Authority stays where it belongs.** The library dispatches; it
   never gains ambient production authority. Capability standing stays
   decoupled behind `GraphProvider` so the contract stays installable
   everywhere while the ecosystem's RDF machinery advances
   independently.
5. **Zero-dependency core, optional everything.** A consumer with no
   `:igniter` and no graph engine compiles clean and ships a working
   binary. Optionality is a tested contract, not a claim.

## What v26.9.16 contributes to the vision

The discovery leg is completed: manifest (v26.9.15) plus help and shell
completions (v26.9.16) as projections of the same data; composition
gains token-level inline references. After v26.9.16, the remaining
distance to the 2030 end-state is held in the ecosystem's other repos
(packs that render registries, providers that stand behind
`GraphProvider`), not in this contract.

## Non-goals on the road to 2030

- Full clap-noun-verb frontier parity (semantic composition, economic
  simulation, quantum-ready crypto-agility) — real capabilities, but
  they belong to the Rust surface until a pack needs their projection.
- An RPC/MCP server in this library — serving is a deployment surface
  (`clap-noun-verb-deploy` upstream), not a dispatch contract.
- A second documentation catalog — this file and its siblings are the
  only strategy layer; everything user-facing projects from the
  manifest.
