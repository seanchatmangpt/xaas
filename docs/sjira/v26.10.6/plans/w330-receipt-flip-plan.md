# W330 — PENDING→CLOSED Flip Plan for `_CLOSURE_RECEIPT.md` + DoD Re-Walk v3 Evidence Bundle

Lane W330, 2026-10-06. Repo `/Users/sac/xaas` @ `feat/playwright-surface`
(working tree, no git actions). This file is the ONLY artifact written.
Read `_CLOSURE_RECEIPT.md` in full (405 lines); every `PENDING` marker
enumerated; evidence re-gathered from `plans/` on disk at check time
(2026-10-06 ~16:30 local). Receipt corpus is now **177 receipt files**
(`ls | grep -cE '^w|^r|^x'` = 177), up from the cited 119 (W184b) — the
Exact-subject count is stale.

## 1. Marker enumeration (grep -i pending, _CLOSURE_RECEIPT.md)

Distinct marker classes (line numbers from the on-disk file):

| # | Marker (verbatim, line) | Occurrences |
|---|---|---|
| M1 | `PENDING: W20` (71, 222, 307) | 3 |
| M2 | `PENDING: W185` (74, 308) | 2 |
| M3 | `PENDING: final Playwright lane` (125, 201, 239–240, 338, 389–390) | 5 |
| M4 | `PENDING: P2-2` (205, 309) | 2 |
| M5 | `PENDING: coordinator commit lane` (48, 157–158, 257–261, 270, 310) | 5 |
| M6 | `PENDING: WP-B commit` (153) / `PENDING: WP-C commit` (155) / `PENDING: coordinator commit` (149) | 3 |
| M7 | `PENDING: r8 falsifier or typed BLOCKED` (224, 309–310) | 2 |
| M8 | `PENDING: ash_surface fleet falsifiers` (232) | 1 |
| M9 | `PENDING: coordinator CI lane` (177) | 1 |
| M10 | `PENDING: coordinator` (262–263, 273–274) | 2 |

## Dispositions

### M3 — `PENDING: final Playwright lane` — READY (evidence-complete)

**Evidence (all on disk):**
- `w317-pw-final-tokened.md` — full tokened `npx playwright test` @ subject
  `d1db2b03`: **96 passed / 0 failed / 2 skipped, 98/98 in --list, 32.0s,
  webServer booted via W310 BOOT readiness gate, zero flaky.** This is the
  final full green browser-rung run the marker names; replaces `w118`
  62/32/3 as best.
- `w310g-pw-final.md` — 95/1/2 (internal-api health-data failure
  subsequently closed by the tokened run; w317 supersedes).
- `w299b-server-death.md` — the residual mid-suite server-death class
  diagnosed: lost-stderr IO-device boot termination, not a dispatch crash;
  w317's PW_PORT lease + stderr redirect closes it.

**Proposed replacement text (all 5 occurrences):**
`CLOSED: final Playwright lane — w317-pw-final-tokened.md: full tokened
npx playwright test @ d1db2b03, 96/0/2 (98/98 --list match), webServer
boot via W310 readiness gate, zero flaky; supersedes w118 as best full-PW
receipt. Residual run-level classes pre-closed: seed (w180), app-gap
(w171), marketplace regression (w169), server-death (w299b diagnosis +
PW_PORT/stderr lease).`

### M2 — `PENDING: W185` — GATED-ON-W318

**Current evidence on disk:**
- Batch6/r2rml test files exist on tree
  (`test/xaas/castle_refusal_negative_batch6_test.exs`,
  `test/xaas/semantics/r2rml_refusal_test.exs`); W185's own run was
  17/20 with 3 disclosed failures. **The 3 failures are now fixed on
  this subject**: W236
  capstone `w236-refusal-capstone.md` = 86 passed / 0F / 0S across all 12
  refusal files including batch6 (18 passed) and r2rml (2 passed);
  re-witnessed by W263b (appended to w236 file: 86 passed re-run) and
  W312 post-format re-run (62 passed across the six batches).
- **No standalone `w185*` receipt file exists** (`ls | grep w185` = none).
  W318 (w185 standalone receipt) is in flight.

**Proposed replacement text (2 occurrences, apply on W318 receipt):**
`CLOSED: W185 — batch6/r2rml fixtures covered by the standalone receipt
w185-*.md on disk; capstone 86/0 witnessed by w236-refusal-capstone.md
(+ W263b re-run, + W312 post-format), delta recount 0 per w176-refusal-delta-recount.md §W202 final recount.`

### M1 — `PENDING: w20` — GATED (no in-flight lane; genuinely open)

`w20-ash-pplan-adjudication.md` exists but is self-labeled INTERIM
("lane still running at backfill time — final verdict pending"). No
final-verdict append has landed. No W316/317/318/325 lane covers w20.
**Proposed replacement text:** keep PENDING, reword to
`PENDING: W20 final verdict append — w20-ash-pplan-adjudication.md remains
INTERIM; permission-bit root cause confirmed (OS-11 class); final narrow-rerun
verdict not appended.`

