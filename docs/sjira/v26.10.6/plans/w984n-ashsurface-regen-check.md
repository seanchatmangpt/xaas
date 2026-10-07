# W984n — ash_surface Regeneration Check (staleness probe, no commit)

Lane: W984n (xaas v26.10.6). Read-only regen check of `priv/ash_surface/`
against the working tree at xaas HEAD `1f2a2b23` (branch
`feat/playwright-surface`), probing drift since regen commit `68a5c9f9`
(418 entrypoints, w978b; revalidated by w981r 371/371). No commits made in
any repo; ~/ash_surface untouched; regen output captured to /tmp only.

## Command used

The generator natively supports a non-destructive target dir (per the mix
task docs in `lib/mix/tasks/xaas.ash_surface.ex`), so no in-place write was
needed:

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  mix xaas.ash_surface --target-dir /tmp/w984n-ashsurface-out
```

Exit: 0. Output (verbatim tail):

```
ash_surface generation complete
  entrypoints:     417
  surface digest:  a4822b0741e9d99d139648b2fcf5af735828608ea8e5bcdef2fe62606744e3c6
  js artifact:     /tmp/w984n-ashsurface-out/xaas_ash_surface_client
.mjs (417 actions, 114 namespaces)
```

Committed projection (`68a5c9f9`): 418 entrypoints, surface digest
`811707ef7fc9ccab54831a2694c8b252494ec6bb2e631dc6a42fdc052b9d9607`.

## Entrypoint delta (fresh regen vs committed priv/ash_surface)

- ADDED: none (`+0`).
- REMOVED: 1 — `Xaas.Ocel.Event#destroy`.
  Attributed to an **uncommitted** in-flight lane edit
  (`git diff -- lib/xaas/ocel/event.ex` removes the `:destroy` default,
  W983e append-only audit finding). Present at HEAD, absent in worktree.
  Not a landed-surface delta.
- **Net entrypoint delta from landed work since `68a5c9f9`: +0.**
  SPEC-31 domain wiring (39e9d77f) and the W982a/u, W983h, W984l graphql
  batches expose *existing* Ash actions over GraphQL/JSON:API; the surface
  contract counts Ash resource actions, so graphql/JSON:API mounting adds
  zero surface-contract entrypoints. The only file added under lib/ since
  the regen is `lib/xaas/graphlaw/limit_gate.ex` (not an Ash resource).

## Content drift (byte-level, not entrypoint-level)

All four artifacts differ from the fresh regen; the drift decomposes into
exactly two causes:

1. **LANDED — SPEC-07 billing multitenancy** (`39c405fc`, restored
   `ddb19522`, both after `68a5c9f9`): `org_id` attribute/accept added to
   approval resources. Fresh regen adds `org_id` zod fields to 4 create
   schemas in `xaas_ash_surface_client.mjs`:
   - `XaasApprovalInvoiceReconciliationApprove_create_schema`
   - `XaasApprovalPricingOverride_create_schema`
   - `XaasApprovalQuotaOverride_create_schema`
   - `XaasApprovalTierDowngrade_create_schema`
   Verified `org_id` present at HEAD in
   `lib/xaas/billing/approval_invoice_reconciliation_approve.ex:93,101`.
2. **UNCOMMITTED (in-flight lanes)** — the `Xaas.Ocel.Event#destroy`
   removal (`lib/xaas/ocel/event.ex`) plus
   the in-flight SPEC-31 per-resource graphql block on the same file.

## Verdict

**STALE (+0 entrypoints)** — the entrypoint set is CURRENT (no new
surfaces would be added; SPEC-31/W982 batches mount existing actions, so
they do not grow the 418-entrypoint contract), but the projection is
byte-level STALE on landed content: SPEC-07 `org_id` multitenancy is
missing from 4 zod create schemas in the committed client. A coordinator
regen after the graphql batches land would change bytes (org_id fields)
without changing the entrypoint count.

## Standing

**PARTIAL_ALIVE** — regen executed for real (exit 0) to a non-destructive
target dir at the pinned asdf toolchain, MIX_ENV=test; artifact diff
computed and decomposed into landed vs in-flight causes; entrypoint set
verified identical (+0) between fresh regen and the committed projection.
Not ALIVE as a regen-landing witness: nothing was written to
`priv/ash_surface/` and nothing committed, per lane instructions — the
land-regen gate (W980g predict → sync → diff-gate pattern) belongs to the
coordinator wave after the graphql batches land.

## Falsifiers (open)

- The coordinator regen lands and `git diff` on `priv/ash_surface/` shows
  more than the predicted +4 org_id zod lines (prediction was wrong).
- A later graphql batch adds a *new Ash action* (not just a mount), which
  would change the entrypoint count — re-run this check before the
  coordinator regen.
- Playwright suite (w981r pattern) fails at the post-regen subject.

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  mix xaas.ash_surface --target-dir /tmp/w984n-ashsurface-out
diff priv/ash_surface/xaas_ash_surface_client.mjs \
     /tmp/w984n-ashsurface-out/xaas_ash_surface_client.mjs
```
