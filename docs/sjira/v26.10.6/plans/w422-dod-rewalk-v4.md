# W422 — DoD Re-walk v4 (re-walk of §5 criteria 1–7 against receipts on disk, 2026-10-06)

Subject: /Users/sac/xaas @ feat/playwright-surface (canonical checkout, read-only re-walk; only this file written).
Method: every verdict below cites receipt files verified with `test -f` on disk today.
Supersedes the W206 walk (§5 status table currently in `_CLOSURE_PLAN.md`).

## Receipt-presence census (test -f, 2026-10-06)

**Present:** w176, w236, w300, w315, w317, w320, w323, w326, w327, w329, w332, w334,
w335 (+ coordinator addendum in-file), w343, w354, w364, w366, w371, w373, w378,
w379, w382, w390 (+ staging tree), w391, w395, w399.
**ABSENT (in-flight lanes, never guessed):** w291, w345, w386, w398, w403, w412,
w415, w416, w202 (standalone), w185.

## §5 Status Table Replacement (coordinator paste)

| DoD | verdict | closing lane / condition |
|---|---|---|
| 1 tests green | **PENDING (W398/W416)** — definitive 3235/0 witnessed (w300 `plans/w300-final-suite.md` @ d1db2b03; w315 `plans/w315-final-dod-suite.md` run 1: 3235 passed / 0 failed, 36 skipped, 91 excluded); bounded suites w329 (7 PASS + 1 lineage mismatch finding); refusal corpus w398 and web+accounts slice w416 have **no receipt on disk** → GATED-ON-W398/W416; opt-in witnesses w380/w388 (w386 absent from disk — NOT cited as evidence) | w398 final-tree refusal corpus receipt + w416 web+accounts slice receipt landing |
| 2 strict flags | **PENDING (operator P2-2 promotion)** — local legs MET: w335 local strict-compile legs + in-file coordinator addendum (ash_surface REGRESSED → OS-13 quarantine → w371 QUARANTINE-CLEAN 36/0 + re-verified EXIT=0 per w335 addendum); format leg w395 full-tree `mix format --check-formatted` exit 0. CI leg: w327 `closure-gates.yml` advisory-only (`continue-on-error: true`) | operator removes `continue-on-error` per job once green on main (w327) |
| 3 refusal coverage | **PENDING (W398)** — w176 delta 16 (recount, baseline 50→16); w236 capstone 86/0 (W202 delta-zero number witnessed via w236; w202 standalone absent); mutants: w320 4/6 killed (2 SURVIVED gaps) → w378/w379 typed unreachability adjudications (outcome (b), no kill test possible); w382 batch re-kills (castle idempotency KILLED, endpoint body-limit KILLED); ash_surface C′ 7/7 + C″ 5/5 ALIVE (w326); w398 refusal corpus absent → GATED | w398 receipt landing; then residual SURVIVED-gap dispositions |
| 4 clean tree | **PENDING (coordinator-gated)** — w334 witnessed HEAD FAILS its own root-sync drift condition; w390 staged the 8-file sync-output into `plans/w390-sync-output-staging/` (sha256 manifest); w354 per-item commit-ready census; w399 runbook amendments (G4/G5/G6 GAPs with staging adds). All receipts on disk; **commits still coordinator-gated** | coordinator commit lanes per w354/w399 staging maps |
| 5 verify ladder | **PENDING (W291)** — browser rung: w317 96 passed / 0 failed (96+2 skipped = 98 = --list); w391 adjudication VERDICT: PARTIAL (w381 86/10 contention explained). CLI rungs: w332 ex4pm 888/0 GREEN @ 9f7aecda; w343 ggen_igniter ALIVE 1555/0 @ 7dbcdb3a; w364 beam4pm FRESH @ OTP-29 fresh build root; w366 ash_a2a HEAD-READY. ash_pplan W291: **no receipt on disk** → IN-FLIGHT | W291 ash_pplan adjudication receipt landing |
| 6 frontier non-UNKNOWN | **PENDING (CI-gated)** — `_FRONTIER.md` row standings all ≠ UNKNOWN at last projection; wasm4pm standing is CI-gated (CI leg requires landed commits); gymact PARTIAL (w373: changed=no, coherence ALIVE, 26.10.6 everywhere) | wasm4pm CI confirm post-commit; gymact end-to-end falsifier or typed BLOCKED |
| 7 no new features | **MET (provenance legs)** — w323: UNTRACED 0 (9 literal-match misses reclassified, hard-untraced 0); w399 per-group verdicts CURRENT with typed GAP adds staged. Review-time enforcement per w153-v2 remains | review-time enforcement at w153-v2-ordered integration review |

## Method note

Verdicts rest only on `test -f`-verified receipts listed in the census above.
w291/w345/w386/w398/w403/w412/w415/w416/w202/w185 are absent from disk and are
marked in-flight / not cited, per lane contract.
