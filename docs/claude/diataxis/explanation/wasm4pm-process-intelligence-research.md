# wasm4pm / wasm4pm-compat and process intelligence in Ash

Research note for GitHub issue #19. Grounded in real local repositories read
directly on this machine on 2026-08-20, plus a real web search for any public
upstream. This is an explanation document: it describes what these projects
actually are and what a real integration path would look like. It does not
implement anything.

## What was actually searched

- `find ~ -maxdepth 3 -iname "*wasm4pm*"` — many real hits.
- `WebSearch "wasm4pm process mining"` — no public project by this name;
  returned an unrelated npm package (`@aarkue/process_mining_wasm`, built on
  the `rust4pm`/`process_mining` Rust crate) and general PM4Py literature.
- `WebSearch "wasm4pm-compat github"` — no public repository found. Results
  were all unrelated WASM-4 (the fantasy game console) projects, a namespace
  collision with this project's own name.

**Conclusion on public/upstream existence: UNVERIFIED — likely does not
exist as a public project.** `wasm4pm` and `wasm4pm-compat` are private,
locally-developed repositories authored by this machine's own user (Sean
Chatman), not a third-party or published open-source process-mining engine.
The Cargo manifest for `wasm4pm` names `repository =
"https://github.com/seanchatmangpt/wasm4pm"` and `wasm4pm-compat` names
`https://github.com/seanchatmangpt/wasm4pm-compat"`, but the web search found
neither indexed — the repos may be private/unpublished as of this research.
Treat any claim that this is a known/adopted community process-mining stack
as **UNSUPPORTED**.

## What wasm4pm actually is (from its own README, `~/wasm4pm`)

wasm4pm is described in its own README as "an evidence-oriented
process-mining platform implemented in Rust, WebAssembly, and TypeScript."
Concretely, from the real README and `Cargo.toml`:

- A public `wpm` CLI (TypeScript, in `apps/wasm4pm`, wrapping a WASM core)
  that discovers and validates process models, operates on XES and
  object-centric (OCEL) event data, executes POWL (partially-ordered
  workflow language) routes, and produces "replayable evidence" (signed
  receipts of what ran).
- A Rust workspace (`crates/wasm4pm-cli`, `wasm4pm-cognition`, `prolog8`,
  `ocpq`, `miniml-core`, `wasm4pm-planner`, `wasm4pm-bindings-py`, etc.) at
  version `26.7.23`, license `BUSL-1.1` (Business Source License — not a
  permissive OSS license).
- Its README states its own standing plainly: **"the Vision 2030
  implementation graph is present, but global standing is `PARTIAL_ALIVE`
  until the complete workspace, real Node-target WASM session, exact
  release certificate, signed AAT-Live bundle, and required exact-head CI
  all execute and replay against one immutable commit."** That is the
  project's own self-assessment, not this document's inference.
- OCEL support is explicit and narrow: the README states "OCEL-v1 and OCEL
  NDJSON remain typed unsupported on this composition root until equivalent
  WASM routes exist" — only **OCEL v2 JSON** has a working WASM route
  (`wpm evidence session <file> --object-type <Type>`).

## What wasm4pm-compat actually is (from its own README, `~/wasm4pm-compat`)

`wasm4pm-compat` (v26.8.7) is explicitly **not** an engine. Its own README
states this in a dedicated "What this Crate IS NOT" section:

> Not a lite wasm4pm... Not an engine... Not a conformance checker (it does
> not compute fitness, precision, generalization, or trace alignment
> scores; it only models their static verdict structures)... Not a
> replay/discovery engine (it does not execute discovery algorithms such as
> Alpha, Inductive, or Heuristics miners, or replay logs against models).

It is a **structure-only, nightly-Rust-only** typestate library: a
compile-time lifecycle (`Raw → Parsed → Admitted → {Projected, Exportable,
Receipted}`) for process-mining data shapes (OCEL 2.0, XES 1849, Petri
nets/WF-nets, BPMN, POWL, process trees, Declare, OCPQ, conformance
verdicts), with typed refusal enums (e.g. OCEL admission enforces "no
dangling event-object links," "no duplicate object IDs," "qualified
object-object relations require a non-empty qualifier") instead of runtime
parse errors. It requires nightly Rust (`#![feature(generic_const_exprs,
adt_const_params, const_trait_impl, min_specialization, portable_simd)]`,
per its own README) and forbids `unsafe`.

Its own README is explicit that real OCEL admission exists for a concrete
type (`LinkedOcel`, admitting into `Admission<LinkedOcel, Ocel20>` or a
typed `Refusal<OcelRefusal, Ocel20>`), but this crate never computes
process-mining results — it only validates shape and hands validated data
to something else (by design, "graduation" to `wasm4pm` proper).

## What Ash and this codebase already emit

`Xaas.Telemetry.OcelAshEmitter` (`~/xaas/lib/xaas/telemetry/ocel_ash_emitter.ex`,
read directly, 176 lines) is real, running code in this repo. It attaches to
Ash's real `:telemetry` `:stop` events (confirmed against Ash's own source
in its moduledoc, not assumed) for every configured Ash domain and the four
CRUD action types, and on each event appends one JSON-OCEL record to
`priv/ocel/ash-actions.ndjson` with real fields:

