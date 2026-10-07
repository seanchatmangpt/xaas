# W443 — Receipt dir slice at final tree (incl. W369's converted r_projection)

Lane: W443, repo `/Users/sac/xaas` @ `feat/playwright-surface`, one canonical checkout, no commits.

## Command (final, after env fix)

```
PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW443 mix test test/xaas/receipt/
```

Real tail:

```
Finished in 17.9 seconds (12.1s async, 5.7s sync)

Result: 28 passed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
[os_mon] memory supervisor port (cpu_sup): Erlang has closed
```

Exit code 0.

## Finding (first run, classified)

First run omitted `GGEN_IGNITER_DIR`; result was `26 passed, 2 skipped` — the
`describe "the committed reference episode fmt-1"` block in
`test/xaas/receipt/r_projection_consistency_test.exs:339-344` sets
`@describetag skip:` when `GGEN_IGNITER_DIR` is unset
(`@ggen_dir System.get_env("GGEN_IGNITER_DIR")`, line 43). w329's baseline
(`docs/sjira/v26.10.6/plans/w329-unignored-suites.md`) ran with
`GGEN_IGNITER_DIR=/Users/sac/ggen_igniter`, so the comparison run must too.
Classified: env-gated describe skip, not a regression. Re-run with the env var:
28 passed, 0 skipped — matches the ≥28 expectation (w329's 27 + W369's
unconditional validator-presence assert).

## Verdict

Receipt slice GREEN at final tree: 28 passed / 0 failed / 0 skipped
(dir contains `r_projection_test.exs` + `r_projection_consistency_test.exs`).

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW443` was DENIED twice by the permission
system (sandboxed and unsandboxed attempts). Build root left on disk —
coordinator must delete `_build-laneW443` at integration per the lane-lease law.
