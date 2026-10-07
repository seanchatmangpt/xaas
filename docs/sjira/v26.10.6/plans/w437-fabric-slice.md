# W437 fabric slice — final-tree verification receipt

Date: 2026-10-06 · Repo /Users/sac/xaas @ feat/playwright-surface (canonical checkout, no writes to tree)

## Command

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW437 mix test test/xaas/fabric/ --exclude castle_kernel
```

Ran in background ~17 min (full cold compile of deps + app in fresh lane build root, 437 MB).

## Real tail (verbatim)

```
Finished in 0.1 seconds (0.00s async, 0.1s sync)

Result: 0 tests, 10 excluded
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
[os_mon] memory supervisor port (memsup): Erlang has closed
[exited with code 0]
```

## Findings

- `test/xaas/fabric/` contains exactly one file: `castle_alive_test.exs`, carrying
  campaign edits per w354. All 10 tests inherit `@moduletag :castle_kernel` (line 17),
  the typed-block per w380.
- `--exclude castle_kernel` therefore excludes all 10; the non-kernel fabric test set
  is empty. Exit 0 is vacuous-pass: green-by-exclusion, not green-by-execution.

## Verdict

**Fabric slice (non-kernel): green-at-final-tree, vacuously** — 0 executed, 10 excluded
(kernel-tagged), 0 failures, exit 0. No non-kernel fabric test exists at the final tree,
so there is nothing to contradict the slice; conversely the slice carries no executed
evidence. The 10 kernel-tagged tests remain typed-blocked per w380.

No failures to isolate; no env-vs-real classification needed.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW437` — **DENIED** (Bash permission refusal, two
attempts 2026-10-06, plain and compound). Directory remains on disk at 437 MB;
coordinator must delete it (lane-build-root lease per cleanup law).
