# W620 — CYCLE-5 CRO entry receipt (v26.10.7 campaign open, Define stage)

Date: 2026-10-07. Lane W620, v26.10.7 campaign. Repo `/Users/sac/xaas`,
branch `feat/playwright-surface`, HEAD `cf228da6` at lane start. **No commit
made** (per dispatch); no mix commands run. Wrote exactly three files:

- `docs/cro/CYCLE-LOG.md` — CYCLE-5 entry appended (append-only, per the
  cycle-log header contract).
- `docs/cro/CRO-LOOP.md` — Status/Changelog pointer line updated only
  (Last-cycle pointer now names CYCLE-5 + this receipt; prior pointer
  preserved as "Prior cycle"). No verbatim operator copy touched.
- this receipt.

## Task

Open the v26.10.7 CRO cycle: write the CYCLE-5 Define entry whose charter is
the directive's six work packages, with per-WP Measure baselines cited to
on-disk receipts; anything unreceipted marked IN-FLIGHT; drift flagged
honestly.

## Measure baselines (all re-read from disk this session)

| WP | baseline (receipt) | standing |
|---|---|---|
| WP-1 | OS-14 LANDED (`plans/w620-os14-export-endpoint.md`, v26.10.6); OS-15 CLOSED doc-class, w423-receipt-missing caveat carried since w694; OS-16 marking ALIVE + end-user disclosure typed GAP retained; graphql OUT-OF-SCOPE flips did not touch statutory rows (W984aw sweep: 0 additional flips). W605 ProvOriginHeader plug code on tree → IN-FLIGHT(W605) (`plans/w605-prov-o-plug.md`) | LANDED/CLOSED/ALIVE+GAP; WP-1 addition IN-FLIGHT |
| WP-2 | OS-18 DONE (W546, `plans/w546-os18-fix.md`): tautology → LIVE clause, forged foreign pairs refused `:external_admission_identity_mismatch`, mutant killed, corpus 80/80 contention-adjusted. No v26.10.7 WP-2 receipt on disk | baseline DONE; WP-2 lane IN-FLIGHT |
| WP-3 | w613 PARTIAL_ALIVE spec-only (no agentgateway checkout, disclosed); w614 ALIVE at its own gate (`plans/w614-gate-log.json`: 10 cases, 8 intercepted, rate 1.0 on nonconforming, all_ok true, GOOSE-ABSENT, echo-stub leg) | PARTIAL_ALIVE / ALIVE-at-gate |
| WP-4 | w608 ash_a2a: **no-manifestation finding** — deviation NOT observed on OTP 29.1.1/1.20.4 (documented-standard semantics), 42 sites/22 files classified, 0 lib patches, court-only diff; w609 ash_pplan: deviation CONFIRMED live, 1 residual site (synthesis.ex:217, class-(b) invariant), census court green, standing PARTIAL_ALIVE (second-root + affected-module gates "(filled on completion)" unfilled). beam4pm + wasm4pm legs: no receipts → IN-FLIGHT; wasm4pm main BLOCKED(main-diverged) per w601p | w608 court finding ALIVE; w609 PARTIAL_ALIVE; 2 legs IN-FLIGHT |
| WP-5 | w610 fixtureOnly markers PARTIAL_ALIVE (surface already marked per family; nothing new to add); w618 fleet version bump 8 repos → 26.10.7, all uncommitted, validation grep/tomllib/json.load only | PARTIAL_ALIVE / uncommitted |
| WP-6 | No WP-6 receipt or mention anywhere under `docs/` (grep, this session) | IN-FLIGHT(UNRECEIPTED) |

## Drift flags (honest)

1. **RESOLVED-on-disk**: every MISSING_RECEIPT flagged by the CYCLE-4
   addendum (w984br) now exists on disk: `w984ai-w1-dim0.md`,
   `w984al-corpus-deepening-5.md`, `w984ao-graphql-removal.md`,
   `w984bk-straggler-removal.md`, plus `w984bv-removal-dispatch` lineage
   (`w984bv-removal-commit.md`), `w984ca-gate5-repairs.md`,
   w984cl-semantics-commit.md. The graphql-removal source commits
   (`12d5f6d3`, `04a153f6`) are in local history.
2. **Branch moved**: CYCLE-4 addendum stood at `b5d677b3` (origin == local).
   Now HEAD `cf228da6`; local is 9 commits
   ahead of `origin/feat/playwright-surface` (04a153f6), remote is an
   ancestor (no divergence) — fast-forward push pending.
3. **v26.10.6 seal exists**: annotated tag `v26.10.6` → `cf228da6` (NOT
   pushed), branch `release/v26.10.7` created from HEAD, census gate
   1352/1-excluded/0-failed on the sealed subject per
   `plans/w601q-tag-prep.md`.
4. **Citation drift in the dispatch**: "w606/607" resolve to v26.10.6
   receipts of a different subject (`w606-corpus-coverage-audit-2.md`,
   `w607-349-41-closures.md`), not Map.update sweeps; the on-disk sweep
   receipts are w608/w609 only. Counted honestly as 2 of 4 legs receipted.

## Falsifiers

1. Any baseline claim above re-checkable: `test -f` each cited receipt;
   OS rows re-parseable from `_CLOSURE_PLAN.md` §4 (court:
   `test/xaas/os_register_court_test.exs`, W981g).
2. WP-6 receipt appearing on disk would falsify the IN-FLIGHT(UNRECEIPTED)
   flag in the falsifying direction (it would resolve it).
3. WP-4 probe falsifier (from w608): any toolchain where
   `Map.update(%{}, :k, 1, &(&1+1))` applies `fun` on absent key reopens
   the ash_a2a no-manifestation finding.

## Standing

ALIVE: w614 gate, w608 court finding, w601q seal/tag, register lineage per
w984aw. PARTIAL_ALIVE: w613, w610, w609 (unfilled gates), w618 (uncommitted).
IN-FLIGHT: W605 court receipt, WP-2/WP-6 lanes, beam4pm/wasm4pm sweep legs,
9-commit fast-forward push. UNRECEIPTED: WP-6 charter. The loop stays in
Define/Measure: no account contact; the S1 account-precondition (operator
picks target accounts) remains unmet per CYCLE-0/1. Coordinator owns
integration; no commit made this lane.
