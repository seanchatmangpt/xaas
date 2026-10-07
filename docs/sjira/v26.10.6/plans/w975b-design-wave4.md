# W975b — design-wave 4 receipt (lane receipt, uncommitted)

- Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, in-flight campaign tree
  (base HEAD `fab56ae1` at lane start; no commit per lane contract). Build root
  `_build-laneW975b` deleted at lane close (lane-lease law).
- Task: up to 2 M-estimate specs from W905's DESIGN backlog
  (`docs/sjira/v26.10.6/plans/w905-design-gap-specs.md`), disjoint from waves 1–3
  (their receipts were absent at lane start; W905 backlog surfaced-state checked
  directly).
- Standing: PARTIAL_ALIVE — 1 M spec landed (SPEC-30); second M spec (SPEC-07)
  aborted after a real disjointness collision with lane W970a (typed below).

## Landed: SPEC-30 (W819/W802-GAP-1) — GraphQL mounted over HTTP, M

- `lib/xaas_web/router.ex`: new `scope "/api/graphql"` → `forward("/", Absinthe.Plug,
  schema: Xaas.GraphqlSchema)`, behind `[:require_internal_api_token, :api]`,
  registered BEFORE the catch-all `forward "/api"` (shadowing rule this router
  already documents for /sparql and /internal-api/fabric).
- `mix.exs`: declared `{:absinthe_plug, "~> 1.5"}` (was transitive-only via
  ash_graphql; now a direct dep since the router references the module directly).
- Court: `test/xaas_web/graphql_http_surface_test.exs` — 5 tests: 401 unauthenticated
  probe (CLAUDE.md API-auth floor), authenticated `sayHello` 200 with real schema
  payload, wired-domain query (`libraryBooks { results { … } }`) over a real
  Postgres `Book` row (real HTTP round trip through the real router — W750 block-(a)
  mirror), route-table shadowing pin (graphql forward index < `/api` forward index),
  Absinthe 200-with-errors envelope pin.
- Mutation kill (real): removing the router scope → **4/5 fail**; restored → 5/5
  pass. Non-vacuous.
- Diataxis doc flip (spec's named court requirement) NOT done in-lane — doc file
  `docs/claude/diataxis/reference/ash-configuration.md` is on the shared dirty-docs
  set with recent multi-lane activity; coordinator should flip
  `UNSUPPORTED(graphql-http-surface)` when integrating, citing this receipt.

## Aborted: SPEC-07 (W729-GAP-3) — billing multitenancy, M

- Implemented, compiled, then reverted byte-identical after discovering lane W970a
  had landed the same spec concurrently on the other four billing resources
  (`approval_pricing_override`, `approval_quota_override`,
  `approval_invoice_reconciliation_forward`, `approval_tier_downgrade`) with a
  different, stricter convention (required tenant `global?(false)` + per-action
  `allow_global`) plus `test/xaas/billing/billing_multitenancy_court_test.exs`.
  Landing both conventions would ship two multitenancy designs through one billing
  tree (N² drift). My court (`multitenancy_deepening_test.exs`) deleted with the
  surface.
- Keep for the coordinator: W970a's court currently FAILS (1 of its tests: "No
  primary action of type :read for resource Xaas.Billing.ApprovalPricingOverride")
  — pre-existing relative to this lane, surface is W970a's, not touched here.
- Deviation note for the SPEC-07 residual: the four org_id-bearing resources I had
  wired (subscription, approval_sla_credit_apply, approval_patch_sla_credit_apply,
  revenue_recognition) remain UN-wired — SPEC-07 is not fully landed tree-wide; the
  register row should not flip on W970a's partial.

## Shared-tree repair (blocker fix, not a W905 spec)

- `lib/xaas/conference/speaker.ex`: `keynote?` was `public?: true`, so ANY schema
  compile including `Xaas.Conference` (wired by lane W973c, SPEC-31) died in
  `Absinthe.Schema.__after_compile__/2` ("Field name keynote? has invalid
  characters"). Set `public?: false` (repair shape verified by W978b's receipt
  and independently by W981b's new `keynote_graphql_surface_court_test.exs`,
  which asserts the same law). Attribute, accept list, and resource behavior
  unchanged; GraphQL/JSON:API projection loses the field (disclosed follow-up:
  GraphQL-visible rename).
- Removed a transient `exclude_fields([:keynote?])` attempt — unsupported in
  ash_graphql 1.12 (compile error), replaced with the `public?: false` repair.
- `test/xaas/graphql_schema_test.exs` now passes for the first time with
  Conference wired (it was red for any fresh compile before the repair).

## Verify ladder (real output, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW975b)

- `mix compile` — exit 0 (pre-existing W970b `purge_expired` atomicity warning
  disclosed, not this lane's surface).
- `mix test test/xaas_web/graphql_http_surface_test.exs` → **5 passed** (×3 runs,
  including after mutation restore).
- `mix test graphql_http + graphql_schema_test + conference_test +
  conference_deepening_test` → **20 passed, ×2 runs**.
- `mix test test/xaas_web/plugs/` → **15 passed**.
- `mix test test/xaas/billing/` → 40/44 — the 4 failures are W970a's in-flight
  multitenancy court, pre-existing to this lane, untouched surface.

## Concurrency ledger

- W973c (wave 8) landed SPEC-31 into `lib/xaas/graphql_schema.ex` mid-lane
  (3 → 19 domains) — my SPEC-30 court still passes against the 19-domain schema
  (libraryBooks query green).
- W978b/W981b keynote repair converged with this lane's fix (same shape).
- W970a landed SPEC-07 first — my duplicate reverted, disclosed above.
- W970b landed SPEC-20 in `route_projects_backups.ex` (untouched by me).
- W897 touching `subscription.ex` (`:sync_from_stripe` validation) — my revert of
  subscription.ex preserves W897's line (verified: only W897's diff remains in the
  file).

## Typed gaps remaining

- Diataxis `ash-configuration.md` doc flip for SPEC-30 — coordinator (shared dirty
  doc, multi-lane).
- `keynote?` GraphQL-visible rename follow-up.
- SPEC-07 residual on the 4 org_id-bearing billing resources — needs one lane under
  W970a's convention (required tenant + allow_global), not a second convention.
- W970a's billing_multitenancy_court red test (their surface).
