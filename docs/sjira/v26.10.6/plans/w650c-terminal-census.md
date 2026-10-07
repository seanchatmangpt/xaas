# W650c — Terminal Census Receipt (EU AI Act wave)

Subject: /Users/sac/xaas @ feat/playwright-surface, lane build root `_build-laneW650c`.
Census window: 00:34–01:07 PDT 2026-10-07.

## Census-time hazard (moving tree)

`art15_deepening_test.exs` was rewritten at 00:59 and `title_iii_test.exs` at 00:49 —
DURING the census. Early runs (gate 00:34 GREEN 1120; census1 10 fail; census2 11 fail,
different set) measured a moving tree. The stable post-quiesce state is census3 / gate2
(identical result, run twice).

## 1. Green gate (first run, 00:34)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650c \
  mix test --include eu_ai_act --exclude eu_ai_act_open_gap test/eu_ai_act/
→ Result: 1120 passed, exit 0  (GREEN at 00:34)
```

**Re-run at ~01:07 on the quiesced tree: 1149/1153 passed, 4 FAILED, exit 2 — GATE NOW RED.**
Post-00:34 lane writes (art15_deepening 00:59, title_iii 00:49) regressed the gate. The
4 failures are untagged, so the `--exclude eu_ai_act_open_gap` filter does not remove them.

## 2. Honest census (no exclude) — final stable state

`mix test --include eu_ai_act test/eu_ai_act/` → **1149/1153 passed, 4 failed, exit 2**
(1120 + 33 open_gap-tagged tests = 1153 total). NOT zero-failure. Typed OPEN_GAPs:

| # | File | Test | Defect |
|---|------|------|--------|
| 1 | art15_deepening_test.exs | "non-numeric margin constant refuses MALFORMED_MARGIN_INPUT atom" | `RobustMargin.admit("ten", 1.0, 1.0, 1.0)` raises **CaseClauseError** at `lib/xaas/semantics/robust_margin.ex:107` — module lacks the malformed-margin guard clause |
| 2 | art15_deepening_test.exs | "non-1-arity margin closure refuses MALFORMED_MARGIN_INPUT (not FunctionClauseError)" | same root cause as #1 (`robust_margin.ex:107`) |
| 3 | art15_deepening_test either | "typed refusals: empty, incomplete, and one-sided populations" | **ArithmeticError** raised in the TEST helper `sample/2` (`value * 2.0` with `1.0e308` overflows before `DatasetAdmission.admit/2` runs) — test-side overflow bug at `art15_deepening_test.exs:172,262` |
| 4 | title_iii_test.exs | "EUAI-ACT 15.5.s3 — EVIDENCED (W540): The technical solutions to address AI specific vulnerabilities…" | `VulnerabilityLifecycle.respond(ticket, ...)` returns `{:error, :REFUSED_LIFECYCLE_SKIP}` where the test expects `%{state: :RESPONDED}` (`lib/xaas/semantics/vulnerability_lifecycle.ex:98-106` — respond only accepts from `:TRIAGED`; the deepening path arrives in a different state) |

## 3. Per-title zero-gap verification (`--include eu_ai_act`, no exclude)

| Title file | Result | Verdict |
|---|---|---|
| title_i_test.exs | 112 passed | GREEN, zero gaps |
| title_ii_test.exs | 40 passed | GREEN, zero gaps |
| title_iii_test.exs | 390/391 passed | **1 OPEN_GAP** (#4 above) |
| title_iv_v_test.exs | 65 passed | GREEN, zero gaps |
| title_vi_xiii_test.exs | 476 passed | GREEN, zero gaps |
| art73_chain_deepening (per-file) | 8 passed | GREEN (census-run failures were async order-dependence, passes in isolation and in census3) |
| art50_deepening (per-file) | 7 passed | GREEN |
| counterfactual (per-file) | 26 passed | GREEN (census2 failure was order-dependence; passes in census3) |

## 4. TERMINAL verdict

**NOT TERMINAL. 4 typed OPEN_GAPs remain; the green gate is RED on the current tree.**

- OPEN_GAP-1/2: `Xaas.Semantics.RobustMargin.admit/4` malformed-input clauses missing
  (`lib/xaas/semantics/robust_margin.ex:107`).
- OPEN_GAP-3: Art15 deepening test helper overflows before the module is exercised
  (`test/eu_ai_act/art15_deepening_test.exs:172,262`).
- OPEN_GAP-4: `Xaas.Semantics.VulnerabilityLifecycle.respond/2` state-machine gap vs the
  W540 15.5.s3 deepening expectation (`lib/xaas/semantics/vulnerability_lifecycle.ex:98`).

Additionally, the wave is not quiesced: title_iii (00:49) and art15_deepening (00:59)
changed mid-census. A re-census is required once the tree stops moving.

Census corpus size: 1153 tests (1068 corpus + Art 56 + deepening + counterfactual + Art 73).

Flakiness note: two census runs showed 10 then 11 failures with different membership while
files were being rewritten concurrently; a separate order-dependence class exists
(art73/art50/counterfactual fail under some async orderings, pass in isolation and in the
final census). Root cause not diagnosed in this lane (out of contract scope).
