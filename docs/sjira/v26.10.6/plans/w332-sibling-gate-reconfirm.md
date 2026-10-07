# W332 — Sibling Gate Reconfirm (DoD 5 CLI rung freshness)

Lane W332, v26.10.6 convergence campaign. Prior greens were receipt-backed but trees had
moved; this reconfirms at current heads. Date: 2026-10-06.

## Results

| repo | head | command | real tail | verdict |
|---|---|---|---|---|
| ex4pm | `9f7aecda87e5110f668f824bbae760f6c97f88e1` | `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/ex4pm/_build-laneW332 mix test` (exit 0) | `Result: 888 passed (2 doctests, 5 properties, 881 tests), 6 skipped, 60 excluded` (43.6s) | GREEN — matches expected 888/0 |
| ash_r2rml | `0d5320f6c5e9a43bb3e8dcb0f30d301b1ebb64d7` | `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/ash_r2rml/_build-laneW332 mix test` (exit 0) | `998 tests, 0 failures, 9 skipped` (17.2s) | GREEN — matches expected 998/0 |
| ggen-marketplace | `93895f808775e04dce9441fbf4014a3d4d40c942` | `python3 scripts/marketplace.py validate` (exit 0) — no mix project / no `test/` dir; smoke slice per contract | `validated packs=305 manifests=305 ontologies=502 templates=1819 native_gates=1868 verifier_gates=21 profiles={"project":101,"projection":158,"semantic":46} diataxis=20` | GREEN (structural-validation smoke; prior 1956/0 ×2 full-suite standing unchanged) |
| beam4pm | `813eb92477ecee3ec734ea93269a32a700692057` | `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/beam4pm/_build-laneW332 mix compile` (exit 0) | `Generated beam4pm app` (with pre-existing warnings, e.g. `lib/beam4pm_replan_router.ex:666:8: BeamPM.ReplanRouter.succ/1`); full suite NOT run per contract | BUILDABLE — still compiles clean-exit at current head |

No reds. No findings requiring fix.

## Cleanup law

Attempted `rm -rf` of each `_build-laneW332` created. **ex4pm/ash_r2rml/beam4pm deletion was
denied by the session permission system (rm refused, not filesystem-denied).** Operator
cleanup paths:

- `/Users/sac/ex4pm/_build-laneW332`
- `/Users/sac/ash_r2rml/_build-laneW332`
- `/Users/sac/beam4pm/_build-laneW332`
