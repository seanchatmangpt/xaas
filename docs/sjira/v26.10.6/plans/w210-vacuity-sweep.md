# W210 — Vacuity sweep over failure-evidence tests (W195 class)

Lane: integration W210, v26.10.6 convergence. Repo: /Users/sac/xaas (canonical checkout, no worktree).

W195 found a vacuously-passing test (`stop == false` / `ran == 1`, satisfied by an
UNKNOWN-exit court). This lane swept the same class across the three named files:
assertions of NEGATIVE outcomes that an ERRORING court subprocess (exit 75 / crash)
would also satisfy — i.e. the assertion cannot distinguish "lawfully no violation"
from "machinery never ran".

## Sites found and fixed (2)

### 1. test/mix/tasks/xaas_stop_court_test.exs — "the real goal.ttl: 13 gates G0..G12, stop.rq in sync, FRI-T5 tuple-complete, STOP=false"

- Vacuity: `assert report.stop == false` + `assert Enum.count(report.gates, & &1.ran) == 1`
  both hold even when the single ran gate (G0) exits UNKNOWN(75) machinery-absent —
  exactly the W195 shape. The compile_prose named skip covers absence of the task, but
  not an in-run court failure.
- Pattern: POSITIVE proof-of-run marker. Added
  `assert [%{id: "G0", standing: "ALIVE"}] = Enum.filter(report.gates, & &1.ran)`
  so the ran gate must carry the court's explicit ALIVE standing, not merely "ran".
- Verified: `MIX_ENV=test mix test test/mix/tasks/xaas_stop_court_test.exs`
  → 18 passed, 1 skipped (the rdflib witness skip).

### 2. test/sjira/v26_9_23_goal_test.exs — "real stop.rq: a WorkOrder under a gate ... keeps STOP open until its bound receipt"

- Vacuity: the UNKNOWN-standing step asserted only `assert {1, _} = fixture_court(repo)`.
  Exit 1 alone cannot distinguish a lawfully-linked UNKNOWN order receipt (the intent:
  UNKNOWN is not terminal, so STOP stays open) from the machinery never linking the
  receipt at all.
- Pattern: typed printed line. Changed to capture output and assert
  `out =~ "order WO-A standing=UNKNOWN receipt=ADMITTED digest=#{digest}"` —
  proof the receipt was found, validator-ADMITTED, linked, and its UNKNOWN standing
  (not absence) is what keeps STOP open.
- Verified: `MIX_ENV=test mix test test/sjira/v26_9_23_goal_test.exs`
  → 33 passed, 4 skipped (compile_prose machinery-absent skips + rdflib).

## Sites examined and judged already-sound

test/xaas/sjira/ard_court_test.exs (whole file, 51 passed):
- Every negative-witness test asserts a typed REFUSED verdict plus a specific check id
  and detail pattern (`assert_refused/3`), i.e. proof-of-run is built in; there is no
  bare negative assertion. The "no machine manifest" test additionally asserts every
  dependent check fails closed. No W195-class sites.

test/mix/tasks/xaas_stop_court_test.exs (other tests):
- Exit-code contract tests assert per-gate typed standings/outcomes
  (`G1 ALIVE 0`, `G2 UNKNOWN 1`, timeout 124, ADMITTED/ADMITTED-UNLINKED/MISSING
  lines, independent validator runs) — positive markers present everywhere a negative
  (`STOP=false`, exit 1) is asserted. Sound.

test/sjira/v26_9_23_goal_test.exs (other tests):
- "the registry resolves GC-26.9.23 ... --only GC23-12" asserts `report.stop == false`,
  but the same test pins the GC23-12 receipt's exact standing
  (ALIVE, or BLOCKED:operator_acceptance with broken_term and exit 77) and re-validates
  it — the court cannot error without failing those positive assertions. Sound.
- Court exit-code contract tests (75/3/typed-77) assert the UNKNOWN/BLOCKED typing
  itself — they test the error path deliberately, with typed receipts. Sound.
- Registry/duplicate/unborn/corrupt/SHA-256 tests assert typed
  MISSING/REFUSED/why-strings and re-validate the STOP receipt. Sound.
- `refute out =~ "ALIVE: ..."` lines (GC23-0/GC23-3 mutation tests) are paired with
  positive `REFUSED(output_drift)` / `REFUSED(goal_inadmissible)` assertions. Sound.

## Commands and exits

```
PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test \
  mix test test/mix/tasks/xaas_stop_court_test.exs   # 18 passed, 1 skipped
PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test \
  mix test test/sjira/v26_9_23_goal_test.exs         # 33 passed, 4 skipped
PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test \
  mix test test/xaas/sjira/ard_court_test.exs        # 51 passed
```

## Standing

PARTIAL_ALIVE on the sweep itself (2 sites fixed with real passing runs; the skips are
the pre-existing named machinery-absent skips, not new). No lib edits, no git actions.

## W286 combined

Combined post-fix confirmation (W257 witness isolation + W210 vacuity markers together).

Command and exit:

```
PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test \
  mix test test/xaas_web/live/witness_live_test.exs test/mix/tasks/xaas_stop_court_test.exs \
  test/sjira/v26_9_23_goal_test.exs
# Finished in 81.4 seconds — Result: 54 passed, 5 skipped
```

Isolated witness re-run for the 3/3 target:

```
PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test \
  mix test test/xaas_web/live/witness_live_test.exs   # Result: 3 passed
```

All green: witness 3/3, stop_court typed skip, goal typed skips. No fixes, no git actions.
