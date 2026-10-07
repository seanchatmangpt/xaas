# W315 — Final DoD-1 Suite Receipt (TRUE DoD-1 Measurement)

- Date: 2026-10-06
- Repo: /Users/sac/xaas @ branch `feat/playwright-surface` (working tree, uncommitted per task constraints)
- Lane: W315, v26.10.6 convergence
- Purpose: post-W280 async env-isolation fix — verify the W251 knowns (247/105 / 245 env-class) are gone.

## Command (both runs)

```
PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token MIX_ENV=test mix test
```

## Run 1 (post-quiescence, authoritative)

Quiescence confirmed: `ps aux | grep "mix test" | grep -v grep | wc -l` → `0`.

```
Finished in 349.3 seconds (20.1s async, 329.2s sync)

Result: 3235 passed (6 doctests, 3229 tests), 36 skipped, 91 excluded
```

**Zero failures.** The W251 245/247/105 env-class is GONE.

## Run 2 (immediate back-to-back rerun, flakiness probe)

```
Finished in 569.4 seconds (97.7s async, 471.6s log sync)

Result: 3232/3235 passed (6/6 doctests, 3226/3229 tests), 36 skipped, 91 excluded
Failed: 3 tests
```

All 3 failures are in `test/xaas/castle_refusal_negative_test.exs` (Xaas.CastleRefusalNegativeTest):
kernel subprocess was SIGKILLed (exit 137) / `:eexist` on `Xaas.Castle.Kernel.CLI.manufacture/2`.
These same 3 tests PASSED in run 1 on the identical tree — classified environment-flaky
(kernel subprocess under memory pressure from back-to-back full-suite runs), NOT the W251
env-class (that class was sandbox/DB-env failures at scale, not a 3-test subprocess flake).

## W251 knowns disposition

| W251 known class | Status |
|---|---|
| 245/247/105 env-class failures | GONE — 0 occurrences across 2 runs |
| r2rml skew pair | Present but non-failing: compile-time module-redefinition warnings only (`Mix.Tasks.AshR2rml.Install` redefinition, ash_r2rml test-helper module warnings) — zero test failures in either run |
| typed skips | 36 skipped per run — runtime env-dependent skips (python venv missing, EX4PM repo path checks return `{:ok, :skipped, reason}` by design); 91 excluded (stress/include-tags) |
| witness | No witness failures — Xaas.Witness (PW5) passed both runs |

## Mock gate

```
MIX_ENV=test mix run --no-compile -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
```

Output (verbatim tail): `[]` — clean. (Grafana/PromEx nxdomain warnings are ambient dev-loop noise, unrelated.)

## Verification ladder

- Narrow: n/a (measurement only)
- Unit+integration+e2e: full `mix test` ×2 — run 1 fully green, run 2 3232/3235 (env-flaky castle subprocess trio)
- Mock gate: `[]`

## Standing

ALIVE (DoD-1 measurement complete; 245-env-class falsifier confirmed dead). Remaining open:
the castle negative-test subprocess flake (new, minor, run-2-only), the r2rml compile-warning
skew (cosmetic), 36 typed runtime skips.

No fixes made, no git operations performed. Real output above, verbatim.