```
"ocel:eid"       => Ash.UUIDv7.generate()
"ocel:activity"  => "#{resource_short_name}.#{action}"
"ocel:timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
"ocel:omap"      => [to_string(resource_short_name)]
"ocel:vmap"      => %{...enriched via Ash.Resource.Info...}
```

This is the real OCEL 2.0 JSON-per-line event shape (`ocel:eid`,
`ocel:activity`, `ocel:timestamp`, `ocel:omap`, `ocel:vmap`), not a bespoke
schema — the same field names wasm4pm's OCEL v2 WASM route and
wasm4pm-compat's `LinkedOcel`/`Ocel20` witness expect at the record level.
The module's own moduledoc is honest about a real limitation: Ash emits
only `:stop`, never a distinguishable `:exception` event, so every record's
outcome is "ran to completion of the span" — success/failure cannot
currently be told apart from this log alone.

## How this could realistically integrate

Two real seams exist, both consistent with what each project's own docs
say it is for:

1. **wasm4pm as an OCEL v2 consumer of the Ash NDJSON log.** wasm4pm's
   `wpm evidence session` route takes an OCEL v2 **JSON** file (object with
   `ocel:events`/`ocel:objects`, not raw NDJSON lines) and an
   `--object-type`. `ash-actions.ndjson` is newline-delimited single event
   records, not a full OCEL v2 document (it has no `ocel:objects` array or
   `ocel:global-log` header, and it is NDJSON rather than one JSON object).
   A real integration would need a conversion step — wrap the per-line
   events into a proper OCEL v2 JSON document (synthesizing `ocel:objects`
   from the distinct `ocel:omap` values seen) — before wasm4pm's WASM route
   would accept it. This conversion does not exist today; it would be new
   work, not a plug-in.
2. **wasm4pm-compat as a structural admission gate.** Before any such file
   is handed to wasm4pm's engine, wasm4pm-compat's `LinkedOcel` admitter
   could validate it (no dangling event-object links, no duplicate object
   IDs) and produce a typed `Refusal<OcelRefusal, Ocel20>` on malformed
   data instead of a runtime crash deeper in the pipeline. This is
   consistent with the crate's stated purpose but requires calling into a
   **nightly-only Rust crate** — a real toolchain constraint for any Elixir
   codebase, since it would have to go through a NIF/port/WASM boundary,
   not a native Elixir dependency.

Neither of these is "an Ash extension" in the Ash-framework sense (there is
no `Ash.Resource` extension, transformer, or DSL entity defined by either
wasm4pm project for Ash specifically — that idea does not appear anywhere
in either README, and nothing in this codebase implements it).

## Honest recommendation

- **Do not claim a working wasm4pm/Ash integration exists.** None does.
  `OcelAshEmitter` produces OCEL-shaped NDJSON; nothing in this repo or in
  `~/wasm4pm`/`~/wasm4pm-compat` reads that file today.
- **If pursued**, the smallest real next step is a converter (Elixir or a
  small script) that batches `priv/ocel/ash-actions.ncjson` lines into a
  proper OCEL v2 JSON document on demand, then hand-verify `wpm evidence
  session <that file> --object-type <Type>` against it once, and read the
  actual CLI output — not assume the route accepts NDJSON as-is.
- **wasm4pm's own README already says its global standing is
  `PARTIAL_ALIVE`**, gated on its own release-certificate and CI evidence,
  independent of any Ash integration. Any dependency taken on it inherits
  that standing, not a mature/stable one.
- **wasm4pm-compat's nightly-only Rust requirement and `BUSL-1.1`/dual
  license terms on wasm4pm proper are real adoption costs** to weigh before
  committing, not incidental details.
- No public/upstream `wasm4pm` or `wasm4pm-compat` project was found by web
  search; this is entirely a local, same-author toolchain, so there is no
  external community or maintenance guarantee to lean on.

**Bottom line: UNVERIFIED that a public wasm4pm/wasm4pm-compat project
exists; UNSUPPORTED that any working integration with Ash currently
exists.** The real local wasm4pm and wasm4pm-compat repositories are real,
substantial, self-authored process-mining tooling with an honest
self-reported `PARTIAL_ALIVE` standing, and a real (if currently
unconnected) OCEL v2 shape match with this codebase's real
`OcelAshEmitter` output — but connecting them is unbuilt work, not a
documentation gap.
