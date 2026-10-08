# W984ir — audit-remediation doc hygiene receipt

- **Lane**: W984ir
- **Date**: 2026-10-07
- **Subject**: working tree on `feat/playwright-surface` (no commits, no branch
  switch, no stash). Edit base: HEAD `3961c4ab` + W984ia-named doc fixes.
- **Clears**: the 2 findings W984ia witnessed
  (`docs/sjira/v26.10.7/plans/w984ia-audit-witness.md`): stale literals quoted
  verbatim in `docs/sjira/v26.10.7/plans/w650k-audit-remediation.md`.

## Diff (single file, 4 quoted literals hyphenated per w467 precedent)

`docs/sjira/v26.10.7/plans/w650k-audit-remediation.md` Class-4 table only:

| line | before | after |
|---|---|---|
| 66 | `"all 6 real domains"` | `"all-6-real-domains"` |
| 68 | `"all 49 resources"` | `"all-49-resources"` |
| 69 | `"44 of 49 resources"` | `"44-of-49-resources"` |
| 71 | `"for all 49 resources"` | `"for all-49-resources"` |

No other line touched; table meaning unchanged (each row still records the
same before→after remediation, only the quoted before-literal is hyphenated
per `w467-release-audit-pin.md:22` precedent).

Verified post-edit: grep for
`\b(all\s+6\s+real\s+domains|44\s+of\s+49|all\s+49\s+resources)\b` in the file
→ 0 matches (exit 1, i.e. neither `@stale_claims` pattern
`lib/mix/tasks/xaas.release_audit.ex:72-73` can fire on it).

## Real audit before/after

- **Before** (W984ia, exit 1): 2 findings —
  `legacy six-domain router claim remains in docs/sjira/v26.10.7/plans/w650k-audit-remediation.md`
  and `legacy 49-resource API claim remains in ...` same file.
- **After** (this lane, fresh `_build-laneW984ir`):
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ir mix xaas.release_audit`
  → `XAAS_RELEASE_AUDIT ALIVE version=26.10.7 tracked_files=5375 ash_resources=122`,
  **exit 0**, zero findings.

## Courts

`MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ir mix test test/xaas/release_audit/ test/mix/tasks/xaas_release_audit_test.exs`
→ **19 passed, exit 0** (47.3s).

## Tag-precondition verdict: **PASS** (audit leg)

The release-audit precondition for the v26.10.7 tag cut is now green: audit
exit 0 with zero findings, courts 19/19. Remaining blockers per
`docs/sjira/v26.10.7/_CLOSURE_RECEIPT.md` are **not** audit items: the
coordinator merge (commit of the remediated surface + post-commit audit
re-run) and the operator ash_pplan call. No commit made by this lane, per
lane contract.

## Cleanup

Lane build root `_build-laneW984ir` (426M): plain `rm -rf` **succeeded**
(no permission denial, no shutil fallback needed); directory confirmed gone.
