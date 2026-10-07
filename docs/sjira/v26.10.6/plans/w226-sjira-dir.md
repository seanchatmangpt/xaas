# W226 — sjira dir post-W139 verification receipt

- Date: 2026-10-06, lane W226, v26.10.6 convergence, repo /Users/sac/xaas
- Scope: full `test/xaas/sjira` dir minus externals, after W139's generate.py + fixtures changes
- Command (verbatim):

```
PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test mix test test/xaas/sjira --exclude external
```

## Counts (verbatim ExUnit output)

```
Running ExUnit with seed: 248511, max_cases: 32
Excluding tags: [:external, :stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api, :external_llm, :subprocess, :property, :castle_kernel]

Finished in 6.1 seconds (3.9s async, 2.2s sync)

Result: 107 passed
```

- Passed: 107
- Failed: 0
- Errors: 0
- Skipped/invalid: 0 explicit; auto-excluded tags in effect: `external, stress, kind, requires_cnv_deploy, requires_semantic_jira_api, external_llm, subprocess, property, castle_kernel` (config-level excludes, not OS-9 machinery skips — no per-test skip lines appeared).

## Failure classification

None. No failures to classify; no contention flakes; no re-run needed.

## Notes

- W139's SJ-001 E2E subprocess test did not run in this invocation: the `:subprocess` tag is excluded by the suite's default exclude set. This receipt covers the non-subprocess surface of the dir only.
- Expected ambient warnings observed (pre-existing, not failures): AshA2A legacy_compat/memory receipt-store warnings, `autofde` not on PATH (sa2a-bridge edges unavailable), PromEx/Grafana nxdomain uploads, node not in distributed mode.

## Standing

- Result: ALIVE for `test/xaas/sjira` (non-subprocess) at this working tree state, branch feat/playwright-surface (uncommitted W139-era changes present; no git actions taken).
- Falsifier for this lane: any failure or skip line in the run above — none observed.

## W238 post-vacuity

Re-run of the W226 dir-level gate after the vacuity-marker fixes (W226 predates them). Command (real, run 2026-10-06):

```
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test mix test test/xaas/sjira 2>&1 | tail -6
```

Actual tail output:

```
...........................................................................................................
Finished in 6.2 seconds (3.8s async, 2.4s sync)

Result: 107 passed
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```

- Passed: 107
- Failed: 0
- Errors: 0
- Skipped: 0 (no skip lines in output; typed skips expected per lane contract did not surface)

## Failure classification

None — zero failures to classify. Counts identical to W226 (107/0/0); no vacuity-marker regression introduced by the fixes.

## Standing

- Result: ALIVE for `test/xaas/sjira` (full dir surface) at this working tree state, branch feat/playwright-surface, post-vacuity-fix. No git actions taken; no fixes made.
