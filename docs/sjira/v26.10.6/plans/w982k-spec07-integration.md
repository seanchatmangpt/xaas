# W982k — SPEC-07 (billing multitenancy) integration receipt

2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface`, base `6f235905`,
integration SHAs `39c405fc` (production+migration) and `bf9f5cb9` (tests). No push.

## Commits / paths

Commit 1 `39c405fc`:
`lib/xaas/billing/{approval_pricing_override,approval_quota_override,approval_tier_downgrade,approval_invoice_reconciliation_approve}.ex`
+ `priv/repo/migrations/20261007250000_add_org_id_to_billing_approval_tables.exs`.

Commit 2 `bf9f5cb9`: `test/xaas/billing/billing_multitenancy_court_test.exs`
(tests 1-3, W970a scope) + `test/xaas/web` controller fixture
(`test/xaas_web/controllers/approval_tier_downgrade_controller_test.exs`).
Commit 2's court blob was staged via temp-index (`git hash-object` + cacheinfo)
because the on-disk court file is a contested shared surface with lane W982p;
the on-disk file was not modified by this lane at commit time.

## Gates (real output)

- Fresh-root `MIX_BUILD_ROOT=_build-laneW982k mix compile --force --warnings-as-errors`
  EXIT=0, 942 files ("Generated xaas app"). One tolerated dep-only warning
  (ash_affidavit `@envelope_domain_tag`, pre-existing, outside repo).
- `mix test` (court + multitenant_approval_deepening + reversal_deepening +
  billing files + tier controller): **57 passed, 0 failures** (EXIT=0).
- Court re-witnessed 5/5 passed on the post-integration tree (incl. W982p's
  on-disk second-half extension, which is NOT part of these commits).

## Standing

- SPEC-07 W970a half: ALIVE at `39c405fc`/`bf9f5cb9` (compile + court + suites).
- W975b half: NOT in these commits.
- `w975b-retroactive-mint.md`: REFUSED(stale-evidence) — cites
  `subscription.ex:121-134` and court filename `multitenancy_deepening_test.exs`,
  absent from disk (w982l finding, confirmed by W982k disk reads).
- W982p second half: LANDED-UNCOMMITTED on tree (lib edits 09:18-09:19 + court
  tests 4/5); W982p owns its integration commit and its court extension.

## Lane collisions (disclosed)

1. **W981s/W969e compile-freeze SLA fix**: `lib/xaas/conference/registration.ex`
   in-flight edit (identity `where:` without `pre_check_with`) failed the fresh
   gate (ash 3.34 `RequirePreCheckWith`; measured that the pre-check path
   changeset.ex:3313 `do_validate_identity` ignores `identity.where`). Owner
   unresponsive past 10-min SLA; W982k snapshotted their edit to
   `/tmp/w982k-registration-w981s-inflight.ex.bak` and restored HEAD to unblock.
   W983a is re-landing the repair with a verifier-satisfying shape; owner must
   re-land from their own source, not from this snapshot.
2. **W982p court contention**: the shared court file was interleaved by two
   lanes simultaneously; W982k ended the race by staging its W970a-scope blob
   via temp-index instead of further trimming the shared file. W982p's merged
   5-test version passes 5/5 on the current tree.
3. Disk pressure: 1.9Gi free forced a seeded build root (dep artifacts copied
   from `_build/test`, xaas app compiled fresh) — gate subject (the xaas app)
   was fully fresh.

## Falsifier

Delete any of the four multitenancy blocks in `lib/xaas/billing/` (or the
migration org_id columns) → court test 1/2 fails. Flip `global?(true)` →
test 3 fails. Receipt cites only executed commands and their real exits.
