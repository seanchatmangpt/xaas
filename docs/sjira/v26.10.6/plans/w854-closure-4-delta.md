# W854 — Closure-plan §4 evidence-citation delta (consolidation-wave refresh)

- **Lane**: W854, xaas v26.10.6, branch `feat/playwright-surface`, HEAD `a0723bf6`
- **Date**: 2026-10-07
- **Write scope honored**: `docs/sjira/v26.10.6/_CLOSURE_PLAN.md` (§4 rows ONLY) + this
  receipt. No commit, no build root. All cited receipts verified with `test -f` on disk
  before citation.

## Rows changed (4)

1. **OS-16** — evidence-citation delta only; status unchanged from W700 (end-user
   disclosure surface remains open, v26.10.7+). Added: W806 disclosure-verification
   receipt (`plans/w806-disclosure-verify.md` — artifact verified court-by-court:
   w665 7/7, w703 4/4, w699 9/9, w723 16/16; §2c/§4 corrected in place; OS-16 stays
   open by design, "courts prove the enforcement substrate, not the disclosure") and
   the W703 plug-mount-order court (`plans/w703-plug-order-court.md` — refusal is BOTH
   -32600 AND marked, reorder-kill witnessed; endpoint.ex:99-100 order pinned).
2. **OS-19** — new evidence rows appended to the row's falsifier/standing cell:
   W814 full real release-audit run (`plans/w814-release-audit-run.md`): mock-grep
   gate half ALIVE (exit 0, `[]`); release-audit half BLOCKED(environment) —
   deterministic `File.Error` crash at `xaas.release_audit.ex:291` on
   tracked-but-deleted worktree files, 3/3 reproducible, typed finding F1 (same
   `File.read!` exposure at :156/:187/:256/:263/:287; rpc check at :344 already
   handles `:enoent`), release-contract standing UNKNOWN this wave. Enoent hardening
   repair assigned W845 — **IN_FLIGHT, no receipt on disk at W854 time** (verified
   `ls w845*` → absent).
3. **OS-21** — typed-catch-all leg citations added: W713 refusal-atom census court
   (`plans/w713-refusal-census.md` — real `File.read!` scans + real
   `risk_concept_for/1` calls over 7 semantics modules) and W732 type-set closure
   repair (`plans/w732-closure-repair.md` — `:REFUSED_EUAIA_MALFORMED_CANDIDATE`
   added to `@typedref_atoms`/`@type refusal_atom` + `describe/1` clause;
   VulnerabilityLifecycle `@type refusal`/`@spec new/1` divergence fixed).
4. **OS-20** — factual-drift fixes only, no new claims: the Progress chain said W603
   §6 was "STILL `(filled at run completion)`" and "ash_pplan NO receipt-grade suite"
   / "§6 fill remains pending". The on-disk `plans/w603-ash-pplan-map-update.md` §6
   is now FILLED (8/8 sites, commit `7eeaaa1`, compile exit 0, regression module 5/5
   exit 0, manufacture_test 9/10 with the sole failure adjudicated environmental in
   its §4; full-suite tail killed at the 2h limit under load 74-92, 4 failures all
   external-drift/contention class, none referencing the patched sites). Three
   sentences corrected in place, each marked W854 drift fix. W737/W804 epoch
   migrations confirmed NOT touching OS-20 (different surface: ultracode epoch
   identity/index, not Map.update sites) — no OS-20 claim derives from them.

## Receipts verified on disk (test -f)

w806-disclosure-verify.md, w665-art50-deepening.md, w703-plug-order-court.md,
w814-release-audit-run.md, w713-refusal-census.md, w732-closure-repair.md,
w603-ash-pplan-map-update.md, w657-os20-refresh.md, w664b-os20-consolidation2.md,
w621-admission-fuzz.md, w694-os-register-rederivation.md — all present.
`w845*` — absent (recorded IN_FLIGHT, not cited as evidence).

## Standing

- Plan file: PARTIAL_ALIVE — §4 rows now cite only on-disk receipts; OS-16/OS-19/OS-20/OS-21
  rows reflect the consolidation wave without status inflation (OS-16 end-user text
  surface still open; OS-19 audit run BLOCKED(environment) with F1 typed; OS-20
  receipt-grade §6 fact corrected, quiet-machine suite rerun still open).
- Falsifier for this delta: any cited path missing on disk, or a §4 sentence still
  asserting w603 §6 is unfilled — both currently fail (i.e. delta holds).
