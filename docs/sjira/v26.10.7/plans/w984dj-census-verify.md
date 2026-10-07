# W984dj — Independent EU AI Act Census Verification (Fleet Seal Item 5)

Lane: W984dj, wave v26.10.7. Date: 2026-10-07.

## Subject

- Repo: `/Users/sac/xaas`
- HEAD at run: `f391159272c9ec4d31f4ec25b79b9448590b3b7b` (branch `feat/playwright-surface`)
- Working tree: in-flight lane state (uncommitted docs/test edits present); source tree as at HEAD plus open lanes. Census run used the live tree, not a clean checkout — disclosed.

## Command (real, executed)

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dj \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
```

Fresh lane build root `_build-laneW984dj` (cold compile of full deps + app, ~426 MB);
deleted after the run per lane-lease cleanup law (`ls` confirms gone).

## Result (real tails)

```
Finished in 38.8 seconds (38.5s async, 0.3s sync)

Result: 1352 passed, 1 excluded
[exited with code 0]
```

- **Passed: 1352 / Failed: 0 / Excluded: 1 (open-gap tag)** — matches the expected
  1,352/0/1 statutory census integrity figure witnessed at W633/W641, now re-witnessed at
  the newest HEAD (tree includes GraphlawWasm, anatomy wiring, ledger export modules —
  no regression in the census surface).
- Compile warnings only (type warnings in `test/eu_ai_act/title_vi_xiii_test.exs`,
  pre-existing); zero compile aborts, zero test failures, zero flakes. No
  W638/W640 in-flight interference observed.

## Standing

ALIVE — census integrity `1,352/0/1` independently witnessed at current seal-candidate
head `f3911592`. Seal checklist item 5 can cite this receipt as the fresh witness.

## Transport notes

Two background invocations were killed by the harness background time cap (600 s) during
cold compile; third invocation with max timeout completed. Compile was resumed from the
persistent build root each time — no test was run under a partial or different subject.
No other transport failures.

## Replay

Same command above on any checkout at `f3911592` (or descendant; counts may move on
descendants by design — this receipt stands only for `f3911592`).
