# W926 — Terminal Census Run 3 (supersedes W821's counts as terminal numbers)

- **Lane**: W926 (v26.10.6 terminal census, run 3)
- **Subject**: `/Users/sac/xaas` @ `fab56ae19051c6bc2b501e4a1d6c91312344e2c3` (branch `feat/playwright-surface`)
- **Note**: HEAD moved during the run window — lane started at `a0723bf6`; an in-flight
  lane committed and settled `lib/xaas/governance/audit_export_token.ex` mid-window
  (two gate attempts at `a0723bf6` broke compile on that file: Ash
  `increment/2` FunctionClauseError, then duplicate JSON:API route `patch /:id`).
  Per protocol I waited ~18 min for mtime settle, then all three certified runs below
  executed on the settled subject `fab56ae1`.
- **Build isolation**: `MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW926` (deletion was
  permission-denied in this lane session; left for coordinator per cleanup law).
- **Date**: 2026-10-07

## 1. Green gate

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW926 \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
```

```
Finished in 20.7 seconds (19.9s async, 0.8s sync)

Result: 1352 passed, 1 excluded
```

Exit 0. **1352 > 1347** (W821's gate) — the wave's ~15 repairs plus the new court files
raised the certified count by +5.

## 2. Census (`--include eu_ai_act_open_gap`)

```
Result: 33/34 passed, 1319 excluded
Failed: 1 test
```

Exit 2 (expected — the census run surfaces the honest gap by design). Delta check:

- 34 tests tagged `eu_ai_act_open_gap`; 33 pass, exactly **1 flunk**: EUAI-ACT 49.3
  (Art.49(3) deployer EU-database registration duty — no registration seam exists in
  this repo; `test/eu_ai_act/title_iv_v_test.exs:453`).
- **No new honest gaps** — delta equals the known open-gap set exactly.

## 3. Stability

Census repeated after 2-min settle:

```
Result: 33/34 passed, 1319 excluded
Failed: 1 test
```

Identical to run 1 — same 33/34, same single 49.3 flunk. **Verdict: STABLE.**

## Standing

W926 counts supersede W821's 1347/1348 as the terminal numbers for v26.10.6:

| metric | W821 | W926 (terminal) |
|---|---|---|
| green gate | 1347 passed, 1 excluded | **1352 passed, 1 excluded** |
| open-gap tagged | 1 flunk (49.3) | 34 tagged, 33 pass, **1 flunk (49.3)** — unchanged |
| stability | — | STABLE (identical repeat) |

Only standing honest gap: **EUAI-ACT 49.3** (Art.49(3) EU-database registration seam).
