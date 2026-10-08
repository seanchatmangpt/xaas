# W984di — Sjira family coverage burn-down + DeliveryBatch depth court (receipt)

Lane: W984di · Campaign: xaas v26.10.6 · Date: 2026-10-07 · Subject: `c6a750bba7b01a197c8da3b92c7d9a2163667a0e` (working tree, uncommitted per lane law)

## Task

Coverage burn-down on `lib/xaas/sjira/`. Verify W984cj's "DeliveryBatch alias-covered"
claim; enumerate uncovered modules (CamelCase-aware map method, W984cy3's correction);
pick a genuinely state-bearing uncovered surface; one 5-test depth court; ×2 fresh root;
typed disposition if thin/covered.

## Census (CamelCase-aware, lib/xaas/sjira/ → test surface)

| Module | Test surface | Standing |
|---|---|---|
| ArdCourt | `test/xaas/sjira/ard_court_test.exs` | COVERED |
| Atlassian | `test/xaas/sjira/atlassian_test.exs` | COVERED |
| AtlassianCursor | `test/xaas/sjira/atlassian_test.exs` (used at lines 69–95) | ALIAS_COVERED |
| AtlassianTransport | `test/xaas/sjira/atlassian_transport_test.exs` | COVERED |
| Checkpoint | `test/xaas/sjira/atlassian_transport_test.exs` (aliases `Xaas.Sjira.Checkpoint`, line 5) | ALIAS_COVERED |
| DeliveryBatch | `test/xaas/sjira/atlassian_test.exs` (used at lines 43–64) | ALIAS_COVERED → DEEPENED by this lane |
| EngineerWorkflow (+ `engineer_workflow/codec.ex` → `EngineerWorkflow.Codec`) | `engineer_workflow_test.exs` (Codec at lines 116–122) | COVERED / ALIAS_COVERED |
| GovernanceObligation | `governance_obligation_test.exs` | COVERED |
| GovernanceRoute | `governance_route_test.exs` | COVERED |
| RateLimit | `atlassian_transport_test.exs` (alias line 6) | ALIAS_COVERED |
| Successor | `successor_test.exs` | COVERED |
| Yield | `yield_test.exs` + `yield_grader_honesty_chicago_test.exs` | COVERED |

Result: **no genuinely uncovered state-bearing sjira module remains.** The only named
candidate (DeliveryBatch) is alias-covered on the happy path (plan/topo/missing-dep/cycle,
record accepted+retry, JSON roundtrip, resume `retry_failed: true`). W984cj's claim:
VERIFIED.

## Disposition: ALIAS_COVERED → DEEPENED

The uncovered remainder of DeliveryBatch is its typed-refusal surface. Court:
`test/xaas/sjira/delivery_batch_depth_court_test.exs` — 5 tests:

1. `resume/3` `{:error, {:checkpoint_digest_mismatch, forged, plan_digest}}` exact tuple.
2. `plan/2` batch-size ceiling boundary: 100 ok, 101/0/"50" refused
   `{:error, {:invalid_batch_size, n}}`.
3. `resume/3` `retry_failed: false` drops previously-failed ids (`["C"]`) vs `true`
   (`["B", "C"]`); state-bearing on `cp.failed`.
`checkpoint_from_json/1` typed refusals + valid-shape roundtrip; accepted-after-failure
clears `cp.failed` and `complete?/1` flips only when pending and failed are empty.

(Items 4/5 above are compressed in this section; full mutation rationale lives inline
in the test file.)

## Commands / exits (real output)

```
# Run 1 — fresh root _build-laneW984di (first use, full compile)
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984di \
  mix test test/xaas/sjira/delivery_batch_depth_court_test.exs
Running ExUnit with seed: 254672, max_cases: 32
Result: 5 passed

# Run 2 — fresh root _build-laneW984di2 (full compile, two killed attempts, then complete)
Running ExUnit with seed: 347053, max_cases: 32
Result: 5 passed
# plus seed-0 confirmation on the same second root:
Running ExUnit with seed: 0, max_cases: 32
Result: 5 passed
```

## Standing

- Court standing: **ALIVE** — 5/5 passed on two independent fresh build roots
  (seeds 254672 / 347053 / 0), real module under MIX_ENV=test, no mocks.
- Census standing: **PARTIAL_ALIVE** — full-family census is read-only evidence
  (grep over test/ tree at subject SHA); no falsifier run for the census itself.
- Falsifier: any depth-court test failing on the subject, or a census row above
  contradicted by a live grep at replay time.

## Artifacts

- `test/xaas/sjira/delivery_batch_depth_court_test.exs` (new, 5 tests)
- this receipt

## Cleanup

Lane build-root deletion was refused by the permission system (`rm -rf _build-laneW984di
_build-laneW984di2` denied). Both roots remain on disk for coordinator cleanup per the
lane-lease law. Nothing committed; tree left for coordinator integration.
