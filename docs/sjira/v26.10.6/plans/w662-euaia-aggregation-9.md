# W662 — EU-AI-Act aggregation-9 (FINAL census receipt)

Date: 2026-10-07 · Repo: /Users/sac/xaas @ `feat/playwright-surface` · Build root: `_build-laneW662`

## Commands (real output)

### 1. Green gate (open gaps excluded)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW662 \
  mix test --include eu_ai_act --exclude eu_ai_act_open_gap test/eu_ai_act/
```

Result: **1120 passed, 0 failures** (exit 0). GREEN.

### 2. Honest census (no exclusion)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW662 \
  mix test --include eu_ai_act test/eu_ai_act/
```

- Run A (00:36): **aborted at compile** — transient sibling edit: stray backtick in
  `test/eu_ai_act/art50_deepening_test.exs:32` (lane W665 file, rewritten at 00:36 mid-run;
  content references `msg-w665-lawful`). Waited 2 min, retried once per contract.
- Run B (retry): **1143/1153 passed, Failed: 10**
- Run C (title extraction re-run): same 10 failures listed below (set shifted vs. run B:
  `title_vi_xiii_test.exs:780` failed in B, passed in C — sibling churn mid-census).

## Census failures — per-title attribution (Run C, latest full observation)

| # | File | Suite | Title |
|---|---|---|---|
| 1 | test/eu_ai_act/art15_deepening_test.exs | Art15DeepeningTest | DatasetAdmission W1-slice bound under seeded perturbation — typed refusals: empty, incomplete, and one-sided populations |
| 2 | test/eu_ai_act/art15_deepening_test.exs | Art15DeepeningTest | RobustMargin adversarial property sweeps — monotone penalty: larger epsilon never turns a refusal into ADMITTED |
| 3 | test/eu_ai_act/art15_deepening_test.exs | Art15DeepeningTest | RobustMargin typed refusals — non-1-arity margin closure refuses MALFORMED_MARGIN_INPUT (not FunctionClauseError) |
| 4 | test/eu_ai_act/art15_deepening_test.exs | Art15DeepeningTest | RobustMargin typed refusals — non-numeric margin constant refuses MALFORMED_MARGIN_INPUT atom |
| 5 | test/eu_ai_act/art15_deepening_test.exs | Art15DeepeningTest | DatasetAdmission W1-slice bound under seeded perturbation — perturbation below the bias bound stays ADMITTED and W1 <= bound |
| 6 | test/eu_ai_act/art15_deepening_test.exs | Art15DeepeningTest | RobustMargin adversarial property sweeps — empirical-Lipschitz monotonicity in sample count (lower bound only grows) |
| 7 | test/eu_ai_act/art15_deepening_test.exs | Art15DeepeningTest | RobustMargin adversarial property sweeps — ADMITTED region is downward-closed in the margin |
| 8 | test/eu_ai_act/art73_chain_deepening_test.exs | Art73ChainDeepeningTest | AuthorityChannel.transmit refuses malformed report inputs, typed |
| 9 | test/eu_ai_act/art73_chain_deepening_test.exs | Art73ChainDeepeningTest | determinism: same evidence set -> identical report, order-insensitive id |
| 10 | test/eu_ai_act/art50_deepening_test.exs | Art50DeepeningTest | 50.2b typed kernel refusals behind the disclosure claims (real module calls) — expected `{:error, :REFUSED_EUAIA_EMOTION_RECOGNITION}`, got `{:ok, :admitted}` |

Grouping: 7× Art15DeepeningTest (RobustMargin / DatasetAdmission W1-slice), 2×
Art73ChainDeepeningTest (AuthorityChannel.transmit typed refusal + report determinism),
1× Art50DeepeningTest (50.2b emotion-recognition typed kernel refusal — refusal not wired:
kernel returns `{:ok, :admitted}` where a typed REFUSED is required).

## Verdict

**NOT TERMINAL.** Zero open gaps only holds under the `eu_ai_act_open_gap` exclusion
(1120 GREEN). Without the exclusion, 10 failures remain across three deepening suites
(Art15 ×7, Art73 ×2, Art50 ×1), and the failure set was not stable run-to-run (one
TitleVIXIII failure present in run B, absent in run C) — sibling lanes were landing edits
during the census. "ZERO TYPED OPEN GAPS ACROSS ALL LINES — terminal state" is therefore
NOT claimable on this subject; the exact falsifier (census with zero failures on a stable
tree) did not pass.

Standing: PARTIAL_ALIVE (gate GREEN at 1120; census 1143/1153, 10 open, churn-affected).
