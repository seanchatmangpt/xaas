# GC-26927-SELFDIGEST — Ultracode as a work subject of itself

- **standing:** UNKNOWN (directive seeded 2026-09-27; kernel implemented, loop not yet wired end-to-end)
- **operator directive (verbatim-critical):** $U_t \in Subjects(U_t)$ — Ultracode observes, models, falsifies, and reconstructs its own capability-selection machinery on the same rails it applies to every other repository.

## The closed loop (target)

```
Work → Resolution → Execution → OCEL → Experience → Gap → Work_self → U_{t+1}
```

(current chain is open: `Work → Resolve → Compose → Generate → Frontier → Verify` — no Experience→Gap→Work_self return edge).

## Metric

$R_t = \dfrac{\text{frontier work}}{\text{total required work}}$, drive $\dfrac{dR}{dt} < 0$.

$RepeatedFrontier(x) \Rightarrow MissingCapability(x) \lor MissingComposition(x) \lor MissingGenerator(x) \lor MissingResolverRule(x)$ — recurrence auto-creates self-work.

## Recurrence classification G (each class names its primitive target)

| class | primitive target |
|---|---|
| semantic | ontology |
| structural | marketplace pack |
| procedural | HDDL |
| nondeterministic | FOND |
| projection | ggen |
| routing | SA2A |
| observation | beam4pm / OCEL |
| selection | resolver |
| verification | court |
| runtime | OTP / Ash / Reactor |

## Fixed boundary: Judge ≠ Candidate

Never $U_t \rightarrow mutate(U_t\ running)$. Path:
$U_t \xrightarrow{CONSTRUCT} U'_{t+1} \xrightarrow{shadow/replay} Evidence \xrightarrow{promotion} U_{t+1}$.
The currently admitted factory remains the judge of the candidate factory until promotion. (This is the same shape the wave loop already enforces: workers construct; the admitted loop settles; config promotion requires restart.)

## Five-layer hierarchy

$L_0$ execute known · $L_1$ compose known · $L_2$ manufacture missing projection · $L_3$ invent missing capability · $L_4$ improve $L_{0..3}$ — **and $L_4$ uses $L_{0..3}$** (no separate self-improvement subsystem).

## Optimization target

$\min \dfrac{\text{new reasoning required}}{\text{new capability delivered}}$. Durable object: $Knowledge_{t+1} = Knowledge_t + compress(FrontierExperience_t)$. When Ultracode itself repeatedly requires LLM reasoning, that is evidence of an unmechanized part of Ultracode.

---

## Self-ticket format (sJira = the semantic representation of factory ignorance)

```text
Observed:      <n> work orders required equivalent handwritten <X>
Expected:      existing semantic capabilities should have been composable
Residual:      <the missing primitive, one sentence>
Classification: <G class>
Candidate repair: <manufacture <primitive>>
Falsifier:     replay the <n> historical episodes
Success:       >= n-2 resolve without frontier coding
```

## History

| ts | standing | note |
|---|---|---|
| 2026-09-27T19:40Z | UNKNOWN | directive received; kernel `Xaas.Ultracode.CapitalCensus.SelfDigest` implemented (classify/1 per G-table, frontier_ratio/2, self_work_order/1); first self-ticket seeded from real evidence below |
| 2026-09-27T21:05Z | UNKNOWN | operator correction 1: 4a2e9d1 is a spike, not implementation — hardcoded G-table = semantic duplication; tests prove constants; threshold ≥3; classify is hypothesis→conclusion; keep only frontier_ratio |
| 2026-09-27T21:20Z | UNKNOWN | operator correction 2: Ash is the runtime spine — Ontology → ggen → Ash → SA2A/PPlan → Reactor/Oban → OCEL; resources/actions as generated Ash; RDF > generated Ash |
| 2026-09-27T21:45Z | UNKNOWN | operator correction 3: not packs for apps — consumer-owned project pack, not marketplace; search existing packs first (pack-search ledger in pack README) |
| 2026-09-27T22:05Z | UNKNOWN | operator correction 4: compose Ash's OWN generators (ash.gen.enum/ash.gen.resource/ash.extend) via a thin bridge — no bespoke Ash-DSL templates; ash_r2rml = the RDF projection leg; ash_oban = the digest trigger |
| 2026-09-27T22:20Z | PARTIAL_ALIVE | **first self-improvement landed**: `priv/ggen/ultracode-self-digest-pack` (ontology + queries + Facts template + qualification); generic bridge `mix xaas.ash.gen`; 6 enums + 5 resources + domain registration + Facts MANUFACTURED; handwritten spike + tests DELETED (−213 lines); Law/Run/bridge/manifest ledgered (+4 rows); Chicago 7/7 on real PG, regression 107/107, regeneration court byte-clean; salvage-committed as 0a4e1a0a by concurrent merge-day executor; receipt: receipts/2026-09-27-selfdigest-retirement-receipt.json |

## REMAINING

- AshOban digest trigger: `ash.extend Episode` + scheduled_action (cron) running the Law digest — no LLM, no external runner.
- sJira markdown as PROJECTION of the WorkOrder graph (AshR2RML mapping → SPARQL, or render_tickets over Ash reads); GC-26927-SELFDIGEST.md itself stops being canonical the moment that projection exists.
- Resolver second-order tickets: `Xaas.Ultracode.CapabilityResolver` self-audit when ≥3 episodes share topology (Law.classify drives it; wiring pending).
- Shadow/replay promotion path for factory changes (construct $U'$ → historical replay → adversarial → shadow → promote).
- Subsume census `Experience` pure law into the Ash spine (Episode naming failed edge recorded in pack README).
- ex4pm 26.9.10 upstream (compile_env fix already proven in deps/ patch) — unblocks ggen_igniter sync verify gate for every xaas pack; hex publish operator-gated.
- Promote `xaas.ash.gen` bridge to a generic marketplace pack (separate admission; ledgered as debt until then).

## Self-ticket #1 — semantic_crown cold-replay toolchain (real evidence, already typed)

```text
Observed:       3 repair attempts on the cold-replay toolchain resolution each
                falsified in turn (Hex reinstall, deps re-fetch, _build rebuild);
                9 ultracode tests red in the corrupt-atom-table family.
Expected:       the asdf shim in SemanticCrown.mix_bin/0 should resolve the pinned
                toolchain for cold-replay work_dirs without operator intervention.
Residual:       no mechanism carries the ggen_igniter .tool-versions pin into
                work_dirs materialized by git archive.
Classification: runtime (OTP/Ash/Reactor) — with an observation-class
                co-defect (the replay must instrument the resolved mix context
                before the next repair guess).
Candidate repair: SemanticCrown materializes .tool-versions into the work_dir
                at archive time + echoes `which mix; mix --version` into the
                task output; then re-falsify.
Falsifier:      MIX_BUILD_ROOT=_build-int mix test test/xaas/ultracode/semantic_replay_test.exs
Success:        9/9 green on two consecutive runs without environment surgery.
```

## REMAINING

- Wire Experience→Gap: mine OCEL exports for frontier episodes at run close (currently manual).
- Resolver second-order tickets: `Xaas.Ultracode.CapabilityResolver` self-audit when ≥3 episodes share topology.
- Shadow/replay promotion path for factory changes (construct $U'$ → historical replay → adversarial → shadow → promote).
