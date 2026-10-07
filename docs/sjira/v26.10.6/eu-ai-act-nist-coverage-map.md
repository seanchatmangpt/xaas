# EU AI Act / NIST AI RMF Coverage Map — v26.10.6

Lane W319, 2026-10-06; refreshed by lane W409, 2026-10-06 (this week's landed
evidence folded in; every number re-verified against the cited receipts).
Repo `/Users/sac/xaas` @ `feat/playwright-surface`.
Document only: maps existing receipts/evidence to regulatory clauses. No code, no tests.
Evidence base: the v26.10.6 refusal-coverage corpus (`_CLOSURE_PLAN.md` §2/§2.1; w176
recount; w236 capstone — 86 tests / 12 files / 0 failures, delta 0, 62/62 refusal tokens);
A2A v1 conformance 26/26 CONFORMANT (w385, HEAD `07180bd3`, in-repo pinned court corpus —
NOT the official A2A TCK); anti-vacuity mutation rounds w320 (4/6 killed) and w382-r2
(landed 2026-10-06: 2/3 killed, 1 new typed gap); structurally-unreachable list +1
(`vkg.ex:52` VKG dead clause, w378 — total 2 typed unreachable variants).

Consumer: the CRO loop (`docs/cro/CRO-LOOP.md`) is the commercial-motion consumer of
this map — it converts this evidence corpus into pipeline (EU AI Act / Caremark /
GCP Marketplace EDP accounts). This map is the loop's Art. 12/14/15 evidence source.

## 1. EU AI Act

### Art. 12 — Record-keeping

| Clause | Requirement (gist) | Evidence artifact(s) | Verdict |
|---|---|---|---|
| 12(1) automatic event recording | Machine-readable record of AI-system events | OCEL NDJSON telemetry (`lib/xaas/telemetry/ocel_ndjson.ex`); receipts under `docs/sjira/v26.10.6/plans/` (w236, w176, w13, w183, w270) | EVIDENCED |
| 12(1)-(3) traceability over lifetime | Replayable per-actuation trace | w236 capstone (per-file counts, verbatim run output); castle checkpoint digest/evidence-path gates (`lib/xaas/castle.ex:456-460`) | EVIDENCED |
| 12(b) traceability incl. refused actuation | Each consequential DO — and each refusal — carries identity + consequence | Actuation refusal atoms (`lib/xaas/actuation.ex:537-547,770`); w13 receipt: exact mismatch tuples, pre==post state asserted; w379 witness test: forged internally-consistent foreign `{intent, receipt}` pair is ADMITTED by `checkpoint_external/2` (inverted gap, tracked as OS-18) | EVIDENCED (refusal-as-logged-consequence); identity clause is a known inverted gap (OS-18), honestly disclosed |
| 12(3) logs available to authorities | Exportable log surface + retention policy | Doc-level machine-readable export now exists: `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json` (62 variants, per-variant sites/fixtures/unreachable reasons, mutant-kill evidence, subject-pinned HEAD `d1db2b03`); still no automated runtime export API or retention artifact | PARTIAL — narrowed `GAP(NO_RUNTIME_EXPORT_API)` (was `GAP(NO_AUTHORITY_EXPORT_SURFACE)`; doc-level export landed, automated surface still open) |

### Art. 14 — Human oversight

