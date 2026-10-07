# W984ap — e2e graphql spec removal

Lane W984ap, xaas v26.10.6, checkout `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `5f7f70d9`.

## Action

- Deleted `e2e/graphql-http.spec.cjs` (untracked, `??` in `git status --porcelain e2e/`,
  sole graphql reference in the e2e layer per W984ao1 inventory
  `docs/sjira/v26.10.6/plans/w984ao1-e2e-graphql-check.md`).
- Operator directive: remove graphql code from the e2e surface.

## Deletion receipt

- Pre-delete: file existed; `git status --porcelain e2e/` showed only
  `?? e2e/graphql-http.spec.cjs` (never tracked — no pathspec commit needed or possible).
- `rm /Users/sac/xaas/e2e/graphql-http.spec.cjs` — file gone.

## Grep-zero proof

```
grep -ri graphql /Users/sac/xaas/e2e/ /Users/sac/xaas/playwright.config.cjs
# exit 1 — zero matches across all 27 remaining e2e files + playwright config
```

## Internal-api spec contract check (read, no run)

`e2e/internal-api.spec.cjs` re-read post-deletion: 4 tests intact and unchanged —
(1) no-token health gate → 401 typed unauthorized / 503 fail-closed misconfigured,
(2) invalid-token ocel_summary → same dual typed floor, (3) real health data with
env token (W836 grace contract: aggregate 200/"ok" with `ultracode_tick`
`skipped(:warming_up)`), (4) real OCEL summary with env token (outcome vocabulary
ok/error/unknown). Matches the contract W980l witnessed 4/4. No drift introduced
by this deletion (graphql spec was self-contained, imported nothing).

## Commit standing

No tracked file changed in this lane — nothing committed (untracked-deletion
convention). Untracked receipt: this file. Standing: **ALIVE** (deletion observed
on exact subject; grep-zero falsifier passed; internal-api contract verified by read).

## Falsifier status

- Any remaining `graphql` reference under `e2e/` or in `playwright.config.cjs` → REFUTED.
  Observed: zero matches.
