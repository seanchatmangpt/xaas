# Pre-flight decisions: xaas_ocel_envelope_pack

Batch: pre-flight decisions gating `priv/packs/xaas_ocel_envelope_pack/` authoring. No pack
files exist yet as of this doc. All six decisions below are resolved before any pack file is
written.

## 1. Scope

Generate **only** a pure envelope-field-shape module: schema/producer/sequence/events keys,
one typespec per field. Explicitly OUT of scope for generation (stays in
`lib/xaas/telemetry/ocel_forwarder.ex`, hand-written):

- `Req.post` / any HTTP call
- timeout/URL configuration
- status-code branching
- `Logger.warning`/rescue policy
- `run_id` `persistent_term` memoization
- the Ash-telemetry/reactor-undo trigger wiring

## 2. Ontology-path resolution: VENDOR, do not cross-repo-point

Confirmed: `ex4pm.ttl` / `ex4pm-shapes.ttl` (at
`/Users/sac/ex4pm/priv/ontology/ex4pm.ttl`, `/Users/sac/ex4pm/priv/shacl/ex4pm-shapes.ttl`,
HEAD `725f495eb90d32a1582e6f44c08151d07743b784` as of 2026-09-09) contain **zero**
classes/shapes for envelope/schema/producer/sequence. The only real, grounded fragment is:

```turtle
ex4pm:Event a rdfs:Class ; rdfs:subClassOf ex4pm:Observation .
ex4pm:activity a rdf:Property ; rdfs:domain ex4pm:Event ; rdfs:range xsd:string .
ex4pm:timestamp a rdf:Property ; rdfs:domain ex4pm:Event ; rdfs:range xsd:dateTime .
ex4pm:relatesObject a rdf:Property ; rdfs:domain ex4pm:Event ; rdfs:range ex4pm:Object .

ex4pm:EventShape a sh:NodeShape ;
  sh:targetClass ex4pm:Event ;
  sh:property [ sh:path ex4pm:activity ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ] ;
  sh:property [ sh:path ex4pm:timestamp ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:dateTime ] .
```

Decision: **vendor** this fragment into `priv/packs/xaas_ocel_envelope_pack/ontology.ttl`,
disclosed with a header comment stating it is a vendored subset of
`/Users/sac/ex4pm/priv/ontology/ex4pm.ttl` + `/Users/sac/ex4pm/priv/shacl/ex4pm-shapes.ttl`
as of commit `725f495eb90d32a1582e6f44c08151d07743b784` (2026-09-09), NOT a live cross-repo
pointer. Reasons: (a) an absolute `--ontology /Users/sac/ex4pm/...` path is non-reproducible
in CI/other machines; (b) this pack's own `agp:CodegenTarget` individuals driving the
mix-task phases must live in the same single `ontology.ttl` a sync invocation reads — a real
cross-repo `--ontology` pointed at ex4pm's file cannot also see those facts in the same run;
(c) mix.lock carries no ex4pm pin at all, so a live pointer has no drift detection — a
vendored fragment is under xaas's own git history and diffable like any other file.

## 3. Generatable vs. hand-authored split

**GENERATE** (bound to real SHACL facts, deliberately divergent typing stated inline):

- `activity :: String.t()` — direct from `ex4pm:EventShape`'s `xsd:string` constraint.
- `timestamp :: String.t()` — **NOT** `DateTime.t()` despite `xsd:dateTime` in the SHACL
  shape. Every real producer (`OcelAshEmitter`, `forward_cancellation`, the hand-authored
  session-activity path, `OcelNotifier`) emits ISO8601 strings, never parsed `DateTime`
  structs. The divergence from the vendored SHACL datatype is intentional and stated as a
  `@doc`/comment on the field, not silently reconciled.
- `omap`, `vmap`, `relatesObject`-derived fields — always-present (never `nil`-optional),
  since every real producer always emits the key.

**HAND-AUTHOR** (co-located in the pack's template as static heredoc content, same pattern as
`xaas_library_pack`'s Ash resource bodies — never derived from SPARQL bindings, since no RDF
fact exists to bind):

- `schema` — constant `"xaas.ocel.v2"`.
- `producer` — shape `%{agent_id: ..., run_id: ...}`.
- `sequence` — non-negative integer, zero ontology backing.

## 4. vmap / omap shape policy

- `vmap :: map()` — **open** map, not a closed struct or tagged union. The ontology gives
  zero grounding for any of the four real producer shapes in this codebase
  (`OcelAshEmitter`'s 9-key CRUD-action shape, `forward_cancellation`'s 5-key shape, the
  hand-authored session-activity 5-key shape, `OcelNotifier`'s attributes/relationships
  shape). Encoding a false-closed union would break any real producer on its next unlisted
  field. Do not attempt to encode the 4-way union.
- `omap :: list(String.t())` — always-present list of **type-name strings**, matching what
  real producers actually emit. This is a stated divergence from `ex4pm:relatesObject`'s
  actual semantics (an Event→Object *instance* reference), documented explicitly in the
  generated module's `@moduledoc`.

## 5. Output module identity and location

Generate a **new, separate** module: `Xaas.Telemetry.OcelEnvelope`
(`lib/xaas/telemetry/ocel_envelope.ex`). Never inject into or overwrite
`lib/xaas/telemetry/ocel_forwarder.ex` (same-file-collision risk). `OcelForwarder.do_forward/2`
is then **hand-edited** (not generated) to call `Xaas.Telemetry.OcelEnvelope.build/1` in place
of its inline map literal.

## 6. Idempotency mode

Use `ggen_igniter`'s real `Actuate.write_file!` frontmatter guard
`unless_exists: true` (confirmed present in `deps/ggen_igniter/lib/ggen_igniter/actuate.ex`),
not xaas_library_pack's ad hoc `File.exists?` guard-in-generated-code (base phase) or
unconditional-overwrite (core phase) patterns. This ensures a hand-edited generated file is
never silently clobbered on resync.

## Concurrent-workflow check (CLAUDE.md Agent Scoping rule)

Checked before starting: no live workflow process found (`ps aux` scan for
workflow/mix-xaas processes — none touching `lib/xaas/telemetry/`, `lib/xaas/actuation.ex`,
or `mix.exs`). No `/workflows` UI available to this subagent to cross-check the tracked
workflow queue directly; the process-level check is the evidence available in this
environment. Per the batch instructions and `~/xaas/CLAUDE.md`, this batch itself does not
touch `lib/xaas/actuation*`, `lib/xaas/library/reactors/`, `lib/xaas/library/explainer*`, or
`groq_adapter.ex` — those remain untouched regardless.

## Status

All six decisions resolved and written above. No pack files, no `ontology.ttl`, no generated
module, and no edit to `ocel_forwarder.ex` have been created in this batch — per the batch
charter ("no code yet"). Next batch authors `priv/packs/xaas_ocel_envelope_pack/` against
these decisions.
