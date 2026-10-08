# W984ek — Mutation Non-Vacuity Probe (C05 idiom) over Landed Courts

Lane: W984ek · Date: 2026-10-07 · Branch: feat/playwright-surface (no commits, no stash)
Subjects: 34fc8a53 (vkg query_depth), 5cf56c13 (validations + incident courts),
32b72c4f (causal receipt court), f0321df2 (spg gate + integration courts).

Method: one surgical lib mutation at a time, targeted court run, restore byte-identical
(`cmp` gate before proceeding), post-restore green confirmation. FILE-SWAP baseline only
(`git show HEAD:<file>` snapshot + `cp` back); `git stash` never used. 6 mutants, 6 killed.

Gates: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ek`.
Compile: EXIT=0 ("Generated xaas app", fresh lane root).

## Mutation Matrix

| # | Court (subject commit) | Test file | Mutated lib file | Mutation | Before | During | After |
|---|---|---|---|---|---|---|---|
| M1 | vkg query_depth (34fc8a53) | test/xaas/semantics/vkg/query_depth_test.exs | lib/xaas/semantics/vkg/query.ex | dropped `query.timeout_ms` from `digest/1` tuple (field-blind digest mutant) | EXIT=0, 5 passed | EXIT=2, 4/5 passed (digest-collision assertion fires) | EXIT=0, 5 passed |
| M2 | spg_gate (f0321df2) | test/xaas/actuation/spg_gate_test.exs | lib/xaas/actuation/spg_gate.ex | removed `def admit(_), do: {:error, :spg_identity_required}` non-map clause | EXIT=0, 5 passed | EXIT=2, 4/5 passed (non-map input crashes instead of typed refusal) | EXIT=0, 5 passed |
| M3 | spg integration (f0321df2) | test/xaas/actuation/spg_integration_test.exs | lib/xaas/actuation/spg_gate.ex | `:spg_not_admitted` → `:spg_not_admitted_mutant` (refusal-atom swap) | EXIT=0, 8 passed | EXIT=2, 6/8 passed (exact-atom assertions in tests 3/5 fail) | EXIT=0, 8 passed |
| M4 | causal receipt (32b72c4f) | test/xaas/causal_receipt/process_receipt_depth_test.exs | lib/xaas/causal_receipt/process_receipt.ex | `verify/1` mismatch guard `when recomputed == stored_hash` → `when true` (tamper-blind verify) | EXIT=0, 5 passed | EXIT=2, 4/5 passed ("verify/1 refuses tampering" fails) | EXIT=0, 5 passed |
| M5 | incident lifecycle (5cf56c13) | test/xaas/operations/w650za_incident_lifecycle_guard_court_test.exs | lib/xaas/operations/incident.ex | removed `validate(...IncidentPostmortemFinalRequiresResolved)` line | EXIT=0, 5 passed | EXIT=2, 4/5 passed (postmortem-guard test 5 fails) | EXIT=0, 5 "passed" |
| M6 | ultracode validations (5cf56c13) | test/xaas/ultracode/validations_court_w984ds_test.exs | lib/xaas/ultracode/validations/epoch_transition_allowed.ex | `if current in allowed` → `unless` (inverted allow-list) | EXIT=0, 5 passed | EXIT=2, 3/5 passed (epoch transition guard tests fail) | EXIT=0, 5 passed |

## Standing Verdicts

- M1 vkg query_depth: **NON-VACUOUS** (mutant killed)
- M2 spg_gate admit fail-closed: **NON-VACUOUS**
- M3 spg integration typed-refusal: **NON-VACUOUS**
- M4 causal_receipt verify: **NON-VACUOUS**
- M5 incident postmortem guard: **NON-VACUOUS**
- M6 epoch transition guard: **NON-VACUOUS**

No vacuous court found in the audited sample. All six courts assert exact typed atoms,
exact counts, and collision-sensitive invariants — every mutant was killed by an exact
assertion, not a crash-only side effect (M1/M3/M4 killed by value assertions; M2/M5/M6
by typed-refusal assertions).

## Replay

```bash
cd /Users/sac/xaas
export PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ek
# baseline: all six courts EXIT=0, 5/5/8/5/5/5 passed
# apply one mutation from the matrix, run the paired court, expect EXIT=2
# restore: git show HEAD:<file> > <file> (cmp-verified), court returns EXIT=0
```

Post-restore confirmation: all six courts re-run, EXIT=0, full pass counts restored
(5/5/8/5/5/5). `git status --short lib/` shows only other lanes' pre-existing in-flight
edits (library/book.ex, operations/audit_log_entry.ex, sa2a/changes/execute.ex,
security.ex, semantics/oversight_governance.ex, compat/) — none of this probe's six
mutation subjects appear, each restore was `cmp`-verified byte-identical.

Standing: ALIVE — non-vacuity observed on exact subjects at HEAD (34fc8a53, 5cf56c13,
32b72c4f, f0321df2), this lane.

Cleanup: `rm -rf _build-laneW984ek` was DENIED by the session permission system (twice,
exit never reached); the lane build root `_build-laneW984ek` remains on disk as an open
lane lease for coordinator cleanup at integration.
