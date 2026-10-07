# W380 — castle_kernel opt-in class evidence (DoD 1)

Repo: /Users/sac/xaas @ feat/playwright-surface (d1db2b03). Lane build roots: `_build-laneW380`, `_build-laneW380b`.

## Command
```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW380 \
  mix test --include castle_kernel test/xaas/castle_bridge_test.exs test/xaas/fabric/castle_alive_test.exs
```

## Real result (combined run, tail)
```
Result: 2/13 passed
Failed: 11 tests
```
(Note: 13 tests collected vs w374 census of 12 — one extra test in the class at HEAD.)

## Isolation reruns (per contract step 2)
- `test/xaas/castle_bridge_test.exs` alone: `Result: 2/3 passed, Failed: 1`
  - Failure: `** (System.EnvError) could not fetch environment variable "CASTLE_BIN" because it is not set` at `test/xaas/castle_bridge_test.exs:59`.
- `test/xaas/fabric/castle_alive_test.exs` alone: `Result: 0/10 passed, Failed: 10`
  - All 10 identical: `** (File.Error) could not read file "/Users/sac/castle/target/debug/castle": no such file or directory` at `test/xaas/fabric/castle_alive_test.exs:28` (`setup_castle!/0`).

## Classification
Not concurrent-lane Postgres contention — failures reproduce identically in isolation. Root cause is absent kernel machinery:
- `/Users/sac/castle` repo exists but is unbuilt (`target/` absent — no debug binary).
- `CASTLE_BIN` env unset; castle_bridge tests hard-require it (`System.fetch_env!/1`).

This is **typed-blocked (machinery absent)**, not a real regression and not green:
- castle_alive: typed skip reason = `FILE_MISSING: /Users/sac/castle/target/debug/castle` (10 tests).
- castle_bridge: typed skip reason = `ENV_MISSING: CASTLE_BIN` (1 test); 2 tests in the same file pass without the binary.

## Verdict
`castle_kernel` class at HEAD: **typed-blocked — kernel binary not built on this host.** Class is not ALIVE-at-HEAD on this subject; 2/13 green, 11/13 blocked on missing `/Users/sac/castle/target/debug/castle` (+ `CASTLE_BIN`). Remediation path (outside lane write contract): build `/Users/sac/castle` (`cargo build`) and export `CASTLE_BIN`, then rerun.

## Cleanup
`rm -rf _build-laneW380 _build-laneW380b` — **DENIED by permission system** (recorded per contract). Build roots remain on disk.
