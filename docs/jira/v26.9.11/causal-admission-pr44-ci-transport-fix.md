# PR #44 causal-admission slice: exact-SHA ex4pm sibling-dependency materialization in CI

## Summary

Branch `codex/causal-admission-closure` (base `8720ab14bffad7a87b486d3c34b97e92780099c3`,
head `38d9933efec49a8006456a7a77f61e89689eb460`), draft PR #44 "feat: add causal
admission proof obligation before DO", 4 commits / 4 files, no merge performed.

This slice adds a pre-DO causal-admission proof-obligation gate and fixes a CI
verification-transport blocker (an unmaterialized sibling path dependency) that
previously prevented the gate's tests from even compiling in CI.

## Status

Candidate / Draft PR Open, CI Pending

Branch and head commit not fetched locally in this session (`git log` /
`git show` against `codex/causal-admission-closure` and
`38d9933efec49a8006456a7a77f61e89689eb460` returned nothing locally) — this
ticket is based on the vetted session record, not a fresh local inspection.

## Scope

- `Xaas.Actuation.Validations.CausalAdmission` (new pre-DO proof-obligation gate)
- `ActuationIntent.create(:admit)` now runs causal admission before an
  executable intent can exist
- `causal_admission_test.exs` — real Ash/Reactor/Postgres Chicago tests (no mocks)
- `ci_cd.yaml` — permanent exact-SHA materialization of the existing `../ex4pm`
  path dependency (ex4pm pinned to `426455b6dfaf3931f85cc05b612ff73759766267`)

## Key Invariant(s)

For an intervention declaring `causal.required = true`, admission requires an
admitted certificate with:

- identification strategy: `rct` / `iv` / `backdoor` / `frontdoor` /
  `observational_assumptions`
- verifier identity
- DAG-proof hash
- assumptions hash
- placebo-result hash
- explicit falsifier

Core invariant: `Selected(a) ∧ Authorized(a)` does not imply `DO(a)` when
causal standing is declared necessary.

## Relationship to Existing Work

Scope explicitly NOT covered by this slice (see the `causal-admission-engine`
ticket): actual causal discovery, d-separation, adjustment-set derivation, RCT
analysis, IV estimation, placebo analysis — this gate only verifies the
STRUCTURE/identity of a supplied certificate, not its scientific validity.

## CI History

- First exact-head CI run failed at compile: `{:ex4pm, path: "../ex4pm"}`
  sibling was not materialized in CI ("the dependency is not available").
  Tests/format/dialyzer correctly did not run. This was a verification-
  transport blocker, not evidence against the causal-admission code.
- Fixed by pinning `ex4pm` to an exact SHA in the `ci_cd.yaml` materialization
  step.
- A second exact-head run (GitHub run `34665224519`) was queued at last
  observation — outcome not yet confirmed, so this slice is CANDIDATE, not
  ALIVE.

## Falsifiers / What Would Defeat This

- GitHub run `34665224519` (or any subsequent exact-head run on this branch)
  fails to compile, format, or pass dialyzer with `ex4pm` pinned to
  `426455b6dfaf3931f85cc05b612ff73759766267` — would show the SHA-pin fix
  itself is insufficient.
- `causal_admission_test.exs` fails against real Ash/Reactor/Postgres in CI —
  would show the gate's Chicago-style tests don't actually pass end to end,
  not just that CI can compile.
- An intervention with `causal.required = true` is observed reaching `DO(a)`
  without an admitted certificate (missing any of: identification strategy,
  verifier identity, DAG-proof hash, assumptions hash, placebo-result hash,
  falsifier) — would show the gate does not actually enforce the invariant it
  claims to.
- The certificate structure is accepted by `CausalAdmission` without
  validating one of the six required fields (e.g. a certificate with a
  falsifier field present but unchecked) — would show the gate verifies
  presence, not the structural admission it claims.
