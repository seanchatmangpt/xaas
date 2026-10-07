# W372 — WP-H verification legs freshness (dev.exs re-points landed per §1 row 20; re-witness)

Subject: /Users/sac/xaas @ feat/playwright-surface, lane W372, 2026-10-06.
Writes: this file + `_build-laneW372` (private build root) only. Read-only on ~/autofde-lab.

## Leg 1 — program registry resolution (config/dev.exs ~:157-301)

| program | path | on disk |
|---|---|---|
| aps | ~/xaas/worktrees/repos/aps | ENOENT |
| nounverb | ~/xaas/worktrees/repos/nounverb | ENOENT out of scope |
| eds | ~/xaas/worktrees/repos/eds | ENOENT out of scope |
| spr | ~/xaas/worktrees/repos/spr | ENOENT out of scope |
| xaas | ~/xaas/worktrees/repos/xaas | ENOENT out of scope |
| **autofde-lab** | ~/autofde-lab | OK (exists, real dir) |
| **gymact** | ~/gymact | OK (exists, real dir) |
| ggen-igniter | ~/xaas/worktrees/repos/ggen-igniter | ENOENT out of scope |
| ggen-ecosystem | ~/xaas/worktrees/repos/ggen-ecosystem | ENOENT out of scope |
| gym-ecosystem | ~/xaas/worktrees/repos/gym-ecosystem (config/dev.exs:224) | ENOENT out of scope |
| ash_a2a … ash_ex4pm (13 rows) | ~/xaas/worktrees/repos/ash_* | ENOENT out of scope |

Typo guard note: `gym-ecosystem` row verified against the literal config string at
config/dev.exs:224 (`~/xaas/worktrees/repos/gym-ecosystem`) — ENOENT.

Verdict: the two scoped rows (autofde-lab, gymact) now resolve to real directories.
Remaining ENOENT rows (18) are out of the scoped fix (autofde-lab + gymact only) —
typed as `ENOENT(SCOPE_EXCLUDED)`: aps, nounverb, eds, spr, xaas, ggen-igniter,
ggen-ecosystem, gym-ecosystem, ash_a2a, ash_graphlaw, ash_pplan, ash_r2rml,
ash_surface, ash_n8n, ash_planning_center, ash_expo, ash_dspy, ash_ex4pm.

## Leg 2 — status_live test (real output, exit 0)

Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW372 mix test test/xaas_web/live/autofde_lab/status_live_test.exs`

Real tail:
```
Finished in 2.6 seconds (0.00s async, 2.6s sync)
Result: 1 test, 1 passed
```
Fresh build root compiled clean under pinned asdf toolchain. Exit code 0.

Verdict: GREEN.

## Leg 3 — status_parser test (real output, exit 0)

Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW372 mix test test/xaas/autofde/status_parser_test.exs`

Real tail:
```
Result: 10 tests, 10 passed
```

Real-file test source confirmed on disk (test/xaas/autofde/status_parser_test.exs:152-160):
`assert 47 in passes`, `assert 26 in passes`, `assert 48 in passes` against the real
~/autofde-lab/docs/STATUS.md post-v26.10.6 regex fix (48 entries; pass 26 via
composite-label support; pass 48 via partial date-range support).

Verdict: GREEN, including the real-file 47/26/48 assertions.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW372` — DENIED by the permission system
(2 attempts; an oclnr delete dry-run also failed at subprocess level).
Build root `/Users/sac/xaas/_build-laneW372` REMAINS ON DISK;
coordinator must delete it at integration per the cleanup law.

## Receipt

- Legs: 3/3 executed, 0 red.
- Leg 1: autofde-lab + gymact paths ALIVE; 18 rows typed `ENOENT(SCOPE_EXCLUDED)`.
- Leg 2: status_live 1 passed (exit 0).
- Leg 3: status_parser 10 passed (exit 0), real-file 47/26/48 asserts present and passing.
- Standing: ALIVE for the scoped re-witness; cleanup BLOCKED(permission).