| Clause | Requirement (gist) | Evidence artifact(s) | Verdict |
|---|---|---|---|
| 14(1) effective oversight | BRCE admission before any consequential DO; refusal surfaced as typed tuple | `lib/xaas/actuation.ex:537-547,770`; `test/xaas/actuation_refusal_negative_test.exs` 6/6 (w13, w121, w236; +w379 forged-pair witness) | EVIDENCED (with OS-18 inverted gap disclosed) |
| 14(4)(a) understand capacities/limits | Typed-refusal surface is machine-readable; no threshold judgement needed | 62/62 refusal tokens with exact-token negative fixtures (w176/w202/w236); `_CLOSURE_PLAN.md` §2.1 | EVIDENCED |
| 14(4)(b) correctly interpret output | Refusal = signed consequence, not exception | w13 verbatim gate output; w236 per-file counts; actuation tests assert exact tuples + pre==post state | EVIDENCED |
| 14(4)(c) remain aware of automation | Refusal rolls back; state unchanged after rejection | w13: pre==post state asserted in `test/xaas/actuation_refusal_negative_test.exs` | EVIDENCED |
| 14(4)(d) decide not to use / override | Deterministic-halt refusal family the operator can rely on | 62/62 `REFUSED_*` tokens covered (w202 recount; w236 capstone) | EVIDENCED |
| 14(4)(e) automation-bias awareness | No silent-proceed: every external-mismatch branch returns `{:error, atom}`, no fallback-to-proceed branch | `lib/xaas/actuation.ex:537-547,770`; fixtures `test/xaas/actuation_refusal_negative_test.exs` | EVIDENCED (code-level) + doc-class EVIDENCED-with-limitations (w423: docs/cro/artifacts/bias-awareness-measures-v26.10.6.md, 5 typed limitations incl. LIMITATION(NO_DEMOGRAPHIC_BIAS_DETECTION)); OS-15 CLOSED 2026-10-06 |

### Art. 15 — Accuracy / robustness / cybersecurity

| Clause | Requirement (gist) | Evidence artifact(s) | Verdict |
|---|---|---|---|
| 15(1)(a) resilient re: drift | Drift refusal + drift guard | `REFUSED_XAAS_PROJECTION_DRIFT` (`castle.ex:380`; batch6 fixture), ggen drift guard (vector4, w73) | EVIDENCED |
| 15(1)(c) cybersecurity | Fail-closed auth floor, body-limit boundary, token revocation, CLOAK_KEY prod guard | Plug 7/7 (w13, `test/xaas_web/plugs/require_internal_api_token_test.exs`); typed 413 body limit (w22, `test/xaas_web/endpoint_body_limit_test.exs`); revocation court (w183, `test/xaas/accounts/token_revocation_test.exs` — real AshAuthentication JWTs, `:is_revoked` flips false→true); OS-17 FIXED: `Xaas.Vault.init/1` prod branch fail-closes on missing/placeholder CLOAK_KEY (`lib/xaas/vault.ex`, w349 receipt + w393 wiring trace; guard tests 4/4 incl. source pin) | EVIDENCED |
| 15(1)(d) resilience via refusal-first | Out-of-bounds actuation is refused, not repaired | 62/62 tokens (w202/w236); authority gate `REFUSED_CASTLE_AUTHORITY_NOT_ALLOWED` (`castle.ex:829`) | EVIDENCED |

### Art. 50 — Transparency

| Clause | Requirement (gist) | Evidence artifact(s) | Verdict |
|---|---|---|---|
| 50(1) machine-readable disclosure | Refusal vocabulary is machine-readable (typed atoms/tuples, not prose) | 62/62 typed `REFUSED_*` tokens; §2 of `_CLOSURE_PLAN.md` | EVIDENCED |
| 50(1)/(4) expose AI interaction | A2A v1 wire-conformant surface | w270: SSE seam closed, `test/xaas_web/a2a/v1_sse_test.exs` (3 cases, real router dispatch); w385 conformance court: 26/26 CONFORMANT (100%), 311 tests, zero missing courts, HEAD `07180bd3` | EVIDENCED (machine-to-machine class; in-repo courts, TCK-certified remains UNSUPPORTED) |
| 50 end-user-facing disclosure | Human-readable disclosure artifact | No end-user disclosure surface on disk (unchanged this week; OS-16 open) | PARTIAL — `GAP(NO_END_USER_DISCLOSURE)` |

## 2. NIST AI RMF

