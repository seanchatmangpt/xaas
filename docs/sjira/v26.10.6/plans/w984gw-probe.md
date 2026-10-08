# W984gw — unclaimed-family probe: actuation validations + neighbors

Lane W984gw, shared canonical checkout `/Users/sac/xaas`, branch `feat/playwright-surface`
(no branch switch, no commit, no stash). Date: 2026-10-07.

## Scope

- `lib/xaas/actuation/validations/causal_admission.ex` (W984dw-courted, verified)
- `lib/xaas/actuation/validations/frontier_evidence.ex`
- `lib/xaas/actuation/validations/reactor_context.ex`
- `lib/xaas/actuation/frontier_evidence.ex`
- `lib/xaas/actuation/refusal.ex`
- Excluded per lane contract: `spg_gate.ex` (landed), `quiescent_stop.ex` (W984ey).

## Method

CamelCase grep of each module name against `test/`, then error-atom/message greps
for branch-level coverage; classification below. Genuinely unexercised
state-bearing branches courted in
`test/xaas/actuation/validations_court_w984gw_test.exs` (27 tests, real
changesets against `Xaas.Operations.ActuationIntent`, real bundle composition,
zero mocks, mutation rationale per test).

## Per-module dispositions

| module | classification | evidence |
|---|---|---|
| `validations/causal_admission.ex` | covered (+2 new branch tests: atom-key fetch paths, whitespace falsifier) | 25 existing tests (`causal_admission_test.exs`, `causal_admission_depth_test.exs` W984dw); atom-key `fetch_atom_key/2` rescue path and trim semantics were unexercised |
| `validations/frontier_evidence.ex` | uncovered → courted (4 tests) | zero prior test refs to the validation module itself; non-map-bundle refusal, malformed-bundle refusal, absent-bundle :ok, atom-key authority path all courted |
| `validations/reactor_context.ex` | indirectly covered (+4 branch tests) | exercised indirectly via pack/marketplace/billing ReactorContext-fence tests; with-chain branches (missing context, nil receipt_id, stale projection hash, matching admission) courted directly at changeset level |
| `actuation/frontier_evidence.ex` | partially uncovered → courted (13 tests) | existing tests covered bundle compose/validate/missing/ceiling/standing only; 15 distinct refusal classes had zero test refs (`frontier_fragments_must_be_list_or_map`, `duplicate_fragment_producer`, `producer_key_mismatch`, `unsupported_frontier_producers`, `unsupported_bundle_schema`, `fragments_required`, `bundle_hash_mismatch`, `frontier_evidence_bundle_must_be_map`, `causal_certificate_must_be_map`, `producer_head_required`, `artifact_hash_required`, `fragment_evidence_required`, `fragment_producer_mismatch`, `fragment_producer_required`) |
| `actuation/refusal.ex` | indirectly covered (+2 branch tests) | `new/find/refusal?` used across sa2a/operations tests; `message/1` rendering and the `find(_other)` catch-all were unexercised |

## Verification (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984gw \
  mix test test/xaas/actuation/validations_court_w984gw_test.exs
→ Result: 27 passed, 0 failures, 0 skipped (0.2s)
Mock gate: scan_mock_usage(["test","lib"]) → [] (exit 0)
```

One iterate during court write: initial run 26/27 (String.to_existing_atom on
`"assumptions_hash"` — atom not existing in lane VM); replaced with a literal
atom-key map. Syntax iterate: `alias ... as X` requires comma form
(`alias ..., as: ...`) — fixed once. Both fixed forward, no resets.

## Disjointness

Touched files: only the new test file and this receipt. No overlap with the
modified files in `git status` (lane-owned new paths).

## Cleanup

Lane build root `_build-laneW984gw` (426 MB) removal attempted post-verification
per cleanup law — outcome noted below.
