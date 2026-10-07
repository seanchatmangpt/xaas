# W717 — Ultracode Run/Epoch/Receipt deepening (receipt)

- **Lane**: W717, xaas v26.10.6 campaign
- **Subject**: canonical checkout `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `a0723bf6`
- **Diff**: exactly one new test file, `test/xaas/ultracode/run_receipt_deepening_test.exs` (10 tests). No lib changes.
- **Standing**: ALIVE (observed execution on the exact subject; 10/10 real sandbox-Postgres Ash-action tests passing)

## Verification (real commands, real output)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW717 \
    mix test test/xaas/ultracode/run_receipt_deepening_test.exs --trace
Finished in 0.7 seconds (0.7s async, 0.00s sync)
Result: 10 passed
```

(Initial run took ~25 min: fresh `MIX_BUILD_ROOT=_build-laneW717` full compile, ~437 MB, deleted after the run.)

## What the tests prove (all against real rows, no mocks)

1. **Lifecycle (a)**: `Run create → :start` (first Epoch constructed via
   `Changes.CreateFirstEpoch`, `cycle == 0`, FK-bound `run_id`, `started_at`/`cycle == 1` on the Run)
   `→ epoch :start → :complete → Receipt :seal → Receipt.for_epoch/1` read-back with evidence intact,
   plus a raw-SQL cross-check of the epoch row's real FK value.
2. **Receipt without its epoch refuses (b)**: sealing against a nonexistent `epoch_id` is refused by
   the real DB FK (`ultracode_receipts_epoch_id_fkey`), surfaced by ash_postgres as
   `InvalidAttribute ... "does not exist"` — nothing persisted.
3. **Immutability (c)**: `Receipt` has no `:update`/`:destroy` action — immutability is by
   construction. Asserted by introspection AND a real failed mutation attempt (changeset for an
   unknown action raises `ArgumentError`); the sealed row's evidence is unchanged after the attempt.
4. **Fold determinism (d)**: the same admitted `RunTransitionAllowed` edge sequence
   (`running→suspended→running→completed`) folds two fresh Runs to identical terminal state
   (`:completed`, `terminal_at` set); terminal states are absorbing (all four attempted exits refuse
   with "is not an admitted edge", row unchanged); a genuinely illegal edge (`pending→completed`)
   refuses without folding.

## Typed findings (asserted in-file, not narrated)

- **GAP (identity NULL-distinctness)**: the DB index backing
  `identity(:unique_run_cycle, [:run_id, :cycle])` is Postgres `UNIQUE (org_id, run_id, cycle)`
  (org_id added by the multitenancy migration). Postgres UNIQUE treats NULLs as distinct, so for
  org-less Runs/Epochs — every internal fixture and unscoped caller — a duplicate `(run_id, cycle)`
  epoch is ACCEPTED, not refused. The org-scoped twin test proves the index fires once `org_id` is
  real. Candidate follow-up (not landed here, out of lane scope): a partial unique index on
  `(run_id, cycle) WHERE org_id IS NULL`.
- **Epoch transition floor real**: `EpochTransitionAllowed` refuses `:expected → :complete`
  ("must be in [:running]"), exercised as setup correctness inside test (c).

## EU AI Act tag decision

No `@moduletag :eu_ai_act`. No Art-line tie exists: `Xaas.Ultracode.Receipt` is an operational
evidentiary record of epoch outcomes; nothing in Run/Epoch/Receipt carries or processes personal
data or a log of processing under Art 12. Tagging would be an ungrounded adjacency.

## Gaps / notes

- No Art-12 tie (see above); receipts here are control-plane evidence, not personal-data logs.
- `Receipt.for_epoch/1` returns `{:ok, []}` for a nonexistent epoch — scoping-by-argument, no
  existence check; acceptable for the narrow internal read path.
- Lane build root `_build-laneW717` deleted after the final green run.