| Function | Expectation | Evidence artifact(s) | Verdict |
|---|---|---|---|
| GOVERN 1.1/1.2 | Governance encoded as law, not prose | BRCE admission path (`docs/claude/diataxis/reference/actuation-and-semantics.md`); SJIRA work-order admission (`docs/sjira/v26.10.6/`) | EVIDENCED |
| GOVERN 2.1 accountability | Per-lane ownership + receipts | `_LANES.md`; per-lane receipts w13/w18/w67/w121/w176/w183/w202/w208/w236/w270/w320/w378/w379/w382/w385 | EVIDENCED |
| GOVERN 4 org governance | Policy floor | CLAUDE.md policy floor: Ash deny-by-default, fail-closed API auth, consequential-DO discipline | EVIDENCED (policy-artifact class) |
| MAP 1.1/3.1 context + risk | Inventory + risk register | `_CLOSURE_PLAN.md` §1-§3; `docs/sjira/v26.10.6/plans/x7-risk-register.md` | EVIDENCED |
| MEASURE 2.5/2.11 | Coverage measured, not asserted | w176 token-level `comm -23` recount (delta 50→16→0); w202 authoritative 62/62; w236 86-pass capstone; w385 26/26 conformance report | EVIDENCED |
| MEASURE 2.11 anti-vacuity | Every claim falsifiable; falsifiers actually run | w176 recount refuted w67's INTENT_NOT_EXECUTING claim — refutation recorded, not overwritten (`_CLOSURE_PLAN.md` §2.1); w320 mutation audit 4/6 killed; w382-r2 (2026-10-06) 2/3 killed; w414 (2026-10-06) killed the surviving empty-bearer mutant with the corrected killer — empty bearer + env set to empty string must 401, never authenticate (`plans/w414-empty-bearer-kill.md`); witness-slice algorithm census: `:ml_dsa65` assertion-exercised, hybrid ES256+ML-DSA-65 KAT (`plans/w434-witness-slice.md`). Totals: 10 mutation runs, 9 kills, 0 open anti-vacuity gaps | EVIDENCED (method-level) |
| MANAGE 2.3/2.4 | Refusal as first-class consequence; risk prioritized | Refusal-first posture: 62/62 typed refusals, delta 0; castle authority gate (`castle.ex:829`) | EVIDENCED |
| MANAGE 4.1/4.3 typed risk vocabulary | Typed reasons for every gap/refusal | `REFUSED_*` family (62/62); typed `GAP(...)` reasons in this map; BLOCKED/UNSUPPORTED/REFUSED standing vocabulary | EVIDENCED |

## 3. Zero-Config Posture (no operator configuration of safety)

| Safety path | Code site (verified on disk) | Why zero-config |
|---|---|---|
| API auth fail-closed | `lib/xaas_web/plugs/require_internal_api_token.ex:95,103` (env checks), `:138` (401), `:148` (503) | Unset env → every request 503 (fail closed, not open); wrong token → 401; `assigns[:current_org]` never set on refusals (w13: 7/7). No flag opens the floor; only presenting the credential admits. Known test gap (w382-r2): the empty-bearer branch (`:130`, guard `byte_size(token) > 0`) is vacuous as tested — no fixture pairs empty `Bearer ` with unset env — the fail-closed behavior itself is unaffected. |
| Actuation refusal atoms | `lib/xaas/actuation.ex:537-547` (identity/input/projection/receipt-intent mismatch), `:770` (`subject_id_required`) | Gates are unconditional — no enable flag, no `Application.get_env` in the gate path; fixtures assert exact tuples + pre==post state (w13/w236). Known inverted gap (w379): the identity clause at `:539` is a tautology — `checkpoint_external/2` loads both records by the admission's own PKs, so a forged internally-consistent foreign pair is ADMITTED (witness test; OS-18). |
| Castle gates | `lib/xaas/castle.ex:829` (`REFUSED_CASTLE_AUTHORITY_NOT_ALLOWED`), `:862` (runtime identity), checkpoint gates `:436-460` | The only `Application.get_env` reads (`castle.ex:59,528,787`: kernel/adapter profiles) select implementations, not whether gates run — gates fire with zero config. |
| Ash-admin surface (W394 final, 2026-10-06) | AshAdmin runs `authorize?: false`; no policy/refusal-law involvement | Zero-config posture unaffected: the observed e2e regression was a LiveView hydration race, fixed by w460 spec settle-waits (e2e-flakiness class, not a refusal-law gap) — `plans/w460-admin-spec-settle.md` (in-flight) |
| Vault CLOAK_KEY prod guard (OS-17, FIXED 2026-10-06) | `lib/xaas/vault.ex` `init/1` prod branch → `{:stop, {:cloak_key_missing, :prod_refuses_placeholder_key}}` | Fail-closed unconditionally in prod: unset or placeholder CLOAK_KEY stops boot; dev/test unchanged. No flag can disable the guard; guard tests 4/4 incl. source pin (w349 receipt + w393 wiring trace). Strengthens Art. 15 / zero-config posture. |

