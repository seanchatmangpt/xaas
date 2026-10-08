# W984iv Probe Receipt — Fortune batch court (v26.10.6)

- **Lane**: W984iv, canonical checkout `/Users/sac/xaas`, branch
  `feat/playwright-surface` (no branch switch, no commit, no stash).
- **Subject**: new file
  `test/xaas/operations/fortune_batch_court_w984iv_test.exs` + this
  receipt. 16 tests, 16 passed, exit 0 (two consecutive green runs after
  one fix).
- **Gate command**:
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984iv mix test test/xaas/operations/fortune_batch_court_w984iv_test.exs`
  — full lane compile from an empty build root, then
  `Result: 16 passed`, exit 0.
- **Mock gate**:
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984iv mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'`
  → `[]` (real output, exit 0).

## Per-module dispositions (read from disk 2026-10-07)

| module | file | disposition |
|---|---|---|
| `Xaas.Operations.Changes.CastleVerbFortune5RequirementsApprove` | `lib/xaas/operations/changes/castle_verb_fortune5_requirements_approve.ex` | identity no-op (`change/3` returns changeset unchanged), UNWIRED — consumer `CastleVerbFortune5Requirements` is read-only (only `:read` action); CamelCase grep: name appears only in its own file |
| `Xaas.Operations.Validations.CastleVerbFortune5RequirementsRequiresApprover` | `lib/xaas/operations/validations/castle_verb_fortune5_requirements_requires_approver.ex` | identity :ok (`validate/3` always :ok), UNWIRED — no `:approve` action exists anywhere on the consumer |
| `Xaas.Operations.Changes.ApprovalCastleVerbScheduleApprove` | `lib/xaas/operations/changes/approval_castle_verb_schedule_approve.ex` | identity no-op, NOT wired — `ApprovalCastleVerbSchedule`'s `:approve` wires only the real `ApprovalCastleVerbScheduleRequiresApprover` validation, not this change |
| `Xaas.Operations.Changes.ApprovalK8sFaultRemediateSuggestApprove` | `lib/xaas/operations/changes/approval_k8s_fault_remediate_suggest_approve.ex` | identity no-op, NOT wired — `ApprovalK8sFaultRemediateSuggest`'s `:approve` wires only the validation |
| `Xaas.Operations.Validations.ApprovalK8sFaultRemediateSuggestRequiresApprover` | `lib/xaas/operations/validations/approval_k8s_fault_remediate_suggest_requires_approver.ex` | REAL maker-checker rule, WIRED on `ApprovalK8sFaultRemediateSuggest` `:approve`; live-action courts cover missing / blank / self-approval refusals + distinct-approver persistence (tests 3a–3d) |
| `Xaas.Platform.Changes.RouteSecretsApprove` | `lib/xaas/platform/changes/route_secrets_approve.ex` | identity action-seam, WIRED on `RouteSecrets` `:approve` and exercised end-to-end through the live action (tests 4a–4c) plus a direct identity pin (test 1) |
| `Xaas.Platform.Validations.RouteSecretsRequiresApprover` | `lib/xaas/platform/validations/route_secrets_requires_approver.ex` | REAL maker-checker rule, WIRED on `RouteSecrets` `:approve`; live-action courts (tests 4a–4c) |

## Court structure (16 tests)

1. Identity court: all 4 `*Approve` changes — `init/1` passthrough +
   pin-assert `change/3` returns the changeset unchanged.
2. Identity court: `CastleVerbFortune5RequirementsRequiresApprover`
   always `:ok` on real changesets (nil and populated approver).
3. k8s live-action courts (3a–3d): missing `approved_by` refused with
   the real message; blank-string approver refused; self-approval
   refused; distinct-approver happy path persists `approved_by` (re-read
   via `Ash.get!`).
4. RouteSecrets live-action courts (4a–4c): missing approver refused;
   self-approval refused; distinct-approver persistence end-to-end
   through the wired `RouteSecretsApprove` seam.
5. Wiring non-vacuity courts (5a–5c): `validate(...)`/`change(...)`
   lines present in both real wiring sites; multiline-safe CamelCase
   grep (W984er lesson) proves the 4 unwired identity shims have no
   wiring site outside their own files (W984fj lesson: an identity
   no-op validation wired onto an approve path is a vacuous gate);
   `CastleVerbFortune5Requirements` action surface stays `[:read]`.
6. Boundary / typed-refusal courts (6a–6c): non-system actor is
   `Ash.Error.Forbidden{}` on k8s create/approve and route_secrets
   create/approve (SystemActor floor, XAAS-2602 predicate); the
   read-only castle resource's read bypass stays open to any actor,
   exercised against a real repo-minted row.
7. Real-validation `init/1` surface pin.

Mutation rationale is inline per test in the court file (identity,
init, wiring, behavior, and policy-floor mutations each named).

## Standing

PARTIAL_ALIVE for the batch: the 3 real validation/change seams are
covered end-to-end through live Ash actions; the 4 identity shims are
pinned as identities with unwired invariants. No commit made (per lane
contract). Adjacent 2-pub stragglers in the census
(`RouteFeatureFlagsRequiresApprover`,
`RouteOrgsCustomDomain*`, `RouteProjects*`,
`RouteProjectsRequiresApprover`) were NOT in this batch's named list
and were left to their lanes.

## Cleanup

Lane build root `_build-laneW984iv` removal attempted after the gate
(see session log for the rm/shutil outcome); deletion is lease cleanup
per the fanout cleanup law, coordinator may re-lease at integration.