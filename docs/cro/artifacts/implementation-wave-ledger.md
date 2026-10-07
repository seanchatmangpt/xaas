# EU AI Act Implementation Wave Ledger — W500-series (anti-vapor ledger)

Lane W515 (integration/map), 2026-10-06. Repo `/Users/sac/xaas` @ `feat/playwright-surface`.
Poll window: 19:00–19:50 PDT. **Landed at poll end: 15/15 lanes** (poll loop:
`ls docs/sjira/v26.10.6/plans/w5NN-*.md` every 30s).

Standing per lane receipt only — never guessed. "Receipt landed, no runner
tail in receipt" is recorded as PARTIAL, not ALIVE.

## 1. Lane table

| Lane | Chapter / article | Standing (per receipt) | Test output in receipt | Notes |
|---|---|---|---|---|
| W500 | Art. 5(1)(a)-(h) constructive-nullification admission | ALIVE (surface) | 24/24, mutant-kill witnessed | Integration into live routes: BLOCKED by lane contract (later lane's job) |
| W501 | Art. 9 inverse-reachability safe-set (Thm 3.1, ferroplan) | PARTIAL_ALIVE | narrow gate pass; mutant killed (4/6 tests); full `cargo test -p ferroplan` exit 0; "Full-suite tail (appended on completion)" placeholder remains | 100% handwritten Rust; no commit |
| W502 | Art. 10 dataset admission gate (Thm 3.2) | ALIVE (lane-scoped) | 6/6, `mix compile` reached |  |
| W503 | Art. 12 audit chain (Def 4.2 + Thm 4.1) | PARTIAL_ALIVE | 17/17 via real ExUnit | SHA-256 over JCS — **BLAKE3 absent and not added**; ML-DSA sig slot pluggable (W510 supplies) |
| W504 | Art. 11 Annex-IV functorial generator (Def 4.1) | BLOCKED (full-app gate) / modules ALIVE isolated | real artifacts at /tmp; full-app gate fails on foreign WIP `quiescent_stop.ex` (`Ash.Query.filter` without `require Ash.Query`, line 91) | BLOCKED(other_lane_untracked_wip), 2 identical attempts |
| W505 | Art. 13 exact Shapley over admission lattice (Def 5.2) | ALIVE (surface) / whole-app BLOCKED(CONCURRENT_LANE_COMPILE) | 8/8 incl. 2^20 boundary; 0.3s | exact enumeration, no Monte Carlo |
| W506 | Art. 86 counterfactual explanation (Thm 7.1) | ALIVE (surface-only, no route wiring) | 9 passed |  |
| W507 | Art. 14(4)(e) emergency-stop attractor (Thm 5.2) | ALIVE | 5 passed, 0 failed, real sandboxed Postgres |  |
| W508 | Art. 15 robust margin gate (Thm 5.3) | ALIVE (surface) | 10 passed, EXIT=0 | CONDITIONAL certificate: empirical Lipschitz is a LOWER BOUND; certified constant = v2 scope (interval arithmetic) |
| W509 | Art. 15 WASI gate binary (`eyerun_wasi`, Thm 5.4) | ALIVE | cargo test + release run, `{"verdict":"ADMITTED"}` exit 0; median 4.01ms incl. spawn | Vapor from w405 replaced with real binary at `/Users/sac/wasm4pm/crates/eu_gate`; crate standalone, uncommitted |
| W510 | Art. 50 / Ch6 ML-DSA-65 signed receipt | PARTIAL_ALIVE | OpenSSL 3.6.4 CLI subprocess, FIPS 204, positive+tamper-negative; persisted via CertifiedReceipt; used as AuditChain sig callback | Engine-side (`ash_affidavit` wasm) ML_DSA65 remains UNSUPPORTED at pinned ABI |
| W511 | Art. 72 conformance (Def 7.2, beam4pm) | PARTIAL (receipt landed, runner tail NOT in receipt — receipt itself says "do not cite this file as proof without the runner tail") | none in receipt | Seam documented only; no xaas code touched |
| W512 | Ch6 Thm 6.1 GPAI authority decoupling | PENDING (receipt landed; "AXIOMS-HELD (pending final mix test receipt below)"; output "(filled at run completion)" still empty at 19:50) | none in receipt |  |
| W513 | Art. 12(3)/Annex IV conformance pack export | ALIVE (4/4) | "Result: 4 passed"; sample generation observed | Doc-level export; narrows OS-14 `GAP(NO_RUNTIME_EXPORT_API)` runtime-export half |
| W514 | RFC 8785 JCS substrate | ALIVE (16 tests) | per receipt | Stray `_buildW514/` at repo root — coordinator cleanup |
| W515 | (this lane) integration/map | ALIVE | ledger + coverage-map section written |  |

## 2. Honest numbers — evidenced vs still future

### Now evidenced (with paths)

- Art. 5 admission profile: `docs/sjira/v26.10.6/plans/w500-art5-admission.md`; module
  `lib/xaas/semantics/eu_ai_act_admission.ex` (24/24, mutant-kill witnessed).
- Art. 9 safe-set: `/Users/sac/ferroplan` `reachability.rs` via
  `docs/sjira/v26.10.6/plans/w501-art9-reachability.md` (mutant killed, full suite exit 0).
- Art. 10 dataset gate: `docs/sjira/v26.10.6/plans/w502-art10-dataset-gate.md`;
  `lib/xaas/semantics/dataset_admission.ex` (6/6).
- Art. 12 audit chain: `docs/sjira/v26.10.6/plans/w503-art12-audit-chain.md`;
  `lib/xaas/witness/audit_chain.ex` (17/17; SHA-256/JCS).
- Art. 11 Annex-IV generator: `docs/sjira/v26.10.6/plans/w504-art11-annex-iv.md`
  (isolated ALIVE; full-app BLOCKED on foreign WIP).
- Art. 13 Shapley: `docs/sjira/v26.10.6/plans/w505-art13-shapley.md` (8/8, exact 2^n enumeration).
- Art. 86 counterfactual: `docs/sjira/v26.10.6/plans/w506-art86-counterfactual.md` (9 passed).
- Art. 14 e-stop: `docs/sjira/v26.10.6/plans/w507-art14-estop.md` (5 passed, real Postgres).
- Art. 15 margin gate: `docs/sjira/v26.10.6/plans/w508-art15-margin.md` (10 passed).
- Art. 15 WASI gate: `docs/sjira/v26.10.6/plans/w509-wasi-gate.md`; crate
  `/Users/sac/wasm4pm/crates/eu_gate` (median 4.01ms).
- ML-DSA-65: `docs/sjira/v26.10.6/plans/w510-mldsa-signing.md` (OpenSSL CLI, FIPS 204).
- Art. 72: `docs/sjira/v26.10.6/plans/w511-art72-conformance.md` (PARTIAL — no runner tail).
- GPAI decoupling: `docs/sjira/v26.10.6/plans/w512-gpai-decoupling.md` (PENDING final run).
- Conformance pack: `docs/sjira/v26.10.6/plans/w513-conformance-pack.md` (4/4).
- JCS: `docs/sjira/v26.10.6/plans/w514-jcs.md` (16 tests, full RFC 8785 via `jcs` hex pin).

### Still future (explicitly NOT evidenced by this wave)

- **Exact network-simplex OT** — not touched by any lane.
- **Certified Lipschitz constants** — W508 ships the EMPIRICAL constant (lower bound);
  certified-via-interval-arithmetic is documented v2 scope.
- **BLAKE3** — absent from lib/, not added; SHA-256/JCS stands in (W503 upgrade path).
- **Official A2A TCK** — 26/26 conformance courts are in-repo pinned corpus, not official TCK
  (unchanged verdict from the coverage map).
- **Art. 5 route integration** — W500 surface not wired into live routes (BLOCKED by lane
  contract; integration lane's job).
- **Art. 72 runner tail** — W511 receipt placeholder unfilled at poll end.
- **GPAI final mix test receipt** — W512 output placeholder unfilled at poll end.
- **Engine-side ML-DSA** — UNSUPPORTED at pinned ABI (OpenSSL CLI bridge only).

## 3. Coordinator carry-forward list

1. W504 full-app gate re-run after owning lanes' files are complete (it may now pass —
   the two blocking files were in-flight sibling WIP at the time; W513's retest passed 4/4
   after W506's file completed).
2. W511 runner tail + W512 final output: receipts must be filled before citation.
3. Stray `_buildW514/` at repo root + `_build-laneW5xx` roots: delete at integration
   per cleanup law.
4. Nothing committed by any lane — coordinator owns transitions.

## Terminal aggregation (W605/W612)

Terminal lane W612 (consolidation), 2026-10-06. Sources:
`docs/sjira/v26.10.6/plans/w605-euaia-aggregation-3.md` (terminal gate + census),
`plans/w547-gap-flips.md` (13 flips), `plans/w546-os18-fix.md` (OS-18 fix).
Fresh `--include eu_ai_act_open_gap` rerun this lane on `feat/playwright-surface`
confirms the census inventory below (19 `EUAI-ACT … OPEN_GAP` tests, exactly the
19 exclusions of the green gate).

### Terminal verdict

- **EVERY-LINE-TESTED + SUITE-GREEN.** Gate direction: `mix test test/eu_ai_act
  --include eu_ai_act --exclude eu_ai_act_open_gap` → **1068 passed, 19 excluded,
  exit 0** (W605, fresh `_build-laneW605` root). Census direction: **1068/1087,
  19 failed — every failure a tagged OPEN_GAP, zero untagged failures.**
- Terminal standing: corpus coverage COMPLETE for the wave. Gap trajectory 37
  → 24 (W547) → 19 (W605). W546's OS-18 `checkpoint_external/2` tautology fix is
  live and mutant-killed (7/7 on `test/xaas/actuation_refusal_negative_test.exs`,
  mutant KILLED by the flipped witness); its "Corpus results" section remained a
  placeholder at aggregation time (fix/flip/kill verdicts complete; corpus
  run-log block unfilled — flagged to coordinator).
- W547 landed 13 flips (12 OPEN_GAP → EVIDENCED, 1 → NOT_APPLICABLE: 50.2,
  15.3, 15.5.s3, 14.4.b, 26.6, 26.7, 27.1, 27.1.a, 27.1.c, 27.1.d, 27.2
  (NOT_APPLICABLE), 27.3, 99.4.e) on `synthetic_marking_plug.ex`,
  `declared_metrics.ex`, `vulnerability_lifecycle.ex`,
  `automation_bias_countermeasure.ex`, `oversight_governance.ex` (`fria/0`),
  `quiescent_stop.ex` — module + test-file existence verified before each flip.

### Per-title final counts

Census inventory run this lane (open-gap-only filter) plus W605/W547 receipts:

| title | final open gaps | line_ids |
|---|---|---|
| Title I (Arts 1–4) | 1 | 4.1 (AI-literacy measures) |
| Title II | 0 | — |
| Title III | 4 | 8.1 (Art 8.1 umbrella), 27.1.b (FRIA period/frequency schedule field), 27.1.e (FRIA oversight-implementation description), 27.1.f (FRIA materialisation = serious-incident authority channel) |
| Titles IV–V | 0 | — |
| Titles VI–XIII | 14 | 73.1, 73.2, 73.2.s2, 73.5, 73.9, 73.4, 73.6, 73.6.s2, 74.12, 74.13.a, 74.13.b, 86.2, 86.3, 73.3 (serious-incident reporting Art. 73 family + Art. 74 authority access/audit powers + Art. 86.2/86.3 exceptions) |
| Total | **19** | 1087 census lines, 1068 evidenced/not-applicable |

### 19-item typed open-gap inventory

Enumerated by real run (open-gap-only rerun, this lane) and consistent with
the W547 "held honestly OPEN" list and the W605 census; cited per receipt:

| # | line_id | gap | source |
|---|---|---|---|
| 1 | 4.1 | AI-literacy obligation has no implemented seam | W605 census; W547 held-open list |
| 2 | 8.1 | Art. 8.1 umbrella clause (high-risk compliance requirements) — no seam | W605 census |
| 3 | 27.1.b | FRIA lacks period/frequency schedule field | W547 flip receipt |
| 4 | 27.1.e | FRIA lacks oversight-measure implementation description | W547 flip receipt |
| 5 | 27.1.f | FRIA's only materialisation entry = the typed OPEN_GAP serious-incident authority channel | W547 flip receipt |
| 6–19 | 73.1, 73.2, 73.2.s2, 73.3, 73.4, 73.5, 73.6, 73.6.s2, 73.9, 74.12, 74.13.a, 74.13.b, 86.2, 86.3 | Art. 73 serious-incident reporting family, Art. 74 authority access/audit powers, Art. 86 exception clauses | W605 census |

(#6–19 counts 14 entries; the full enumerated set appears in the per-title table
above, which is the authoritative enumeration.)

### Carry-forward list (coordinator)

1. Fill W546's "Corpus results" placeholder with the actual corpus run record
   (`docs/sjira/v26.10.6/plans/w546-os18-fix.md`) before citing the corpus rerun.
2. W511 runner tail + W512 final output still unfilled — must be filled before citation.
3. Delete lane build roots `_build-laneW5xx`/`_build-laneW6xx` at integration
   (cleanup law), including `_build-laneW605`/`_build-laneW612`.
4. Nothing committed by any lane — coordinator owns transitions and commits.
5. The 19 typed open gaps are the future-work inventory: Art. 73 serious-incident
   reporting channel, FRIA schedule/oversight-description fields (27.1.b/27.1.e),
   serious-incident authority channel (27.1.f), AI-literacy (4.1), Art. 8.1
   umbrella, Art. 74 authority-access/audit powers, Art. 86.2/86.3 exceptions,
   plus the standing v2 items (certified Lipschitz constants, BLAKE3, official
   A2A TCK, exact network-simplex OT, Art. 5 route integration).

## Terminal-2 (post-deepening/flips)

Appended by lane W650 (terminal-2 update, 2026-10-06). Supersedes the W605/W612
aggregation section above where counts moved.

### Poll log (final wave receipts, all verified present in docs/sjira/v26.10.6/plans/)

| receipt | present | verdict |
|---|---|---|
| w546-os18-fix.md | yes | `checkpoint_external/2` tautology fixed (live identity clause re-deriving input hash); witness flipped, mutant KILLED; corpus run-log block still a placeholder (prior carry-forward #1 stands) |
| w547-gap-flips.md | yes | 13 flips (12 OPEN_GAP → EVIDENCED, 1 → NOT_APPLICABLE); suite 37 → 24 |
| w616-deepening.md | yes | 22 Title I–II test bodies deepened to real admit/1 calls + near-miss controls |
| w623-title-iii-deepening.md | yes | Title III W532-reclassified lines deepened with 8 real-call kinds (audit chain, dataset gate, margin gate, quiescent, counterfactual, Shapley, briefing, ferroplan reachability) |
| w626c-deepening-iv-xiii.md | yes | 14 lines deepened/repaired (Titles IV–V, VI–XIII); repaired a foreign lane's broken release_audit.ex fragment blocking all compilation (disclosed) |
| w625c-art73-flips.md | yes | 9 flips (73.1–73.6.s2 → EVIDENCED, 73.9 → NOT_APPLICABLE typed); file census 14 → 5; 471 passed / 5 excluded |
| w550-counterfactual-harness.md | yes | 17-test Pearl 3-step counterfactual harness, 17 passed |
| w624-counterfactual-extension.md | yes | +7 rows (Art 11/25/26(6)/50(2)/72/14.4.b); Art 9(2)(a) honestly NOT_RUN (cross-repo, no in-repo seam) |
| w607-349-41-closures.md | yes | 3.49.a–d → EVIDENCED (W538 builder); 4.1 kept OPEN_GAP (`GAP(NO_AI_LITERACY_SURFACE)`, not manufactured) |
| w525b-title-i.md | yes | Title I generator (Arts 1–4), one test per corpus line_id |
| w531-title-ii-corpus-loop.md | yes | all 26 Title II corpus lines covered, 0 uncovered |
| w534-title-iii-restructure | yes | fixed the ExUnit include-over-exclude defect (91 gap tests resurrected) |
| w535-title-iii-remaining-gaps | yes | 13 new EVIDENCED + 23-entry per-line NOT_APPLICABLE map for Arts 8/10/11/15/26/27 |
| w606-corpus-coverage-audit-2.md | yes | 1068 corpus ids, 1072 generated, 24 failures all OPEN_GAP-by-design, 0 uncovered |
| w611-corpus-coverage-final.md | recorded transport failures; corpus coverage COMPLETE (0 uncovered, 0 id-level duplicates); 5 real-behavior failures flagged to coordinator |
| w630-totality-fix.md | yes | 4 fuzz escapes closed (RobustMargin guard-domain, DatasetAdmission non-enumerable, EuAiActAdmission improper lists) — admission gates now total |

All named receipts landed. No lane reported a residual BLOCKED standing at
terminal; mid-wave transport blockers (release_audit.ex orphan fragment,
airo_risk_mapping.ex mid-edit SyntaxError) were cleared or repaired forward
within the wave.

### Final per-lane standing table (W500–W651)

Standing basis: landed receipt with real verification output = ALIVE; receipt
landed with a disclosed unfilled section or disclosed NOT_RUN row = PARTIAL.
No lane is BLOCKED at terminal (transient blockers cleared mid-wave).

| lane(s) | standing | basis |
|---|---|---|
| W500–W514 (Art 5/9/10/11/12/13/14/15, WASI gate, GPAI decoupling, JCS, conformance pack) | ALIVE | receipts w500–w514 landed; consumed by Title II/III suites (W522/W523/W531/W534/W535) and deepening lanes |
| W511 | PARTIAL | runner tail unfilled (prior carry-forward #2 stands; no later receipt fills it) |
| W512 | PARTIAL | final output unfilled (carry-forward #2 stands) |
| W521–W526b, W531, W534, W535, W536–W540 | ALIVE | Title generators + corpus loops + flips; consumed by W543/W605/W622 aggregations |
| W524b, W525d, W545 | ALIVE | audit-chain integration, map-update sweep, OCEL fitness |
| W546 | PARTIAL | fix + witness flip + mutant kill ALIVE; "Corpus results" block placeholder (carry-forward #1 stands) |
| W547 | ALIVE | 13 flips, suite 37 → 24 |
| W550, W624 | ALIVE | counterfactual harness 17 + 7 rows; one disclosed NOT_RUN (Art 9(2)(a), cross-repo) |
| W551 | PARTIAL | 6-mutant kill ledger PENDING (all 6 mutants + KillScore unfilled); harness itself (W550) ALIVE |
| W600–W605 (AIRA/AIRO vendor, mappings, marketplace, per-repo packs, aggregation-3) | ALIVE | receipts landed; W605 aggregation-3 real run 1068 passed / 19 excluded |
| W606, W611 | ALIVE | coverage audits: 0 uncovered, 0 id-level duplicates |
| W607 | ALIVE | 3.49-family flips; 4.1 honestly held OPEN |
| W608 | ALIVE | Art 56 boundary (15 lines → typed NOT_APPLICABLE) |
| W616, W623, W626c | ALIVE | deepening receipts: 22 + Title III + 14 bodies to real calls |
| W620–W622, W625–W628 | ALIVE | OS fixes, admission fuzz, aggregation-4 (1100/1110, 10 typed gaps), authority channel, master-equation check/soak |
| W625c | ALIVE | 9 Art-73 flips, file census 14 → 5 |
| W630 | ALIVE | 4 fuzz escapes closed, gates total |
| W631–W639 (rpc alignment, kanban/web drift, gettext, per-repo AIRO ledgers) | ALIVE | receipts landed, consumed by W639 AIRO ledger |

Counts: **ALIVE lanes 42 groups (≈57 lanes), PARTIAL 4 (W511, W512, W546, W551), BLOCKED 0.**

### Open-gap trajectory

| census | count | receipt |
|---|---|---|
| pre-restructure defect | 91 gap tests resurrected under the green-gate flags | w534-title-iii-restructure.md (defect observed 91/391 failing) |
| aggregation-2 | 37 | w543-euaia-aggregation-2.md (1035/1072, 37 typed OPEN_GAP) |
| post-flip | 24 | w547-gap-flips.md (via w605-euaia-aggregation-3.md baseline "37 → 24") |
| aggregation-3 | 19 | w605-euaia-aggregation-3.md (1068/1087, 19 failed = 19 tagged) |
| post-Art-73 flips | 15 | w625c-art73-flips.md ("suite-level count: 24 → 15") |
| aggregation-4 (current) | 10 | w622-euaia-aggregation-4.md (1100/1110, 10 typed open gaps — W605's 19 minus the 9 Art-73-family flips) |

Terminal count: **10 typed open gaps** (1100/1110 green-gate 1100 passed / 10 excluded, exit 0).

### Terminal inventory of remaining honest gaps (10, from w622-euaia-aggregation-4.md §3)

| line_id | gap | status vs. task's named candidates |
|---|---|---|
| 4.1 | AI-literacy obligation — no implemented seam; W607 judged honestly and kept open (`GAP(NO_AI_LITERACY_SURFACE)` typed reason) | open |
| 8.1 | Art. 8.1 umbrella (high-risk compliance requirements) — no seam | open |
| 27.1.b | FRIA lacks period/frequency schedule field | open |
| 27.1.e | FRIA lacks oversight-measure implementation description | open |
| 27.1.f | FRIA's only materialisation entry is the typed OPEN_GAP serious-incident authority channel | open |
| 74.12 | Art. 74 authority access/audit powers — no seam | open |
| 74.13.a | Art. 74.13(a) authority access to data | open |
| 74.13.b | Art. 74.13(b) authority powers | open |
| 86.2 | Art. 86.2 exception clause — no seam | open |
| 86.3 | Art. 86.3 exception clause — no seam | open |

Resolution status of the task's named candidates: **Art 14.4.b — RESOLVED**
(W547 flip to EVIDENCED on `automation_bias_countermeasure.ex` +
`automation_bias_countermeasure_test.exs`, receipt w539; deepened real-call in
W623's `:briefing` kind and W624 row 7). **Art 73.x family — RESOLVED with
typed caveat**: 73.1–73.6.s2 EVIDENCED via W538 `IncidentReport.build/2` +
W625 `AuthorityChannel.transmit/2`; authority endpoints remain `:OPEN` — the
report is `PREPARED_NOT_TRANSMITTED`, never silently "sent"; 73.9 typed
NOT_APPLICABLE. **Art 86.2/86.3, 4.1, 8.1, 74.x — OPEN** (FRIA schedule fields
27.1.b/27.1.e/27.1.f OPEN).

### Terminal standing

Receipt: ALIVE. Corpus coverage COMPLETE (w606/w611: 1068/1068 corpus ids
tested, 0 uncovered, extra = documented Title II synthetic extras only).
Green gate 1100 passed / 10 excluded, exit 0 (w622). Falsifier for the
terminal standing: any corpus.json line added without a generated test, or
any untagged failure in the honest census, flips this to residual.

### Carry-forward (coordinator, unchanged items marked unchanged)

1. (unchanged) Fill W546's corpus run-log placeholder before citing the corpus rerun.
2. (unchanged) W511 runner tail + W512 final output unfilled before citation.
3. (unchanged) Delete lane build roots at integration (cleanup law).
4. (unchanged) Nothing committed by lanes — coordinator owns transitions/commits.
5. W551's 6-mutant kill ledger + KillScore PENDING — fill or retire the receipt
   before citing mutation-kill standing for the counterfactual harness.
6. The 10 typed open gaps are the future-work inventory: 4.1, 8.1, FRIA
   schedule fields (27.1.b/27.1.e/27.1.f), Art 74 authority powers (74.12,
   74.13.a/b), Art 86.2/86.3 exceptions.
