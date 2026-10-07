# W980i — Depth Batch (accounts / marketplace / generation)

Lane W980i, xaas v26.10.6 campaign. Branch `feat/playwright-surface`, HEAD at
lane start `ed407ef8`. No commit (per dispatch). Written only: 3 new test
files + this receipt.

## Surface selection (read-first, per dispatch)

- **accounts**: `test/xaas/accounts/` read first (org_test 9, org_membership_test 10,
  token_revocation 7): CRUD + tenant-scoping already courted (19 prior courts),
  so the depth slice chosen is the genuinely uncovered remainder — the
  `:destroy` default action and the `role` promote/demote lifecycle + one_of
  constraint (zero prior coverage; verified by reading both existing files).
- **marketplace**: `provider_test.exs` (6 courts) covers `authorize?: false`
  construction, slug identity, actuate-boundary refusal, and the read
  filter. Uncourted: the *authorized* `:create` path through
  `Xaas.Marketplace.Checks.ActorOrgMatches` and the authorized `:update`
  descriptive-metadata path — the pre-approve (`:pending`) lifecycle.
  No provider event-recording module exists in `lib/xaas/marketplace/`
  (verified: `changes/` holds only `apply_provider_status_change.ex`;
  `validations/` holds the two approval checks) — "provider event
  recording" has no referent to court; the pre-approve state path is what
  exists. W733's approve wiring was not re-courted.
- **coupling**: `test/xaas/coupling/` exists with 18 passing courts, so per
  dispatch the fallback fired: **generation**, ProjectionRecord admission
  boundary. `generation_test.exs` (19) + `generation_deepening_test.exs` (7)
  already cover hash-match admit, manual-patch refusal, missing-file
  refusal, patch reversal, graph-mutation sensitivity. The uncourted slice
  is ETS read-back provenance round trip, required-attribute refusals,
  append-only re-admission, and divergence refusal where the recorded hash
  names different real content (not a post-record patch).

## Files + per-file counts (all green x2)

| file | courts | result |
|---|---|---|
| `test/xaas/accounts/org_membership_destroy_depth_test.exs` | 4 | 4/4 x2 |
| `test/xaas/marketplace/provider_preapprove_lifecycle_test.exs` | 6 | 6/6 x2 |
| `test/xaas/generation/projection_record_admission_depth_test.exs` | 5 | 5/5 x2 |

Combined: 15/15 passed, two consecutive runs (`MIX_ENV=test
MIX_BUILD_ROOT=_build-laneW980i`, pinned asdf toolchain 1.20.2-otp-28).
Mock gate: grep of the three files → only "No mocks" prose, zero
`Mock()`/`patch(` usage. Chicago discipline: real Postgres sandbox rows
(accounts/marketplace), real on-disk files + real ETS resource (generation),
typed refusals asserted (`Ash.Error.Forbidden`, `Ash.Error.Invalid`, nested
`Ash.Error.Query.NotFound`).

## Mutation rationale per file

1. accounts: delete `:destroy` from `defaults([:read, :destroy])` in
   `lib/xaas/accounts/org_membership.ex` → both destroy courts fail; the
   surviving-row assertion in the anonymous-denied court distinguishes a
   policy-shaped refusal from an action-shaped one.
2. marketplace: delete the `bypass action(:create) do
   authorize_if(ActorOrgMatches)` bypass from
   `lib/xaas/marketplace/provider.ex` → the authorized-create court fails
   and the no-row-persisted assertions distinguish policy-shaped refusals
   (a direct `authorize?: false` create still succeeds).
3. generation: remove `validate(Xaas.Generation.Validations.NoManualPatch)`
   from `:admit` in `lib/xaas/generation/projection_record.ex` → the
   divergence court fails, proving the validation, not the data layer, is
   the refusing collaborator.

## Standing

- New courts: ALIVE (observed execution on the exact lane subject, 15/15 x2,
  real commands + exits).
- `_build-laneW980i` lane build root: LEFT FOR COORDINATOR — `rm -rf` was
  permission-denied in this lane's session; coordinator should delete it at
  integration per the fanout cleanup law.
- Pre-existing lane-environment observation (not session-introduced): one
  transient dep-compile race on a cold `MIX_BUILD_ROOT` (first compile failed
  in `lib/xaas/billing/subscription.ex` at the uncommitted SPEC-07
  multitenancy block; identical recompile green, subsequent compiles
  stable). The uncommitted working-tree diff to `subscription.ex` (14 lines,
  W729-GAP-3 multitenancy backstop) is pre-existing, not mine.
- Not done (typed): no `Provider` lifecycle event-recording surface exists
  to court (UNSUPPORTED: no-referent); W733 approve wiring left untouched.
