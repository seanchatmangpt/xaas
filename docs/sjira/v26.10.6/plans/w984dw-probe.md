# W984dw — CausalAdmission Chicago Depth Court (probe receipt)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD c0626503 (uncommitted test addition only)
- **Lane**: W984dw (shared canonical checkout, no branch switch, no commit, no stash)
- **Target**: `lib/xaas/actuation/validations/causal_admission.ex` — top uncovered from
  W984du fifth re-census (`/tmp/w984du_map.txt`).

## Disjointness check (pre-write)

`git status --short test/xaas/actuation lib/xaas/actuation` showed sibling lane
W650h33c mid-flight on `spg_gate.ex` / `spg_gate_test.exs` /
`spg_integration_test.exs` — disjoint from CausalAdmission. No collision.
Pre-existing coverage `test/xaas/causal_admission_test.exs` (3 tests) covers:
no-causal pass, non-admitted-status refusal, admitted pass-through, bad-strategy
refusal. This lane covers only unexercised branches.

## New court

`test/xaas/actuation/causal_admission_depth_test.exs` — 14 tests, Chicago
(no mocks; real Ash changeset via `Ash.Changeset.for_create(:admit, ...)` on
`Xaas.Operations.ActuationIntent`, real validation module invoked).

Covered branches (all previously unexercised):

1. no `causal` declaration → `:ok`
2. `causal` non-map → "must be a map"
3. empty causal map → "must include boolean required"
4. non-boolean `required` → "must include boolean required"
5. `required: false` → `:ok` (pass-through)
6. status not admitted → refusal
7. missing evidence fields listed (blank-string `verifier` rejected by
   `non_empty_string?`)
8. admitted cert, nil frontier, nil supporting hash → `:ok`
9. supporting hash without frontier bundle → refusal
10. frontier bundle with empty `bundle_sha256` → refusal
11. frontier bundle supplied, certificate unbound → refusal
12. supporting hash mismatch vs bundle hash → refusal
13. matching binding → `:ok`
14. non-map frontier evidence → "must be a map"

## Commands / exits

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dw
  mix test test/xaas/actuation/causal_admission_depth_test.exs`
  → **exit 0, Result: 14 passed** (0.4s async). First run (pre-fix) failed 14/14:
  changeset used nonexistent action `:create`; fixed to real action `:admit`
  (test-only fix, no lib change).
- Mock gate: `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'`
  → **`[]`**.

## Standing

- Court ALIVE for the covered branch surface on this exact subject.
- Errors surface as `{:error, field: :authority, message: ...}` (refusal shape
  asserted per test).

## Notes / falsifiers

- `rm -rf _build-laneW984dw` **DENIED by permission system** — lane build root
  (426 MB) left on disk; coordinator must clean per fanout cleanup law.
- NO commit made, per lane contract.
