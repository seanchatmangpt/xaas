# W328 — P2-6 docs staleness sweep, falsifier re-run (read-only leg)

Subject: /Users/sac/xaas @ feat/playwright-surface, no new commits by this lane.
Method: real `grep -n` / `ls` against `lib/xaas_web/router.ex`, `lib/xaas/**`, `config/config.exs`,
`README.md`, `CHANGELOG.md`, `VERSION` on 2026-10-06. Docs were NOT edited (P2-6 contract).

| # | Check | Verdict | Evidence |
|---|---|---|---|
| 1 | http-api-surface.md route table vs router/resources | CURRENT (sampled 7 rows) | `base("/route_projects")` platform/route_projects.ex:32; `base("/marketplace_providers")` marketplace/provider.ex:54; `base("/incidents")` operations/incident.ex:104; `base("/pentest_findings")` governance/pentest_findings.ex:77; `base("/audit_export_tokens")` governance/audit_export_token.ex:49; `base("/approval_invoice_reconciliation_approve")` billing/approval_invoice_reconciliation_approve.ex:66; `base("/approval_pricing_override")` billing/approval_pricing_override.ex:62. `grep -rln 'base("/' lib/xaas \| wc -l` = 70, matching the doc's 2026-10-06 recount |
| 2 | ash-configuration.md — 3 sampled claims | 2 CURRENT, 1 STALE | CURRENT: `Xaas.Witness` domain files all exist (`lib/xaas/witness.ex`, `catalog.ex`, `certified_receipt.ex`, `verification_key.ex`); `Xaas.Marketplace` extensions line matches `lib/xaas/marketplace.ex:6-8` (AshJsonApi/AshGraphql/AshAdmin/AshTypescript.Rpc); `Xaas.Witness` registered in `config/config.exs:32`. STALE: witness LiveView paragraph (lines 183-186) |
| 3 | README version/snapshot claims | CURRENT | `Version: VERSION` -> VERSION file = `26.10.6`; 19 domains listed = 19 registered in config.exs (Accounts…Witness); `26.9.27` / `26.9.25` hits are historical contract/retirement references, not current-state pins |
| 4 | CHANGELOG v26.10.6 entry | CURRENT | `CHANGELOG.md:7` `## [Unreleased] — v26.10.6 (convergence, branch feat/playwright-surface)` |
| 5a | V1TransportPlug reflected in diataxis docs | STALE (x3 locations) | Real: `lib/xaas_web/router.ex:215` mounts `forward("/v1", XaasWeb.A2A.V1TransportPlug, agent: XaasWeb.A2A.NextReadAshAgent, ...)`. Docs still name `AshA2A.Protocol.Plug`: architecture-overview.md:75, architecture-overview.md:134, http-api-surface.md:611-612. `V1TransportPlug` appears nowhere under docs/claude/diataxis/ |
| 5b | /witness route documented | PARTIAL STALE | Real: `live("/witness", WitnessLive)` router.ex:62; `lib/xaas_web/live/witness_live.ex` exists. STALE: ash-configuration.md:183-186 says the router line is "not yet present in lib/xaas_web/router.ex at HEAD d1db2b03" — it IS present. STALE-by-omission: http-api-surface.md:624-627 browser-surface list and lines 15-22 list four new LiveViews (chicago, chicago/seller, marketplace-pplan, marketplace-catalog) but omit `/witness` |
| 6 | actuation-and-semantics.md central claims | CURRENT | No /a2a/v1 or witness claim in this doc; provider lifecycle contract (`:status` not publicly updatable, `:actuate_status` public? false, ReactorContext validation) matches doc lines 35-44 and lib code sampled |

## Stale list (exact corrections, for coordinator to land)

1. `docs/claude/diataxis/reference/ash-configuration.md:183-186` — change "the
   `live(\"/witness\", ...)` router line it requires is not yet present in
   `lib/xaas_web/router.ex` at HEAD `d1db2b03` ... the LiveView surface is
   pending" to reflect that `live("/witness", WitnessLive)` is present at
   `lib/xaas_web/router.ex:62` and `lib/xaas_web/live/witness_live.ex` exists;
   the surface is mounted, not pending.
2. `docs/claude/diataxis/explanation/architecture-overview.md:75` and `:134` —
   `AshA2A.Protocol.Plug` -> `XaasWeb.A2A.V1TransportPlug` (same agent
   `XaasWeb.A2A.NextReadAshAgent`, same token-gated `/a2a` scope).
3. `docs/claude/diataxis/reference/http-api-surface.md:611-612` — same
   `AshA2A.Protocol.Plug` -> `XaasWeb.A2A.V1TransportPlug` correction.
4. `docs/claude/diataxis/reference/http-api-surface.md:15-22` and `:624-627` —
   add `/witness` (`WitnessLive`) to the browser-surface LiveView lists (five
   new LiveViews on this branch, not four).

Counts: 5 checks CURRENT, 3 STALE (items 1-4 above; check 5a x3 locations +
check 5b x2 locations).
