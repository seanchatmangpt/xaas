# W821 — Terminal Census 2 (EU-AI-Act suite)

- **Date**: 2026-10-07 (04:55–05:20 PDT)
- **Subject**: `/Users/sac/xaas` @ `a0723bf61a1c6058bdcd2d0202c9519840182a5e`, branch `feat/playwright-surface`
- **Mandate**: successor to W650c — certify the terminal census W662/W650c could not (tree was churning). Successor lane to the W778 green gate / W779-W815 open-gap ledger.
- **Command env**: `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW821`

## Results

| # | Run | Command | Result | Exit |
|---|-----|---------|--------|------|
| 1 | Census (incl. open gap) | `mix test test/eu_ai_act --include eu_ai_act --include eu_ai_act_open_gap` | **1347/1348 passed, 1 failed** | 2 (via tail pipeline; failure row present) |
| 2 | Green gate (excl. open gap) | `mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap` | **1347 passed, 1 excluded** | 0 |
| 3 | Census repeat after 2-min settle | same as run 1 | **1347/1348 passed, 1 failed** | 2 |

## Delta check

Census total (1348) − gate passed (1347) = **1 = exactly the one excluded open-gap test**. Requirement met.

## Stability verdict

**DETERMINISTIC.** Both census runs produced identical counts (1348/1347/1) and the identical
single failure:

```
1) test EUAI-ACT 49.3 — OPEN_GAP: Before putting into service or using a high-risk AI system listed in Ann (Xaas.EUAIAct.TitleIVVTest)
   test/eu_ai_act/title_iv_v_test.exs:453
   OPEN_GAP: Art.49(3) deployer EU-database registration duty before putting into service — no registration seam exists in this repo
   code: flunk("OPEN_GAP: " <> unquote(detail))
```

This is the known honest typed open gap (49.3, W779/W815 ledger), failing via its explicit
`flunk/1` — not a regression, not a flake, not a sibling-in-flight artifact. No other failures
appeared in any run; no retry protocol (sibling-edit wait 2 min + retry) was needed. Tree was
at the same SHA a0723bf6 across all three runs.

## Standing

**ALIVE (terminal census certified).** The census-minus-gate delta equals the open-gap count,
the gate is 1347/1347 exit 0, and repeated census membership is deterministic. This closes the
certification W662/W650c could not make.

## Notes

- `_build-laneW821` was left in place (lane build-root deletion denied by session permissions);
  coordinator should remove it at integration per the lane-lease cleanup law.
- No code changes made; receipt is the only file written by this lane.
