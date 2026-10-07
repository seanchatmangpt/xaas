# W432 — Final-tree telemetry slice (v26.10.6 convergence)

Lane: W432 · repo /Users/sac/xaas @ feat/playwright-surface · 2026-10-06

## Command
```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW432 mix test test/xaas/telemetry/
```
(ran >600s foreground — cold full dependency compile into fresh lane build root, 212 libs; completed in background, exit code 0)

## Real tail (verbatim)
```
Result: 33 passed
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```

## Counts
33 passed, 0 failed, 0 skipped, exit 0.

## Classification vs baseline
Zero failures — nothing to classify. Matches w197-era 33/0 telemetry baseline exactly
(includes ocel_ash_emitter refusal-outcome tests per w420's read-only probe).

## Verdict
telemetry slice GREEN at final tree.

## Cleanup
`rm -rf /Users/sac/xaas/_build-laneW432` — DENIED by permission system (both compound
`rm -rf ... && ls` and standalone attempt). Build root REMAINS ON DISK (~1 lane compile,
212 deps). Coordinator cleanup required at integration.
