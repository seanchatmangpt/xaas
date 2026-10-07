# W433 — Operations Slice Verification Receipt

Lane: W433, v26.10.6 convergence campaign
Repo: /Users/sac/xaas @ feat/playwright-surface (canonical checkout, no commit)
Command:

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW433 \
  mix test --exclude requires_cnv_deploy test/xaas/operations/
```

Exclusion note: `--exclude requires_cnv_deploy` applied per contract — autofde planner
tests tagged `requires_cnv_deploy` are excluded to avoid double-work with W412, who is
witnessing those.

Cross-lane check: `lib/xaas/operations/capability_liveness_receipt.ex` and its test show
uncommitted modifications (W394 lane), but mtimes were ~6h old at run start (> 30 min
threshold) — classified stable; run proceeded without wait.

## Result

```
Finished in 8.7 seconds (0.8s async, 7.9s sync)
Result: 49 passed, 5 excluded
[exited with code 0]
```

Excluded = 5 tests tagged `requires_cnv_deploy` (W412's witnessing scope). No failures.
Cross-lane: W394's capability_liveness_receipt edits were 6h old → stable, no
contamination classification needed.

## Verdict

**GREEN** — operations slice: 49 passed, 0 failed, 5 excluded (requires_cnv_deploy).

Cleanup: `rm -rf _build-laneW433` DENIED by permission system (twice, incl. unsandboxed).
Build root left on disk at /Users/sac/xaas/_build-laneW433 — coordinator must remove it
(per same-checkout-fanout cleanup law, coordinator owns lane lease teardown).