## 4. Anti-Vacuity: mutant-killable vs structurally unreachable

Mutant-killable = a negative fixture exists that fails if the refusal branch is mutated
away. All fixture counts from the w236 consolidated run (86 passed, 12 files). Mutation
rounds: w320 (6 mutants, 4 killed, 2 survived → reclassified), w382-r2 (2026-10-06,
3 more mutants, 2 killed, 1 survived), w414 (2026-10-06, the w382-r2 survivor killed —
empty bearer + env set to empty string must 401, never authenticate;
`plans/w414-empty-bearer-kill.md`).

**Mutant-killable:**

| Family | Fixtures | Receipt |
|---|---|---|
| Castle engine (REFUSED_CASTLE_* 25 + `BLOCKED_CASTLE_TRANSPORT` typed tuple, w321 reverified at `castle.ex:950`) | `castle_refusal_negative_test.exs` (19) + batch2 (12) + batch3 (7) + batch4 (3) + batch5 (3), `test/xaas/` | w67 (44/44), w236; w320 killed PROJECTION_MISMATCH + REQUIRED_FIELD mutants; w382-r2 killed the `verify_outer_intent/3` idempotency-gate mutant (`castle.ex:382`) — 17/18 |
| Castle outer intent/receipt gate (13 tokens, `castle.ex:360-421`) | `castle_refusal_negative_batch6_test.exs` (18 tests: 13 gate mutations + REQUIRED_FIELD admission/CLI paths), `test/xaas/` | w208, w236, w320, w382-r2 |
| Required-field gate | `REFUSED_REQUIRED_FIELD` admission + CLI paths, in batch6 | w208, w236, w320 (mutant KILLED, 16/18) |
| Actuation error atoms (7) | `test/xaas/actuation_refusal_negative_test.exs` (6: 5 pre-existing + w379 forged-pair witness) | w13, w121, w236, w379 |
| VKG (3 declared; 2 mutant-killable + 1 structurally unreachable) | `test/xaas/semantics/vkg_refusal_negative_test.exs` (3) | w18, w236; `REFUSED_VKG_EMPTY_CATALOG` moved to the unreachable list (w378 call-graph proof) |
| R2RML (1 of 2) | `test/xaas/semantics/r2rml_refusal_test.exs` (2 tests) | w185-class, w236, w320 (NON_UNIQUE_SEMANTIC_IDENTITY mutant KILLED, 0/2) |
| Fail-closed plug (3 branches) | `test/xaas_web/plugs/require_internal_api_token_test.exs` (7) + `test/xaas_web/endpoint_body_limit_test.exs` (3) | w13, w22, w236; w320 killed fail-closed-503 mutant (6/7); w382-r2: endpoint body-limit mutant KILLED (1/3); plug empty-bearer mutant SURVIVED (7/7 green with guard disabled), then KILLED by w414 (`plans/w414-empty-bearer-kill.md`) — 0 open gaps in this family |
| Token revocation | `test/xaas/accounts/token_revocation_test.exs` (4) | w183 (+OS-12 disclosures) |

**Structurally unreachable (typed, per `_CLOSURE_PLAN.md` §2; count now 2 ledger-tracked
variants + the typed-shape items below):**

- `lib/xaas/semantics/vkg.ex:52` `REFUSED_VKG_EMPTY_CATALOG` dead clause — **NEW (w378
  call-graph proof)**: `Registry.admit/1` refuses `[]` contracts outright
  (`deps/ash_r2rml .../vkg/registry.ex:25`), so `Catalog.ids/1` can never return `[]`
  through any public entry; the real empty edge refuses earlier as
  `REFUSED_VKG_MANIFEST` (fixture exists). Operator/next-cycle: delete the dead clause
  + redundant guard (`vkg.ex:40`).
