# W743 Receipt — ResolveOrgActor Deepening

- **Lane**: W743, xaas v26.10.6 campaign
- **Subject**: repo `/Users/sac/xaas`, branch `feat/playwright-surface` @ `a0723bf6`
- **Date**: 2026-10-07
- **Standing**: **PARTIAL_ALIVE** — new court file green on the exact subject; no source change (deepening only)

## O / O*

- O: backlog claim that `XaasWeb.Plugs.ResolveOrgActor` (`lib/xaas_web/plugs/resolve_org_actor.ex`)
  is security-load-bearing and thinly courted relative to its ~15-entry
  path allowlist.
- O*: verified by reading the plug source + the router pipeline mount
  (`lib/xaas_web/router.ex`, `pipeline :resolve_org_actor` on the `/api`
  scope, after `RequireInternalApiToken`) and the existing court file
  `test/xaas_web/controllers/resolve_org_actor_test.exs` (cross-org
  isolation only; the allowlist/resolution mechanics themselves were
  uncourted).

## μ / diff

Handwritten test file only, zero lib changes:

- `test/xaas_web/resolve_org_actor_deepening_test.exs` (new, 16 tests)
- Receipt itself.

Generated-vs-handwritten: 100% handwritten (no generator profile for plug
courts; irreducible residue).

## Courts added (all Chicago-style: real plug invocations + real sandbox rows, no mocks)

- **(a) path allowlist**: each of the 4 named non-global-multitenancy
  governance paths (`approval_dr_failover`, `approval_legal_hold_release`,
  `approval_deployment_quarantine`, `approval_backup_retention_change`)
  enforces — real 400 `missing_org_id`, halted, at plug level; a
  non-listed `/api` path passes through completely unaffected, asserted
  BOTH at plug level (structurally unchanged conn: no halt, no status, no
  actor/tenant assigns) and via a real router HTTP probe
  (`GET /api/freeze_window` over the real endpoint — never answers the
  plug's 400 `missing_org_id`).
- **(b) resolution**: real `X-Org-Id` → real `Org` row assigns
  `conn.assigns[:current_actor] == %{org_id: slug}` AND the real Ash
  actor AND tenant (`Ash.PlugHelpers.get_actor/get_tenant`); unknown slug
  → real 404 `org_not_found` with the slug `inspect`ed into `detail`;
  empty-string header → typed 400 `missing_org_id` (no lookup); a
  genuinely multi-valued `x-org-id` header (two `req_headers` entries, as
  an HTTP client sending it twice produces — `put_req_header` replaces,
  noted in-test) → typed 400 `missing_org_id`, actor/tenant provably
  never installed (never first-wins).
- **(c) non-interference**: with a real org actor already resolved,
  `SetInternalApiSystemActor` on a system-actor segment leaves it intact
  (its `is_nil(get_actor)` guard, `Xaas.SystemAuthority` struct provably
  NOT substituted, tenant preserved); the converse baseline (system actor
  installs when no org actor exists) and the no-blur direction (a
  pre-existing system actor on a tenant-scoped path does NOT substitute
  for a missing `X-Org-Id` — real 400) both asserted.
- **(d) `/mcp` no-op**: an `/mcp` path whose second segment coincidentally
  equals an allowlisted name never enforces (no halt, no actor/tenant);
  same with a real `X-Org-Id` present — the plug is a pure passthrough.

## Verification ladder / real run output

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW743 \
  INTERNAL_API_TOKEN=test-token \
  mix test test/xaas_web/resolve_org_actor_deepening_test.exs
```

Final tail (after 2 test-side fixes: `:internal_api` pipeline requires
`application/vnd.api+json` Accept, not `application/json`;
`put_req_header` replaces rather than duplicates, so the multi-valued
case is constructed directly on `req_headers`):

```
................
Finished in 0.7 seconds (0.00s async, 0.7s sync)

Result: 16 passed
```

16/16 passed, 0 failures, 0 skipped. No `mix test` regression of the full
suite was run (lane scope; concurrent lanes active on the shared tree —
a full-suite run would serialize on their in-flight edits).

## Transport failures encountered (real, resolved)

1. First run: 14/16, two test-side failures (wrong Accept format → 406
   from the `:internal_api` pipeline; `put_req_header` replace-vs-dup
   misconception). Fixed in-test; no lib code touched.
2. Mid-run, a CONCURRENT lane's uncommitted `lib/xaas/ocel.ex` edit
   briefly contained a syntax error (`@spec ... ) %{` missing `::`) that
   broke my compile twice. Per lane law I did not touch their file; the
   lane fixed it and the run then went green. Recorded as a same-checkout
   fan-out hazard, not a W743 defect.

## Standing / gaps

- PARTIAL_ALIVE as a court: it witnesses the CURRENT plug behavior on the
  exact subject; it does not widen the plug's trust model (the caller-
  asserted `X-Org-Id` is not authentication — disclosed in the plug's own
  moduledoc, unchanged).
- Uncourted residue (typed, out of lane scope): the other 11 allowlist
  segments (`marketplace_providers`, `approval_provider_status_change`,
  `approval_tier_downgrade`, `approval_sla_credit_apply`,
  `approval_patch_sla_credit_apply`, `incidents`, `route_orgs_custom_domain`,
  `route_projects_backups`, `audit_export_tokens`, `pentest_findings`,
  plus the `orgs` create/PATCH special cases) are smoked only by their
  per-resource controller tests, not by this file; `POST /api/orgs`
  empty-actor special case and `PATCH /api/orgs/:id` are uncourted here.
- **Build-root lease**: `rm -rf _build-laneW743` was permission-denied in
  this session; the directory is left for coordinator deletion per the
  lease law's fallback.
