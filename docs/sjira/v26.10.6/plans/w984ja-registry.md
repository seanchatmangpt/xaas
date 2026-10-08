# W984ja — EU-AI-Act corpus registry audit receipt (2026-10-07)

Lane W984ja, shared canonical checkout `/Users/sac/xaas`, branch
`feat/playwright-surface` (no branch switch, no commit, no stash, no lane
build root left behind).

## Subject

`test/eu_ai_act/` registry (README.md file map + census headline) vs. the
actual test tree; tag conventions in `test/test_helper.exs`; intentional
OPEN_GAP marker count; `deepening_map` in `title_iii_test.exs`.

## Commands / evidence (real output)

- `ls test/eu_ai_act/` → 25 entries: 24 `.exs` files + `support/`
  (`corpus_loader.ex`) + `README.md`.
- `grep -n "moduletag\|@tag" *.exs` → tag census below.
- `grep -n "deepening_map" title_iii_test.exs` → defined at line 521;
  kind-based (`:dataset_gate`, `:audit_chain`, ...), references no file
  paths; suite compiled and ran green, so no path-drift class applies.
- Honest census:
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/eu_ai_act
  --include eu_ai_act --include eu_ai_act_open_gap` →
  **1388/1389 passed, 1 failed = `EUAI-ACT 49.3 — OPEN_GAP`
  (Xaas.EUAIAct.TitleIVVTest, title_iv_v_test.exs:453)** — finished 35.5s.
- Green gate:
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/eu_ai_act
  --include eu_ai_act --exclude eu_ai_act_open_gap` →
  run 1: 1387/1388 passed, 1 excluded, 1 failed (transient, identity not
  captured before re-run); run 2 (captured, `/tmp/w984ja_gate.log`):
  **1388 passed, 1 excluded, exit 0**.

## Registry check — file map vs disk

README "File map (per title)" registered 9 test files; 16 files on disk
were unregistered (orphan drift, not in any README table):
12 `art*_deepening_test.exs`, `counterfactual_deepening_test.exs`,
`title_ii_deepening_test.exs`, `eyerun_wire_deepening_test.exs`,
`not_applicable_completeness_test.exs`. All 9 registered files exist;
every registered module name matches disk (grep of `defmodule` lines).

## Drift table

| # | Drift | Evidence | Fix | Status |
|---|---|---|---|---|
| 1 | 16 test files present but absent from README file map | `ls` vs README file map | Added addendum table to `test/eu_ai_act/README.md` (file, module, scope, pattern + tag note) | FIXED (doc-only) |
| 2 | Census headline stale: claimed 1112/1118 with 5 open gaps (W651); reality 1389 tests, 1 open gap | census/gate runs above | Added W984ja re-run block (1388/1389, 1 gap = Art. 49.3; gate 1388 passed / 1 excluded / exit 0) and marked W651 numbers historical with gap lineage 37→24→19→10→5→1 | FIXED (doc-only) |
| 3 | `test_helper.exs` `:eu_ai_act` default-exclude wiring | line 68, comment lines 66-67; README "Suite wiring" section matches | none needed | NO DRIFT |
| 4 | OPEN_GAP marker count | census: exactly 1 failure = Art. 49.3 | none needed | MATCHES the "exactly the Art. 49.3 one" invariant |
| 5 | `deepening_map` (title_iii_test.exs:521) | kind map, no path claims; compiled green | none needed | NO DRIFT |

## Tag census (verified, not asserted)

- `@moduletag :eu_ai_act` on: smoke, title_i (main module), title_ii,
  title_iii (main), title_iv_v per-test `@tag :eu_ai_act` (2) +
  per-test `@tag :eu_ai_act_open_gap` (1 = Art. 49.3),
  title_vi_xiii (main), airo_grounding, counterfactual, and all 16
  deepening/audit files except noted below.
- Open-gap modules (`TitleIOpenGapsTest`, `TitleIIIOpenGapsTest`,
  `TitleVIXIIIOpenGapsTest`) carry `@moduletag :eu_ai_act_open_gap`
  with deliberately NO `:eu_ai_act` tag (exclude-before-include
  discipline); each emitted 0 tests — their `Lines.open_gaps()` lists
  are empty, consistent with the census.
- `title_ii_test.exs:225` has one `@tag :eu_ai_act_not_applicable`
  (sub-classification tag, not excluded by the gate).
- `art9x_risk_management_deepening_test.exs` additionally per-test tags
  7 tests with `@tag :eu_ai_act`.
- `test_helper.exs:68` puts `:eu_ai_act` on the default exclude list
  (W526); suite runs via `--include eu_ai_act`. No drift.

## Intentional OPEN_GAP count

Exactly **1**: Art. 49.3 deployer EU-database registration duty
(title_iv_v_test.exs:453, `Xaas.EUAIAct.TitleIVVTest`). The three
separate OpenGaps modules (Titles I, III, VI–XIII) contributed zero
tests. Matches the required invariant.

## Verification ladder

narrow (ls/grep static registry check) → unit (full suite census + gate
runs, real execution, real exit codes).

## Standing

- Registry doc (`README.md`) now matches disk: ALIVE (doc-only edits,
  no test logic touched).
- Suite itself: gate green (exit 0), census 1 intentional gap = ALIVE
  with 1 typed OPEN_GAP.

## Not fixed (disclosed)

- First gate run had 1 transient failure (test identity not captured
  before the re-run passed 1388/1388 exit 0). Recorded as an observed
  transient red; not a registry matter and not reproduced on re-run.
- Deepening/audit addendum rows were classified from on-disk module
  docstrings/tags, not re-derived lane-by-lane provenance; scope/pattern
  columns are descriptive summaries.
