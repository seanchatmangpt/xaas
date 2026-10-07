# W940b — SPEC-16/17 audit export token use action commit

Lane: W940b, campaign v26.10.6, repo /Users/sac/xaas, branch feat/playwright-surface.

## Commit

- SHA: `fab56ae19051c6bc2b501e4a1d6c91312344e2c3`
- Subject: `feat(governance): SPEC-16/17 audit export token use action (w935)`
- Parent: W940 tip on feat/playwright-surface (base 910a2e22)

## Files (4 changed, 58 insertions, 3 deletions)

- lib/xaas/governance/audit_export_token.ex (+6/-3)
- lib/xaas/governance/validations/audit_export_token_expired_token_refused.ex (new)
- lib/xaas/governance/validations/audit_export_token_not_already_used.ex (new)
- priv/repo/migrations/20261007220000_add_used_at_and_use_count_to_audit_export_tokens.exs (new)

Note: test/xaas/governance/export_token_deepening_test.exs was already tracked and
clean at HEAD (last touched be23d26f) — nothing to stage; included in staging set
as a no-op.

## Verification

- Per-path porcelain after commit: clean (empty output, all 5 paths).
- Test run (MIX_ENV=test, asdf shims pinned toolchain):
  `mix test test/xaas/governance/export_token_deepening_test.exs`
  tail: `Finished in 0.6 seconds ... Result: 21 passed`
  (PromEx/Grafana uploader warnings are environmental nxdomain noise, pre-existing.)

## Standing

ALIVE (observed execution on committed tree). No push performed.