### M4 — `PENDING: P2-2` / M9 — `PENDING: no coordinator CI lane` — genuinely open

No CI-leg receipt on disk. Keep PENDING as-is, typed
`GATED-ON coordinator CI lane`.

### M5/M6 — coordinator commit legs — genuinely open (by contract)

By lane contract, commits are the coordinator's; w191 hazard map governs
(DO-NOT-COMMIT / PARKED / COMMIT-eligible; no `_build-lane*` in final
commit). Keep all commit-leg markers, typed
`GATED-ON coordinator commit lane (w153-v2 order, w191 hazard map)`.

### M7 — `PENDING: r8 falsifier or typed BLOCKED` — GATED-ON-W325

`r8-gymact.md` is an audit + wiring plan, not an executed e2e falsifier.
gymact e2e gate still UNKNOWN. W325 in flight; **no w325* receipt on disk
at check time** (`ls | grep -E 'w316|w318|w325'` = none).
On W325 receipt: flip to `CLOSED: gymact e2e falsifier — w325-*.md on
disk (executed e2e gate at gymact d3eb5e8 …)` or, if W325 lands a typed
BLOCKED, flip to that typed BLOCKED row.

### M8 — `PENDING: ash_surface fleet falsifiers (G1–G5)` — genuinely open

No G1–G5 execution receipt on disk; 1/11 repos wired (x2). Keep PENDING,
typed open. No lane in flight.

### Still-open register (carry as typed-gated, never silently closed)

- **OS-9 (law_evolution, BLOCKED → v26.10.7+)**: GC23 courts need retired
  compile_prose surface — `w107`, `w128`.
- **OS-10 (BLOCKED(new-code) → v26.10.7+)**: gymact witnessed_crown flip
  needs standing-feedback overlay + crown-premark-law change — `w129`
  receipt `adae920d`.
- **OS-11 (unowned permission-bit stripping)**: confirmed fleet-wide root
  cause by W20's adjudication file; unowned, open.
- **OS-12(a) (`:revoke_token` store-invariant fixture decision)**:
  operator/owner-gated.
- **OS-13 (fixtureOnly worked-example durable fix)**: `w264-fixtureonly-markers.md`
  is the inventory; durable fix open.
- **Coordinator legs**: integration commit + SHA, PR minting,
  receipt-to-commit binding, P2-1/P2-2 CI legs, sibling untracked/dirty
  legs (ferroplan wasm untracked, beam4pm 2,495 dirty lines, zcode-cli
  18-file stream, ggen-marketplace pack-gate fix uncommitted).
- **W20 final verdict** (see M1).
- **Stale count**: "119 receipt files" in Exact subject → 177 on disk at
  W330 check time; update during flip if desired.
- **New minor opens surfaced by the DoD re-walk**: castle negative-test
  subprocess flake (run-2-only, w315 disclosure), r2rml compile-warning
  skew (cosmetic, `w230-r2rml-skew.md`), 36 typed runtime skips.

## DoD re-walk v3 verdicts (per DoD 1–7)

| DoD | v3 verdict | Evidence |
|---|---|---|
| 1 (full suite) | **CLOSED — ALIVE** | w300-final-suite (3235P/36S/91E, exit 0, quiescent) + w295b (clean-root 3235P/0F, private build root) + w315 (two-run rerun, run-1 fully green, run-2 3232/3235 env-flaky trio) |
| 2 (refusal coverage delta 0) | **CLOSED — ALIVE** | w176 §W202 final recount (comm -23 = 0) + w236 capstone 86/0/0 + W263b re-run + W312 post-format 62/0 |
| 3 (browser rung) | **CLOSED — ALIVE** | w317 96/0/2 tokened full PW @ d1db2b03; w310g 95/1/2 prior best; w299b death class diagnosed+closed |
| 4 (integration commit) | OPEN (coordinator) | tree uncommitted by fan-out contract; w153-v2/w191 |
| DoD 5 = browser rung (merged into 3) | — | — |
| 6 (CI legs) | OPEN (coordinator CI lane) | no receipt; w103 prod-16-warnings receipt stands |
| 7 (review) | N/A until 4–6 land | — |

DoD 1–3 are now receipt-backed CLOSED/ALIVE. DoD 4/6 remain coordinator
legs; DoD 7 follows them.

## Counts

- **READY (evidence-complete, flip now)**: 1 marker class (M3, 5 occurrences) — final Playwright lane.
- **GATED-ON in-flight lanes**: 2 classes (M2 → W318; M7 → W325). (W316's tokened-suite leg is already superseded by w300/w295b/w315; W317's receipt already exists and feeds M3 — no separate gate needed.)
- **Genuinely open (no lane, typed-gated)**: 7 classes (M1 W20 verdict; M4/M9 P2-2/CI legs; M5/M6 coordinator commit legs; M8 G1–G5 fleet falsifiers; OS-9..OS-13 register; coordinator PR/SHA binding; stale 119→177 receipt count).
