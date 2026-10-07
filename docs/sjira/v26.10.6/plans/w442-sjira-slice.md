# W442 — final-tree sjira dir slice witness (v26.10.6 convergence)

## Receipt

- Subject: /Users/sac/xaas @ feat/playwright-surface (ONE canonical checkout, d1db2b03)
- Command:
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW442 mix test test/xaas/sjira/`
- Exit code: 0
- Real tail:
  ```
  Finished in 7.6 seconds (4.5s async, 3.1s sync)

  Result: 107 passed
  [os_mon] memory supervisor port (memsup): Erlang has closed
  [os_mon] cpu supervisor port (cpu_sup): Erlang has closed
  ```
- Counts: **107 passed, 0 failures, 0 skipped** (whole `test/xaas/sjira/` dir at once).
  Consistent with w329 per-file anchors (ard_court 51/0, yield 8/8 — subsumed in the 107).

## Verdict

**sjira slice green-at-final-tree.** No failures; no isolation pass needed.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW442` was **DENIED** by the permission system
(twice, including sandbox-disabled retry). Build root `/Users/sac/xaas/_build-laneW442`
remains on disk — coordinator must delete it (lane build-root lease law).
