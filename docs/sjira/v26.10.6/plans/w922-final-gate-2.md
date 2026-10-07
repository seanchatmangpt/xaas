# W922 — Final Gate 2 (EU AI Act green gate + census + full-suite sanity)

Standing: PARTIAL_ALIVE (gates 1–2 green/consistent; gate 3 majority green with
deterministic residue classified). Subject: `/Users/sac/xaas` working tree,
HEAD `fab56ae19051c6bc2b501e4a1d6c91312344e2c3` at gate-1 start (canonical
checkout; note HEAD moved from `a0723bf6` during the wave — siblings were
committing and editing lib mid-flight, see Transport).

Lane: W922 · MIX_ENV=test · MIX_BUILD_ROOT=_build-laneW922 · elixir 1.20.2-otp-28 (asdf shims).

## Gate 1 — EU AI Act green gate

```
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW922 mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
```

Real tail (log `/tmp/w922_gate1.log`):

```
Result: 1352 passed, 1 excluded
EXIT=0
```

**1352 passed, 1 excluded, 0 failed.** Growth vs W778's 1347: +5 from the new
deepening files. The 1 excluded is the tagged `eu_ai_act_open_gap` test
(EUAI-ACT 49.3).

## Gate 2 — Open-gap census

```
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW922 two runs:
  mix test test/eu_ai_act --include eu_ai_act_open_gap
```

Real tail (`/tmp/w922_gate2.log`):

```
Result: 33/34 passed, 1319 excluded
Failed: 1 test
```

The single failure is exactly the expected typed open gap:

```
1) test EUAI-ACT 49.3 — OPEN_GAP: Before putting into service or using a
   high-risk AI system listed in Ann (Xaas.EUAIAct.TitleIVVTest)
   test/eu_ai_act/title_iv_v_test.exs:453
   OPEN_GAP: Art.49(3) deployer EU-database registration duty before putting
   into service — no registration seam exists in this repo
```

Delta consistency: 34 open-gap-tagged tests in census; exactly one fails, and it
is 49.3. **No new typed open gaps** beyond 49.3's known flunk row. Census
arithmetic reconciles with gate 1 (1352 green + 34 tagged open-gap tests; the
49.3 flunk is the designed typed gap).

## Gate 3 — Full-suite sanity

```
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW922 mix test test/xaas/ test/xaas_web/ --exclude wip
```

Real tail (`/tmp/w922_gate3.log`):

```
Result: 4034/4070 passed (15/15 doctests, 4019/4055 tests), 32 skipped, 155 excluded
```

36 failures on the hot run; classified by two isolated reruns
(`/tmp/w922_retry1.log`, `/tmp/w922_retry2.log`):

### Deterministic (failed all 3 runs) — 10

| cluster | tests | classification |
|---|---|---|
| `test/xaas/ledger/reversal_deepening_test.exs` W968c SPEC-27 (:reverse) | 3 | **Regression candidate** (ledger/transfer area touched by recent waves) |
| `test/xaas/ash_surface_drift_{guard,mutation}_test.exs` | 2 | **Regression**: committed `priv/ash_surface` artifacts drifted from regeneration (`aria.json`, `live_view.json`, `surface_contract.json`, `xaas_ash_surface_client.mjs`) — consistent with many lib changes landing without regen |
| `test/xaas/actuation/run_idempotency_deepening_test.exs` (d1/d2/d3) | 3 | **Regression candidate (isolation)**: (d1) asserts `Ash.read!(ActuationIntent) == []` and finds a foreign `ActuationIntent` row (idempotency key `curate-deactivate:...:1791375390931`) — sandbox/isolation or a sibling test's leakage; d2/d3 share the file |
| `test/xaas/topology_guard_test.exs` | 1 | **Sibling-in-flight / working-tree state**: `File.read!` crash scanning a git-indexed path absent from disk mid-wave |
| `test/xaas/zcode_plugin/projection_test.exs` | 1 | **Sibling-in-flight**: sibling artifact `generated/castle_bridge/innovation.json` created 00:58 by another lane; test refutes top-level `generated/` |

### Flake / sibling-mid-flight (passed on isolated rerun) — 26

Castle refusal cluster (13 — `port_died` port/EXIT noise under full-suite
parallel load), audit_export_token controller + route-collision court (5),
NextRead ranker/LiveView/nextread deepening (4), health_court (1),
semantic_drive (1), authority_decoupling (1), audit_log_entry (1). All green
when the same files ran with fewer concurrent collaborators. One
(`actuation_refusal_negative_test.exs` nil-subject) passed on retry 2 → flake,
not deterministic.

## Transport failures

- Two gate-1 attempts crashed at compile in `lib/xaas/governance/audit_export_token.ex:121`:
  a sibling lane was live-editing that file during the wave (observed three
  distinct contents across runs: positional `increment(:use_count, 1)` →
  `expr(use_count + 1)` variant → settled `increment(:use_count, amount: 1)`,
  which compiles clean). Waited for mtime stability (3 min) and retried per the
  wait-and-retry instruction; gate 1 then passed.
- HEAD advanced `a0723bf6` → `fab56ae1` mid-run (sibling commits).

## Replay

```bash
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW922 \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap   # 1352 passed, 1 excluded
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW922 \
  mix test test/eu_ai_act --include eu_ai_act_open_gap                        # 33/34, only 49.3 flunks
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW922 \
  mix test test/xaas/ test/xaas_web/ --exclude wip                            # 4019/4055 tests, 36 fail (classified above)
```

## Standing + handoff

- EU AI Act final gate: **ALIVE** — 1352 green, open-gap delta exactly 49.3, no new typed gaps.
- Full-suite: **PARTIAL_ALIVE** — 4019/4055; the 10 deterministic failures are
  coordinator-routable: 2 ash_surface regen-needed (real regression), 3 ledger
  W968c SPEC-27 (real regression), 3 run_idempotency isolation, 2 sibling
  working-tree artifacts (`generated/castle_bridge/`, topology-guard scan race).
- No commits made; `_build-laneW922` deleted per cleanup law.
