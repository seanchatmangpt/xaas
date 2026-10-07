# W657 — OS-20 consolidation refresh (v26.10.6)

Lane W657, v26.10.6 campaign, OS-20 consolidation refresh (supersedes W620's snapshot,
which predated W603's completion + the W609 straggler). Date: 2026-10-06.
Sole file write: this receipt + the OS-20 row in `_CLOSURE_PLAN.md` §4 (task-assigned).

## 1. W603 receipt check

`docs/sjira/v26.10.6/plans/w603-ash-pplan-map-update.md` — **PRESENT**.
Verdict: 8/8 sites patched (§1 table), dual-safe `case Map.fetch` idiom, compile exit 0
(152 files, pinned toolchain, `_build-laneW603`). Regression test
`test/map_update_absent_key_test.exs` (3452 B). **§6 result line is still
`(filled at run completion)` — the suite verdict was never filled.** The follow-up
capture lane `plans/w610-ash-pplan-suite-capture.md` is **GATED(load)**: 12 checks over
~65 min, min 1-min load 35.84 vs ≤10.0 admissibility threshold; `mix test` never ran;
no counts claimable. W603 receipt status = verdict-pending, not in-flight-code.

## 2. Per-repo on-disk verification (real recount, 2026-10-06)

Python multiline regex `case\s+Map\.fetch.*?:error\s*->\s*Map\.put` over `lib/**/*.ex`
per repo (same method as W620):

```
beam4pm  sites: 3   files: 2
ash_a2a  sites: 14  files: 9
ex4pm    sites: 36  files: 15
ash_pplan sites: 8  files: 7
```

Total **61 / 61** — matches the w525d census (3 + 14 + 35+1 W609 + 8) exactly. No drift
since W620. Regression test files, all PRESENT:

| repo | test file | bytes |
|---|---|---|
| beam4pm | `test/beam4pm_w601_map_update_dual_safe_test.exs` | 2305 |
| ash_a2a | `test/ash_a2a/dual_safe_map_update_test.exs` | 5524 |
| ex4pm | `test/w604_map_update_dual_safe_test.exs` | 3652 |
| ex4pm | `test/w609_oracle_site_test.exs` | 1714 |
| ash_pplan | `test/map_update_absent_key_test.exs` | 3452 |

## 3. Consolidated table

| repo | sites patched (disk/census) | regression test | suite verdict (from landed receipts) | lane receipts |
|---|---|---|---|---|
| beam4pm | 3/3 | present | narrow 39/0; full 1562/1565 — 3 failures pre-existing/gate-adjacent; w601 test file still needs `bpm:HandAuthoredSource` admission | w601 |
| ash_a2a | 14/14 | present | 3720 passed / 0 failed, exit 0 | w602 |
| ex4pm | 36/36 (35 + 1 W609) | both present | 896 passed / 0 failed, exit 0; W609 gates 2/9/30, no skips | w604, w609 |
| ash_pplan | 8/8 | present | **NO receipt-grade suite** — W603 §6 unfilled; W610 GATED(load); W291 narrow GREEN only | w603 (pending), w610 (GATED) |

## 4. Remaining items

1. **ash_pplan full-suite verdict** — fill W603 §6 or rerun W610 when machine load ≤10.
2. **Coordinator commits ×4** — verified 2026-10-06: all four repos' working trees still
   carry the (uncommitted) OS-20 patches (`git status --porcelain` non-empty in
   beam4pm, ash_a2a, ex4pm, ash_pplan; HEADs 813eb924 / 07180bd3 / 9f7aecd / 414a393).
3. **beam4pm `bpm:HandAuthoredSource` admission** for the w601 dual-safe test file
   (ontology.ttl + manifest regen) to clear AuthorshipGate findings.

## 5. OS-20 closure

- Site-level: **61/61 = 100%** (verified on disk, census-exact).
- Receipt-level: 4/5 legs with witnessed suites (w601, w602, w604, w609); ash_pplan
  patched + compiled, suite capture twice gated → **closure ≈ 80% receipts / 100% sites**.
