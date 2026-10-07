# W376 — diataxis tutorial/ + how-to/ staleness sweep (P2-6 residual)

Repo: /Users/sac/xaas @ feat/playwright-surface. Read-only sweep; this file is the only write.
Scope enumerated: `docs/claude/diataxis/tutorial/` does not exist — actual dir is `tutorials/` (2 pages).
Total pages: 6 (2 tutorials + 4 how-to). Each page's file-path, module, route, and command claims
verified against the working tree on 2026-10-06.

## Per-page verdict table

| Page | Verdict | Stale claims |
|---|---|---|
| tutorials/receipted-provider-lifecycle.md | CURRENT | none |
| tutorials/build-an-autonomic-capability-loop.md | CURRENT | none |
| how-to/actuate-provider-lifecycle.md | CURRENT | none |
| how-to/add-a-real-json-api-route-to-an-ash-resource.md | STALE (minor) | (1) "44 of 49 resources (see `lib/xaas_web/api_router.ex`'s moduledoc)" — the moduledoc no longer states these counts (now: "all seven configured XaaS domains … Sensitive Ledger and authentication resources that declare no routes"). (2) Internal inconsistency: "one of those 6 domains" after listing 7 domains. |
| how-to/author-ggen-templates-safely.md | STALE (line refs only) | (1) `lib/xaas_web/router.ex:37` (pipeline :audit_mcp_tool_call) → now router.ex:49-50. (2) `lib/xaas_web/router.ex:113-114` (require/import XaasWeb.McpScope) → now router.ex:173-174. All other claims (mcp_scope tools, A2A skill ids, priv/ggen_igniter/mcp_a2a/* files, commit a0ee306, ~/ggen_igniter format fix) verified CURRENT. |
| how-to/fix-ash-admin-and-use-ggen-for-codegen.md | STALE | (1) `e2e/ash-admin-state-change.spec.js` ×3 (lines ~89, ~142-143, ~218) → renamed this branch to `e2e/ash-admin-state-change.spec.cjs` (also the `npx playwright test e2e/ash-admin-state-change.spec.js` command). (2) "Every one of this repo's 6 domains (Accounts, Billing, Governance, Ledger, Operations, Platform)" — stale: Marketplace is also a core domain with `admin do show?(true) end` (lib/xaas/marketplace.ex:10-12); core count is 7, and `config :xaas, ash_domains` now lists 12+. (3) Cosmetic: current domain files use `show?(true)` syntax, not `show? true`. |

## Verified-current spot checks (evidence)

- `Xaas.Actuation.Reactor` defined at `lib/xaas/actuation.ex:260`; `:actuate_status` at
  `lib/xaas/marketplace/provider.ex:83`; `{:error, {:idempotency_conflict, key}}` at
  `lib/xaas/actuation.ex:638`.
- Router routes `/internal-api/capability_liveness_regressions` and `/ocel_summary` at
  `lib/xaas_web/router.ex:91-92`, before the catch-all forward; commit `e07b9c8` exists.
- `lib/xaas_web/internal_api_router.ex` `domains: [Xaas.Operations]` — matches docs.
- `XaasWeb.McpScope` tools `[:list_books, :books_by_grade_band, :active_curations_for_grade]`
  and A2A skill ids `browse/checkout/hddl-plan` — match docs exactly.
- `e2e/ash-admin-state-change.spec.cjs` exists; `.spec.js` does not.

## Priority checks (W328's class)

No page in tutorial/ or how-to/ references `AshA2A.Protocol.Plug` as the /a2a/v1 mount,
no page requires a /witness mention fix, no retired modules referenced, no pre-26.10
version strings. Zero hits of the W328 stale-mount class in these two families.

## Corrections for coordinator application (verbatim list)

1. how-to/add-a-real-json-api-route-to-an-ash-resource.md — replace "the pattern already applied
   to 44 of 49 resources (see `lib/xaas_web/api_router.ex`'s moduledoc)" with wording that does
   not cite counts from the api_router moduledoc (e.g. "the pattern used across the mechanically
   migrated read-only resources"), and change "one of those 6 domains" → "one of those 7 domains".
2. how-to/author-ggen-templates-safely.md — `lib/xaas_web/router.ex:37` → `lib/xaas_web/router.ex:49-50`;
   `lib/xaas_web/router.ex:113-114` → `lib/xaas_web/router.ex:173-174` — i.e. line refs → 49-50 and 173-174.
3. how-to/fix-ash-admin-and-use-ggen-for-codegen.md — `e2e/ash-admin-state-change.spec.js` →
   `e2e/ash-admin-state-change.spec.cjs` (3 occurrences, plus the `npx playwright test` command);
   "Every one of this repo's 6 domains (Accounts, Billing, Governance, Ledger, Operations,
   Platform)" → "Every one of this repo's then-6 domains … (Marketplace has since been added —
   `lib/xaas/marketplace.ex` carries the same `admin do show?(true) end` block)".

## Verdict totals

CURRENT: 3 / STALE: 3 (1 minor count-drift, 2 line-ref/rename drift). W328-class hits: 0.
