# W650h33c — Commit Receipt

## Identity
- **Lane**: W650h33c (v26.10.7 fleet seal)
- **Task**: Land W650h10's repaired causal_receipt court (landed-uncommitted)
- **Subject**: commit `32b72c4fcbc06bc466b4cd5ffaad96bc7e60f42e`
- **Branch**: `feat/playwright-surface`, pushed fast-forward `d51119c5..32b72c4f` to origin
- **Repo**: /Users/sac/xaas

## Files (exact pathspec, 2)
- `test/xaas/causal_receipt/process_receipt_depth_test.exs` (untracked, +153)
- `docs/sjira/v26.10.6/plans/w650h10-owner-defect.md` (untracked, +98)

## Freshness verification (pre-gate)
- Test file untracked, mtime 2026-10-07 17:37 PDT (47 min old at gate time); receipt
  mtime 18:24 PDT. W650h10's lane is done — no concurrent writer.
- Before-state history: court had a CompileError, so 0/5 tests ever executed;
  after W650h10's repair: 5/5 x2 fresh roots (per w650h10 receipt).

## Gates (real commands, this lane, MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650h33c)
1. `mix compile --force` (fresh root) — **EXIT=0**
2. `mix test test/xaas/causal_receipt/process_receipt_depth_test.exs` — **5 passed, 0 failed** (0.1s, exit 0)
   - Only noise: PromEx/Grafana dashboard-upload nxdomain warnings (no Grafana locally); unrelated.

## Consequence
Court's 5 depth tests are now executed-and-green on a committed subject, first time
in history (previously CompileError'd, never ran).

## Replay
```
git show 32b72c4f --stat
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=<fresh> mix compile --force
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=<fresh> \
  mix test test/xaas/causal_receipt/process_receipt_depth_test.exs   # expect 5 passed
```

## Standing
**ALIVE** — exact subject `32b72c4f`, observed execution (compile + court green).

## Cleanup
Lane build root `_build-laneW650h33c` deleted at integration (lane-lease law).
