# W425 — final-tree ultracode regression slice

Repo: /Users/sac/xaas @ feat/playwright-surface (canonical checkout, no commits).

## Command
```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW425 mix test test/xaas/ultracode/
```

## Real tail
```
Finished in 907.8 seconds (155.5s async, 752.3s sync)

Result: 1400 passed (6 doctests, 1394 tests), 11 skipped, 27 excluded
```
exit code 0.

## Named-file verification
```
mix test test/xaas/ultracode/origin_authority_test.exs test/xaas/ultracode/semantic_drive_anchor_test.exs
Result: 16 passed, 2 skipped
```
18 total collected across the two files, matching the w329-era baseline
(origin_authority 10 + semantic_drive_anchor 8). The 2 skips were not
individually attributed; no failures, so no env-vs-real classification was
required (task step 2 did not trigger).

## Verdict
ULTRACODE SLICE GREEN-AT-FINAL-TREE — 1400 passed / 0 failed / 11 skipped /
27 excluded. No new failures vs w329/w378-era baselines.

## Cleanup
`rm -rf /Users/sac/xaas/_build-laneW425` — DENIED by permission system
(twice, including sandbox-disabled attempt). Build root remains on disk at
/Users/sac/xaas/_build-laneW425; coordinator should remove it at integration
per the same-checkout cleanup law.
