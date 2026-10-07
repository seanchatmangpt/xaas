# W639 — SHACL → WASM typestate feasibility (WP-6 follow-on)

Standing: PARTIAL_ALIVE (feasibility assessment; no implementation)
Lane: W639, v26.10.7 fleet seal. Read-only lane; no code changed.

## Receipt

- Subject: branch `feat/playwright-surface` @ f3911592 (working tree, read-only).
- Date: 2026-10-07.
- Method: read-only grounding in the wasi-json-abi-pack generated artifacts
  + W615's AIRO SHACL profile and generator. No compile, no test, no commit.
- μ/diff: none (no code changed). Generated-vs-handwritten: n/a.

## Grounding evidence (exact files read)

Pack: `~/ggen-marketplace/packs/wasi-json-abi-pack/generated/graphlaw/`
- `guards.rs` (54 lines): guard prelude for `graphlaw-wasm`. Contains exactly
  three items: `json_depth/1` (allocation-free JSON-depth limit check),
  `op_index/2` and `error_code_index/2` (table-ordering helpers). **No
  typestate machinery exists** — no state-parameterized types, no transition
  traits, no pre/post-condition encoding. Guards are plain validation
  functions rendered from `queries/guards.rq` over closed-set ontology facts
  (`wja:errorStyle`, `wja:maxJsonDepth`, limits), with a disclosed
  UNSUPPORTED(generator-capability) residue (refusal envelope stays
  hand-written per `HANDWRITTEN-graphlaw.md`).
- `capability-registry.json`: exports `gl_alloc` / `gl_call` / `gl_free`;
  error codes {NotSemanticContent, Ambiguous, EngineRejected, Unsupported,
  ResourceLimit}; ops include `shacl` (`{data, shapes} → {conforms,
  results}`) and `law` (`{data, steps, signed_lease, ...} → {states,
  receipts, nquads}`).
- `op-examples.json` line 54: the `law` op example is literally a two-step
  pipeline — an n3 rules step followed by a `shacl` step. This is the
  pack's existing guard-sequence mechanism.

AIRO side (xaas):
- `priv/airo/profile.shacl.ttl` (W615-generated, 47 NodeShapes; 3 compiled
  PropertyShape constraints documented in the generator moduledoc).
- `lib/mix/tasks/xaas.airo.compile_shacl.ex`: AIRO 1.0 vocabulary
  (`priv/semantic/airo/airo.ttl`, sha256 6274d2d8…) → SHACL profile, with a
  hand-rolled `violations/1` court because **no SHACL validator exists in
  the Elixir dependency tree** (RDF.ex 3.0.1 + SPARQL only).

## Verdict

**PARTIALLY REALIZABLE**, split by constraint:

| # | Constraint | Verdict | Carrier |
|---|---|---|---|
| 1 | RiskControl binds ≥1 risk concept (sh:or of forward minCount 1) | REALIZABLE | guest-side `op:"shacl"` in the graphlaw reactor |
| 2 | Risk cited ≥1 control via inverse paths (sh:or of sh:inversePath minCount 1) | REALIZABLE | guest-side `op:"shacl"` |
| 3 | rdfs:seeAlso file:// citation existence | NOT realizable guest-side | stays host-side (`check_file_citations/1`) |

- **Not realizable as literal Rust typestates.** The directive's "compile
  AIRO shapes into WebAssembly typestates" does not match the pack: guards.rs
  has no typestate encoding. The nearest real mechanism is the `law` op's
  step pipeline (n3 → shacl steps inside one `gl_call`), which is a
  guard-sequence, not a typestate. Recommend the follow-up lane adopt the
  guard-sequence reading, not the typestate reading.
-  **Constraints 1 and 2 are already SHACL-expressible** (W615 emitted them as
  sh:or/minCount/inversePath PropertyShapes), and the graphlaw reactor
  already implements `op:"shacl"` and `op:"law"` with a `step:"shacl"` inside
  one gl_call. So guest-side SHACL admission = pass profile.shacl.ttl as the
  `shapes` argument. No new guard class needed — the existing `shacl` op IS
  the guard class. Constraint 3 needs host filesystem access; WASI
  preview1 sandbox has no such import, so it stays host-side
  (`check_file_citations/1`).
- **TTL remains the human-readable projection.** profile.shacl.ttl is the
  byte-for-byte `shapes` argument text — generated artifact keeps its role as
  the auditable projection of airo.ttl; the WASM reactor consumes it as data,
  no hand-editing on either side.

## Minimal design (if the follow-up lane builds it)

1. Keep `xaas.airo.compile_shacl` as the sole generator; profile.shacl.ttl
   stays the projection surface.
2. At admission time, host packages the admission request as an `op:"law"`
   call: steps = [ {step:"shacl", shapes: profile.shacl.ttl text, data:
   instance graph} ], via the packed-u64 gl_call convention
   (ontology.ttl:241), error-style `refusal-kind`.
3. Host-side `check_file_citations/1` runs after the law call returns
   conforms:true, unchanged.
4. Court: differential court — the in-tree hand-rolled `violations/1` and the
   guest-side shacl op must agree on a corpus of conforming/violating
   instance graphs (agreement = ALIVE; disagreement = typed REFUSED with
   focus + constraint). This reuses C14 "one admission kernel" (DfCM catalog)
   differential-admission falsifier.

## Standing

PARTIAL_ALIVE: the feasibility claim is grounded in read artifacts on disk
at f3911592; the guest-side SHACL op surface (op:shacl/op:law) is ALIVE in
the pack registry, but no differential court has witnessed AIRO admission
through the reactor — that is exactly what the follow-up lane must
manufacture. No implementation was performed; the assessment gates a
follow-up lane.

## Falsifier for the follow-up lane

A conforming instance graph admitted by `violations/1` but rejected (or a
violating graph admitted) by `op:"shacl"` with profile.shacl.ttl as shapes —
or constraint 3 attempted guest-side — kills this design.
