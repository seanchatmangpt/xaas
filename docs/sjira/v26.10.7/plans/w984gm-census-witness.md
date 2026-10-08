# W984gm — eu_ai_act Census Witness Receipt

Date: 2026-10-08T03:58Z (UTC). Lane: W984gm. No commit (per lane contract).

## Subject

- HEAD at run: `102c178294297764ddbe32eeb72104dff50a3bbd` (branch `feat/playwright-surface`)
- Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984gm mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap`

## Result

Exit code 0.

```
Finished in 19.5 seconds (18.4s async, 1.0s sync)

Result: 1388 passed, 1 excluded
```

## Anomaly classification

None. 0 failures, 0 errors. Compile warnings only (pre-existing type warnings in
`test/eu_ai_act/title_vi_xiii_test.exs` around `is_binary(reason)` asserts —
non-failing, informational).

## Floor verdict

MEETS FLOOR: 1388 passed >= 1388 floor, 0 failed, 1 excluded (expected).
Fresh witnessed number post-wave confirmed; seal chain may consume this receipt.
