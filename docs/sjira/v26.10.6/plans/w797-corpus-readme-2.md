# W797 — Corpus README deepening-wave refresh (lane receipt)

- **Lane**: W797, xaas v26.10.6, branch `feat/playwright-surface`, HEAD `a0723bf6`.
- **Subject**: `docs/eu_ai_act/corpus-README.md` — appended "Current status
  (W797 refresh, 2026-10-07)" section; earlier sections (W646 refresh)
  untouched. No lib/test changes. No commit (coordinator owns commits).
- **Standing**: PARTIAL_ALIVE — document-only lane; every new claim cites a
  `test -f`-verified receipt path or a real `ls`/grep executed this session.

## Commands (real, executed this session)

1. `ls test/eu_ai_act/` → 16 `*_test.exs` files + `README.md` + `support/`
   (`corpus_loader.ex`). Deepening files present: art15, art50, art73_chain,
   art86_rights, art99_enforcement, title_ii_deepening,
   counterfactual_deepening, counterfactual, eyerun_wire_deepening.
2. `wc -l test/eu_ai_act/*.exs` → 6728 loc total (per-file figures in the
   README table are from this run).
3. `test -f` on all 12 cited receipt paths under `docs/sjira/v26.10.6/plans/`
   → all OK (list in README).
4. `grep 'exclude' test/test_helper.exs` → `:eu_ai_act` confirmed on the
   default exclude list.
5. `grep -n '@moduletag' test/xaas/semantics/...` →
   `declared_metrics_staleness_test.exs:16` tagged `:eu_ai_act`;
   `refusal_atom_census_test.exs` has NO `@moduletag` (untagged, runs by
   path only).
6. `ls docs/sjira/v26.10.6/plans/ | grep w778|w779` → neither receipt
   exists; both marked "not landed" in the README.

## Facts recorded (each cited in the README)

- **Run convention**: `--include eu_ai_act` mandatory; bare run is a
  vacuous pass ("All tests have been excluded", exit 0) — disclosed in
  `w666-ocel-egress-deepening.md`.
- **Gate count**: 1198/1200 passed, 2 failed — **as of the W760 receipt**
  (`w760-gate.md`, HEAD a0723bf6). W778 verification not landed; README
  carries the re-stamp requirement.
- **Open-gap tag**: runtime-inert per W760 (`--only eu_ai_act_open_gap`
  selects 0 of 1200); `@moduletag :eu_ai_act_open_gap` present in 4 title
  files. W779 diagnosis not landed; status recorded as
  "runtime-inert, undiagnosed pending W779".

## Not done / open

- No test run this lane (document-only; W760's run is the cited gate).
- W778 re-stamp and W779 re-stamp are explicit open hooks in the README.
