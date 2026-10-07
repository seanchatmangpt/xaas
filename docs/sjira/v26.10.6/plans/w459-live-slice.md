# W459 — final-tree LiveView dir slice (test/xaas_web/live/)

Lane: W459, repo /Users/sac/xaas @ feat/playwright-surface, private build root `_build-laneW459`.

## Command

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW459 mix test test/xaas_web/live/
```

(exit code 0; run moved to background during cold-lane compile, completed in-lane)

## Real tail

```
Finished in 2.4 seconds (0.9s async, 1.5s sync)

Result: 27 passed
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

[exited with code 0]
```

## Verdict

**live dir slice green-at-final-tree** — 27 passed, 0 failed, 0 skipped, exit 0.

No failures → no cross-test-interference classification needed. Individual receipts
(w435 chicago 152/0, w434 witness 9/0, w372 autofde 1/0) are consistent with the
whole-dir result; no contradiction observed.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW459` — DENIED by permission system (rm -rf
refused). Build root remains on disk at `/Users/sac/xaas/_build-laneW459`; coordinator
must release this lease at integration per the lane-cleanup law.
