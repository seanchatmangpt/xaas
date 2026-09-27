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