- `r2rml.ex:212` `REFUSED_UNKNOWN_ATTRIBUTE` — `is_nil(attribute)` cannot hold through
  any public entry; projection is derived, never injected (w185/w208 call-graph
  evidence, per `_CLOSURE_PLAN.md` §2.1).
- `actuation.ex:539` external admission identity clause — dead via its only lawful
  entry (`checkpoint_external/2` loads both records by the admission's own PKs);
  w379 deletion-mutant survives with zero behavioral delta; the surviving semantic
  gap (forged internally-consistent pair ADMITTED) is OS-18, fix serialized after
  w398's corpus run (v26.10.6-adjacent safety-law change; may defer to v26.10.7).
- ~~`castle.ex:941` `BLOCKED_CASTLE_TRANSPORT` — untyped~~ **REVERIFIED TYPED (w321)**:
  typed tuple `{:error, {:BLOCKED_CASTLE_TRANSPORT, %{...}}}` at `castle.ex:950`;
  fixture `castle_refusal_negative_batch4_test.exs:94-113`. No longer an
  untyped-shape gap (kept on the unreachable list only if no mutant run — w320/w382
  did not mutate it).
- `actuation.ex:383` untyped rescue → `{:exception, struct, string}` (fixture pins
  shape only; pre-existing, not this session's diff).
- Bare-string refusals: `stop_court.ex:1956`, `eds/falsifier.ex:84`,
  `a2a/zoe_event_simulation_agent.ex:58`, `a2a/next_read_user_agent.ex:159`,
  `health_controller.ex:96`, `marketplace_catalog_live.ex:71,74` — typed-refactor-only,
  out of closure scope. (~~`capability_coverage.ex:59`~~ **REMOVED (w321 REFUTED)** —
  no refusal shape in that file; `:59` is a report printer.)
- ash_surface JS projector untyped string throws (`REFUSED_UNKNOWN_ACTION`,
  `REFUSED_NOT_DO_BOUNDARY`, `projectors/js.ex:494,501` per w321) —
  machine-readability gap, not fixture-able until typed.
- 12 Mix-task files / 21 sites emit bare `"REFUSED"` stdout strings (w321 recount;
  was "13 tasks": stop_court 4, successor 4, episode 3, fabric.redeploy,
  release_audit, autonomic.controls, sjira.engineer_work,
  safe_generate_migrations, release_snapshot.verify 2, self_digest, ash_surface,
  run_validate:83 — stdout renderer of a typed code, not a refusal shape).

**Typed test gap (w382-r2) — CLOSED (w414):** the plug empty-bearer branch
(`require_internal_api_token.ex:130`, guard `byte_size(token) > 0`) was vacuous as
tested — the mutant (`> 0` → `>= 0`) left the suite 7/7 green. w414's corrected killer:
empty bearer + `INTERNAL_API_TOKEN` set to empty string must 401, never authenticate —
fails under the mutant (8/9 passed, 1 failed before the killer; `Result: 9 passed`
after). 0 open anti-vacuity gaps (`plans/w414-empty-bearer-kill.md`).

**Ledger drift note:** `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json` carries a
note that "w382 does NOT exist on disk" — stale as of 2026-10-06 17:33 PDT, when
`plans/w382-anti-vacuity-r2.md` landed (2/3 mutants killed, 1 survived). The ledger's
`mutant_kill_verified: 6` covers w320 only; w382-r2's three runs are not yet folded in.

## 5. Aggregate Verdict

- **Art. 12**: EVIDENCED except 12(3) — GAP narrowed: doc-level machine-readable export
  landed (`docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json`); remaining gap is
  `GAP(NO_RUNTIME_EXPORT_API)` (no automated runtime surface, no retention artifact).
- **Art. 14**: EVIDENCED at refusal-as-consequence class (OS-18 forged-pair inverted gap
  honestly disclosed); 14(4)(e) EVIDENCED code-level + doc-class EVIDENCED-with-limitations — GAP(NO_BIAS_AWARENESS_DOC) narrowed to the code-level limitation per w423 (OS-15 CLOSED 2026-10-06).
- **Art. 15**: EVIDENCED (drift, cybersecurity incl. the new OS-17 CLOAK_KEY prod guard,
  refusal-first resilience).
- **Art. 50**: PARTIAL — machine-readable refusal vocabulary, wire-conformant A2A v1
  (w270) and 26/26 in-repo conformance courts (w385) are EVIDENCED; end-user disclosure
  absent — `GAP(NO_END_USER_DISCLOSURE)` (OS-16, unchanged; TCK-certified UNSUPPORTED).
- **NIST RMF**: GOVERN/MAP/MEASURE/MANAGE EVIDENCED at receipt class.
- **Zero-config**: EVIDENCED — fail-closed plug (`require_internal_api_token.ex:95,103,138,148`),
  unconditional actuation gates (`actuation.ex:537-547,770`), castle gates fire with
  zero config (`castle.ex:829`; env reads select implementations only), CLOAK_KEY prod
  guard fails boot closed (`vault.ex init/1`, w349/w393). Posture HELD with zero
  safety-adjustable knobs (w322).
- **Anti-vacuity**: 62/62 refusal tokens with negative fixtures (delta 0, w202/w236);
  10 mutation runs, 9 kills, 2 typed-unreachable variants (VKG EMPTY_CATALOG, r2rml
  UNKNOWN_ATTRIBUTE), 1 tautology clause documented with ADMITTED-forgery witness
  (OS-18), 0 open anti-vacuity gaps; ledger regenerated with a stale w382 note
  (see §4 drift note).

## 6. Consumers

- CRO loop (`docs/cro/CRO-LOOP.md`): weekly GTM/RevOps cycle converting this corpus
  into pipeline (EU AI Act / Caremark / GCP EDP accounts); consumes this map as its
  Art. 12/14/15 evidence source and the ledger at
  `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json`.
- Integration carrier of the evidence corpus: `plans/w464-commit-manifest-v3.md`
  (in-flight) — the commit manifest packaging this map, the ledger, and the
  mutation-round receipts.

## 7. Implementation wave (2026-10-06, W500-series)

Lane W515 (integration/map), 2026-10-06. The 16-lane EU-AI-Act implementation wave
landed receipts under `docs/sjira/v26.10.6/plans/` (W509's crate at
`/Users/sac/wasm4pm/crates/eu_gate`; W501's Rust in `/Users/sac/ferroplan`; W511's
module in `/Users/sac/beam4pm`). Anti-vapor ledger with full per-lane detail:
`docs/cro/artifacts/implementation-wave-ledger.md`.

**This section maps lanes to articles only. It does NOT flip any existing
EVIDENCED/GAP verdict above — that is the next integration lane's job after review.**

| Lane | Article / dissertation claim | Standing (per lane receipt) | Receipt |
|---|---|---|---|
| W500 | Art. 5(1)(a)-(h) constructive nullification (admission profile) | ALIVE (surface; 24/24, mutant-kill witnessed); route integration BLOCKED by lane contract | `plans/w500-art5-admission.md` |
| W501 | Art. 9 safe-set reachability (Thm 3.1) | PARTIAL_ALIVE (narrow gate pass, mutant killed, full ferroplan suite exit 0) | `plans/w501-art9-reachability.md` |
| W502 | Art. 10 dataset admission gate (Thm 3.2) | ALIVE (lane-scoped; 6/6) | `plans/w502-art10-dataset-gate.md` |
| W503 | Art. 12 audit chain (Def 4.2 / Thm 4.1) | PARTIAL_ALIVE (17/17; SHA-256/JCS — BLAKE3 is documented upgrade path, not present) | `plans/w503-art12-audit-chain.md` |
| W504 | Art. 11 Annex-IV generator (Def 4.1) | BLOCKED (full-app gate on concurrent-lane WIP); modules ALIVE in isolated runs | `plans/w504-art11-annex-iv.md` |
| W505 | Art. 13 exact Shapley (Def 5.2) | ALIVE (surface; 8/8 incl. 2^20 boundary); whole-app BLOCKED(CONCURRENT_LANE_COMPILE) | `plans/w505-art13-shapley.md` |
| W506 | Art. 86 counterfactual (Thm 7.1) | ALIVE (surface-only; 9 passed) | `plans/w506-art86-counterfactual.md` |
| W507 | Art. 14(4)(e) emergency stop (Thm 5.2) | ALIVE (5 passed, real sandboxed Postgres) | `plans/w507-art14-estop.md` |
| W508 | Art. 15 robust margin (Thm 5.3) | ALIVE (surface; 10 passed) — CONDITIONAL certificate, empirical Lipschitz lower bound | `plans/w508-art15-margin.md` |
| W509 | Art. 15 WASI gate (Thm 5.4, `eyerun_wasi`) | ALIVE (cargo test + release run; median 4.01ms incl. spawn); replaces w405 vapor | `plans/w509-wasi-gate.md` |
| W510 | Art. 50 ML-DSA-65 signed receipt (Ch6) | PARTIAL_ALIVE (OpenSSL 3.6.4 CLI, FIPS 204, positive+tamper-negative; engine-side wasm UNSUPPORTED at pinned ABI) | `plans/w510-mldsa-signing.md` |
| W511 | Art. 72 token-replay conformance (Def 7.2) | PARTIAL — receipt landed, runner tail explicitly not in receipt ("do not cite without the runner tail") | `plans/w511-art72-conformance.md` |
| W512 | GPAI authority decoupling (Ch6 Thm 6.1) | PENDING — "AXIOMS-HELD (pending final mix test receipt)"; output placeholder unfilled at 19:50 PDT | `plans/w512-gpai-decoupling.md` |
| W513 | Art. 12(3) conformance pack export (OS-14 narrowing) | ALIVE (4/4; real sample generation observed) | `plans/w513-conformance-pack.md` |
| W514 | RFC 8785 JCS substrate | ALIVE (16 tests, full RFC 8785 via pinned `jcs` hex) | `plans/w514-jcs.md` |
| W515 | Integration/map (this section + ledger) | ALIVE | `docs/cro/artifacts/implementation-wave-ledger.md` |

Aggregate at poll end (19:50 PDT): 15/15 receipts landed; 8 ALIVE (surface-scoped),
4 PARTIAL / PARTIAL_ALIVE, 1 BLOCKED (full-app gate, likely resolved now that sibling
files completed — re-run owed), 1 PENDING (W512), 1 integration lane. Nothing is
committed; the coordinator owns lane transitions and per-lane `_build-laneW5xx`
build-root cleanup. Still future (unchanged): certified Lipschitz constants,
BLAKE3, official A2A TCK, exact network-simplex OT, live-route integration of the
Art. 5 admission profile.

### Terminal state (2026-10-06, W546/W547/W605/W612)

All lanes landed. Terminal verdict per
`plans/w605-euaia-aggregation-3.md` (cited in the
implementation-wave-ledger terminal section): **EVERY-LINE-TESTED +
SUITE-GREEN** — gate direction 1068 passed / 19 excluded / exit 0; honest
census 1068/1087 with every failure a tagged OPEN_GAP. Corpus coverage is
**COMPLETE for the wave**; gap trajectory 37 → 24 (W547's 13 flips) → 19.
W546's OS-18 `checkpoint_external/2` tautology fix is live and mutant-killed
(its corpus run-log receipt block remained a placeholder at aggregation time).

The **19 typed open gaps remain as the future-work inventory** (full
enumeration in the ledger's terminal section):
AI-literacy (4.1); Art. 8.1 umbrella; FRIA schedule field (27.1.b), FRIA
oversight-implementation description (27.1.e), FRIA materialisation /
serious-incident authority channel (27.1.f); the Art. 73 serious-incident
reporting family (73.1, 73.2, 73.2.s2, 73.3, 73.4, 73.5, 73.6, 73.6.s2, 73.9);
Art. 74 authority access/audit powers (74.12, 74.13.a, 74.13.b); Art. 86
exceptions (86.2, 86.3). Standing v2 items unchanged: certified Lipschitz
constants, BLAKE3, official A2A TCK, exact network-simplex OT, Art. 5
route integration.

### Post-W612 flip/reclassification wave (2026-10-06, W625c-W660) — final dispositions

Lane W663 (coverage-map §7 append), 2026-10-06. The typed open-gap inventory
from the terminal block above is now fully dispositioned. Every cited receipt
below was `test -f` verified on disk at
`docs/sjira/v26.10.6/plans/` before citation.

| Family | Lines | Disposition | Receipt |
|---|---|---|---|
| Art. 3.49 serious-incident family | 3.49, 3.49.a-d (5) | EVIDENCED via W538 `IncidentReport.build/2`/`transmit/1` (family-level trigger classes; sub-line-distinct atoms absent, disclosed in the receipt) | `plans/w607-349-41-closures.md` |
| Art. 4.1 AI literacy | 4.1 | EVIDENCED via `Xaas.Semantics.OversightGovernance.ai_literacy/0` (real operator-enablement evidence paths); W607 had honestly kept it open as `GAP(NO_AI_LITERACY_SURFACE)` | `plans/w648b-literacy-fria.md` |
| Art. 50.2 synthetic marking | 50.2 | EVIDENCED via W533 `synthetic_marking_plug` + its test | `plans/w547-gap-flips.md` |
| Art. 8.1 Section-2 umbrella | 8.1 | EVIDENCED iff children — discharged by the evidenced Art. 9-15 children asserted against the file's own `reclass_map` resolution | `plans/w649b-art8-1-flip.md` |
| FRIA structured fields | 27.1.b, 27.1.e, 27.1.f | EVIDENCED via `fria_schedule/0`, `fria_oversight_description/0`, and `fria/0` materialisation entries + W538 seam; 27.1.f carried as typed-inventory-not-closed-channel (authority endpoint `:OPEN`, `PREPARED_NOT_TRANSMITTED`) | `plans/w648b-literacy-fria.md` |
| Art. 73 serious-incident reporting family | 73.1, 73.2, 73.2.s2, 73.3, 73.4, 73.5, 73.6, 73.6.s2 (8) | EVIDENCED-with-caveat (authority endpoints typed `:OPEN`; reports `PREPARED_NOT_TRANSMITTED`, never silently sent) | `plans/w625c-art73-flips.md` |
| Art. 73.9 legal scoping | 73.9 | NOT_APPLICABLE (typed) — authority-side legal dedup, no in-repo obligation beyond the evidenced 73.1 seam | `plans/w625c-art73-flips.md` |
| Art. 74/86 authority-side powers | 74.12, 74.13.a, 74.13.b, 86.2, 86.3 (5) | NOT_APPLICABLE (typed) — authority-side access/exhaustion/legal-scoping determinations; the in-repo auditable substrate (receipt corpus, OCEL, audit chain) is what they consume | `plans/w648-art74-86-classify.md` |
| EUAIA risk-concept grounding | all 8 Art. 5 atoms | EVIDENCED — `risk_concept_for/1` EUAIA family clauses map each `REFUSED_EUAIA_*` atom to a distinct dissertation-partition risk concept; bogus-atom fallback refuted to `UNADMITTED_TRANSITION` | `plans/w657-euaia-family.md`, `plans/w660-grounding-refresh.md` |
| OS-18 `checkpoint_external/2` tautology | n/a (fix) | FIXED — identity clause replaced with live resource/action/subject/input-hash comparison; mutant killed | `plans/w546-os18-fix.md` |

**Residual typed open-gap count: 0.** W650's ledger terminal block listed 10
remaining typed open gaps (4.1, 8.1, 27.1.b, 27.1.e, 27.1.f, 74.12, 74.13.a,
74.13.b, 86.2, 86.3); W648b flipped the first five, W649b flipped 8.1, and W648
reclassified the remaining five as typed NOT_APPLICABLE. After these waves,
`Xaas.EUAIAct.TitleVIXIIIOpenGapsTest` generates zero tests and Title I/III
each carry zero typed open gaps (per the W648b/W648 receipts). The last full
aggregation rerun is W645 aggregation-7 (`plans/w645-euaia-aggregation-7.md`:
green gate 1112 passed / 5 excluded; honest census 5 stable typed open gaps);
no post-flip aggregation rerun (w645c / w662) has landed — the residual-zero
claim rests on the per-lane flip receipts, and an aggregation rerun at the
post-flip tree is owed before citing a suite-level number.

Standing v2 items unchanged: certified Lipschitz constants, BLAKE3, official
A2A TCK, exact network-simplex OT, Art. 5 route integration.
