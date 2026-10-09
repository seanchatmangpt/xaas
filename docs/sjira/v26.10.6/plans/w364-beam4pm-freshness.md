# W364 — beam4pm freshness gate at current head (WP-F)

Date: 2026-10-06. Subject: `/Users/sac/beam4pm`, branch `main`, HEAD `813eb92477ecee3ec734ea93269a32a700692057`. Read-only lane; this file is the only write. One canonical checkout, no worktrees, no commits.

## Receipt

| field | value |
|---|---|
| subject | beam4pm @ `813eb92477ecee3ec734ea93269a32a700692057` |
| dirty tree | 2,495 files (`git status --porcelain \| wc -l`; r9 observed 2,462 at the same SHA — +33, consistent with ongoing runtime-artifact churn in tracked receipts/engine_ops in the beam4pm repo and new untracked evidence) |
| prior gate | w52/w74 OTP-29 adjudication + 1506/1509 at an older head; trees moved |

## Commands + real output

1. Pin: `git rev-parse HEAD` → `813eb92477ecee3ec734ea93269a32a700692057`; `git status --porcelain | wc -l` → `2495`.
2. Compile (full private root, fresh):
   `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/beam4pm/_build-laneW364 mix compile`
   → tail: `Generated beam4pm app` / `EXIT=0` (warnings only, e.g. `lib/beam4pm_replan_router.ex:666:8: BeamPM.ReplanRouter.succ/1`). Exit 0 — required gate met.
3. Narrow slice = r9 ladder steps 4-5 (C2 + C4 acceptances):
   `MIX_ENV=test MIX_BUILD_ROOT=... mix test test/beam4pm_ash_ex4pm_emission_test.exs test/beam4pm_types_test.exs`
   → tail: `Result: 10 passed` (0 failures, 0 skipped; 2.0s).

## Comparison to r9 adjudication

r9's ladder expected: step 4 ex4pm emission green under OTP-29 (C2 acceptance); step 5 types green with 673 types (C4). Both ran green: 10 passed / 0 failed. No NEW failure vs the r9 classification.

## Verdict

**FRESH** — compile exit 0 under 1.20.4-otp-29 with a fresh full private build root, and the r9-adjudicated ladder step 4-5 slice passes (10/10) at the exact current head. Consistent with the w52/w74 OTP-29 adjudication and 1506/1509; no drift.

## Cleanup

Lane build root `rm -rf /Users/sac/beam4pm/_build-laneW364` was DENIED by the permission system. Path left on disk: `/Users/sac/beam4pm/_build-laneW364` (per-lane build lease; coordinator to remove at integration per the cleanup law).

## Standing

FRESHNESS gate for beam4pm WP-F: **FRESH** (observed execution, exact subject, real tails above). Feeds the _FRONTIER beam4pm row note.
