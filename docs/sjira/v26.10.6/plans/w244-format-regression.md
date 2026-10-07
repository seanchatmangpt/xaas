# W244 Format-Regression Receipt

- **Subject**: repo `/Users/sac/xaas`, branch `feat/playwright-surface`, uncommitted tree after W237 format-only pass (39 files).
- **Scope**: regression check of most-touched suites after format-only changes. No fixes, no git actions.

## Command

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test \
  test/xaas/castle_refusal_negative_batch6_test.exs \
  test/xaas/semantics/r2rml_refusal_test.exs \
  test/xaas_web/live/witness_live_test.exs \
  test/xaas/operations/gymact_surface_test.exs \
  test/mix/tasks/xaas_refusal_render_test.exs \
  test/xaas/sjira/ard_court_test.exs
```

## Result: 90/91 passed, 1 failure

- Castle refusal batch6: pass
- R2RML refusal: pass
- Gymact surface: pass
- Refusal render (mix task): pass
- ARD court: pass
- **WitnessLive: 2/3 passed, 1 failure**

## Failure (deterministic, reproduced 3x incl. run-to-run and single-test `:67`)

```
1) test renders the typed empty state when no receipts exist (XaasWeb.WitnessLiveTest)
   test/xaas_web/live/witness_live_test.exs:67
   Expected truthy, got false
   code: assert has_element?(view, "[data-testid='witness-empty-row']")
```

- The empty-state test sees `@receipts != []` when it expects none.
- **Not a format regression**: `lib/xaas_web/live/witness_live.ex` and
  `test/xaas_web/live/witness_live_test.exs` are **untracked new files** (PW5 lane W1
  witness work, commit 3508f427 lineage) — they were not among the 39 formatted files.
  The failure is in that lane's uncommitted code, deterministic, and fails identically
  in isolation.
- Likely mechanism (not fixed, per lane constraints): the seeded receipt from a prior
  test is visible at mount — the `{:shared, self()}` sandbox sharing plus Ash create
  appears to leak the prior test's row into the empty-case test's connection. Owner lane
  decision needed.
- Pre-existing-vs-introduced: **pre-existing on this tree** (untracked new lane code),
  not introduced by the W237 format pass. All 39 formatted-file suites are green.

## W257 isolation fix

- **Subject**: repo `/Users/sac/xaas`, branch `feat/playwright-surface`, integration lane W257.
- **Change (test-only)**: `test/xaas_web/live/witness_live_test.exs` — the
  "renders the typed empty state when no receipts exist" test now runs
  `Repo.delete_all(CertifiedReceipt)` inside its sandboxed checkout before
  mounting, so prior tests' seeded rows (and e2e-w55 rows) visible through the
  shared `{:shared, self()}` sandbox no longer mask the empty branch. A
  sandboxed bulk `delete_all` was acceptable per lane contract; no lib edits.
- **Verification**:
  - Single suite: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_TEST_PARTITION=w257 mix test test/xaas_web/live/witness_live_test.exs` → **3 passed**.
  - W244 combined set (same 6 files as above, `MIX_TEST_PARTITION=w257`): **91 passed, 0 failures**.
- **Environment note**: the shared `xaas_test` database was in a broken
  migration state (`duplicate_column spg_graph_id on actuation_intents`,
  crash in Ecto migrator, reproducible 2x) — pre-existing, unrelated to this
  change; isolated via `MIX_TEST_PARTITION=w257` fresh create+migrate.
- **Standing**: ALIVE (observed execution on this tree); no git actions taken.

## W268 operations

- **Date**: 2026-10-06 (integration lane W268, v26.10.6 convergence)
- **Command**: `cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/operations 2>&1 | tail -4`
- **Result**: `49 passed, 5 excluded` — green (dir-level coverage of the W237
  `gymact_surface.ex` format; extends W244's file-level verification).
- **Standing**: ALIVE (observed execution on this tree); no fixes, no git.

## W272 sa2a

- **Date**: 2026-10-06 (integration lane W272, v26.10.6 convergence)
- **Command**: `cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/sa2a 2>&1 | tail -4`
- **Result**: `102 passed, 18 skipped, 1 excluded` — green (dir-level
  coverage of the W237 post-format `court_stale_plan`/`execute`/`route`
  sources; os_mon shutdown lines in tail are benign).
- **Standing**: ALIVE (observed execution on this tree); no fixes, no git.

## W296 post-W257

- **Date**: 2026-10-06
- **Subject**: combined 6-file re-run on this tree after the W257 witness
  isolation fix landed (W244's 90/91 expected to be 91/91).
- **Command**: `cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas_web/live/witness_live_test.exs test/xaas/castle_refusal_negative_batch6_test.exs test/xaas/semantics/r2rml_refusal_test.exs test/xaas/operations/gymact_surface_test.exs test/mix/tasks/xaas_refusal_render_test.exs test/xaas/sjira/ard_court_test.exs 2>&1 | tail -4`
- **Result**: `91 passed` — 91/91, no failures, no skips in tail. The
  W244 90/91 shortfall is closed by the witness isolation fix (os_mon
  shutdown lines in tail are benign).
- **Standing**: ALIVE (observed execution on this tree); no fixes, no git.
