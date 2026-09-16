# XAAS-2602: Classify every remaining action-scoped `authorize_if(always())` site; convert the provably-internal/service-boundary mutations to `Xaas.Checks.SystemActor`

- **Status**: Closed — implemented + Chicago-validated (2026-09-15)
- **Severity**: High
- **Standing**: ALIVE for this fix (full suite green; see Closure evidence)
- **Found by**: XAAS-2601's disclosed follow-up scope (the broader-pattern sites outside that ticket's named change set), closed by a full classification sweep this session.
- **Base**: `fix/v26.9.15-system-authority` @ `57783a5`; branch `fix/v26.9.15-system-authority-followup` (worktree `wt-v26915/xaas-followup`).

## Evidence

`grep -rn -B4 "authorize_if(always())" lib/` finds 144 raw matches. After separating doc comments, `action_type(:read)` read bypasses (out of scope by the task's own boundary, left untouched), and the two `AshAuthentication.Checks.AshAuthenticationInteraction`-gated sites in `lib/xaas/accounts/{token,user}.ex` (gated by a real check, not a bare `always()` — the standard AshAuthentication pattern), every remaining **mutation** site was classified by real caller evidence: who invokes the action, through which surface (JSON:API route behind `XaasWeb.Plugs.RequireInternalApiToken`, internal lib/ code, AshOban schedule, or nobody).

Key structural facts the classification rests on:

- `Xaas.GraphqlSchema` exists but is mounted nowhere (no router/endpoint reference; only schema introspection tests) — GraphQL is not a live caller path.
- The `/api` (`XaasWeb.ApiRouter`) and `/internal-api` (`XaasWeb.InternalApiRouter`) AshJsonApi routers serve resource-declared routes behind the real internal Bearer token; requests carry NO actor unless a pipeline plug sets one (`XaasWeb.Plugs.ResolveOrgActor` supplies org actors for its own 14-segment allowlist, disjoint from this change).
- No governance/billing/platform approval resource has ANY direct lib/ caller — their only callers are their own HTTP routes.
- `Xaas.Mix.Tasks.Xaas.CloseCoverageGap` (lib/ non-controller code) is the only production caller of the five autofde planner `request_*` creates; `Xaas.Operations.CapabilityLivenessReceipt :check_regressions`' only caller is its AshOban cron schedule.

## Classification table

Classification classes: **SERVICE-BOUNDARY** (only XaasWeb routes behind `RequireInternalApiToken`; converted — the router pipeline supplies `Xaas.SystemAuthority.new(:internal_api)` via the new `XaasWeb.Plugs.SetInternalApiSystemActor`), **INTERNAL-ONLY** (only lib/ non-controller code; converted with explicit system-actor callers), **READ-CLASS** (out of scope: `action_type(:read)` or read-equivalent stateless computation), **AMBIGUOUS/UNCALLED** (no production caller found; not converted per the fail-closed rule).

| Site (resource:action) | Classification | Evidence | Action taken |
| --- | --- | --- | --- |
| `Platform.RouteSecrets` :create/:destroy | SERVICE-BOUNDARY | JSON:API `POST/DELETE /api/route_secrets`; no lib/ caller | Converted to `SystemActor`; actor from plug |
| `Platform.RouteFeatureFlags` :create/:update | SERVICE-BOUNDARY | JSON:API `POST/PATCH /api/route_feature_flags`; no lib/ caller | Converted; actor from plug |
| `Governance.FreezeWindow` :create/:destroy | SERVICE-BOUNDARY | JSON:API `POST /api/freeze_window` + `DELETE`; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalFreezeOverride` :create/:approve | SERVICE-BOUNDARY | JSON:API post/patch routes; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalCmekKeyBinding` :create/:approve | SERVICE-BOUNDARY | same route shape; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalSsoRoleMappingUpdate` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalComplianceRotationBlock` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.DataDestructionCertificateIssue` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalChangeOfControlNotify` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalVendorOffboardingAttestationIssue` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalOrgDelete` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalInsurancePolicyUpdate` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalSubprocessorRegistryUpdate` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalGeofenceExceptionGrant` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalDeniedPartyOverride` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalExportSubscriptionUpdate` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalLeRequestRespond` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalPersonnelAttestationRecord` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalPentestFindingResolve` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalSourceEscrowSnapshot` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalDsarErasure` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalEnvironmentPromote` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Governance.ApprovalBreakGlassJustificationReview` :create/:approve | SERVICE-BOUNDARY | same; no lib/ caller | Converted; actor from plug |
| `Billing.ApprovalPricingOverride` :approve | SERVICE-BOUNDARY | `PATCH /api/approval_pricing_override` (only route; :create is unrouted and floored); no lib/ caller | Converted; actor from plug |
| `Billing.ApprovalQuotaOverride` :create/:approve | SERVICE-BOUNDARY | post/patch routes; no lib/ caller | Converted; actor from plug |
| `Billing.ApprovalInvoiceReconciliationApprove` :create/:approve | SERVICE-BOUNDARY | post/patch routes; no lib/ caller | Converted; actor from plug |
| `Operations.ApprovalK8sFaultRemediateSuggest` :create/:approve | SERVICE-BOUNDARY | post/patch routes under BOTH `/api` and `/internal-api` (Operations is in both routers); no lib/ caller | Converted; actor from plug (both prefixes) |
| `Operations.ApprovalCastleVerbSchedule` :create/:approve | SERVICE-BOUNDARY | same dual-prefix routes; no lib/ caller | Converted; actor from plug |
| `Operations.AutofdePlannerMatch` :request_match | INTERNAL-ONLY | create action (persists a row + outbound cnv-deploy call); only caller is `Mix.Tasks.Xaas.CloseCoverageGap` + integration tests; no HTTP routes, GraphQL unmounted | Converted; mix task + tests pass `actor: Xaas.SystemAuthority.new(:autofde_coverage_monitor)` |
| `Operations.AutofdePlannerCatalog` :request_catalog | INTERNAL-ONLY | same callers | Converted, same as above |
| `Operations.AutofdePlannerCacheStats` :request_cache_stats | INTERNAL-ONLY | same callers | Converted, same as above |
| `Operations.AutofdePlannerCacheHotset` :request_cache_hotset | INTERNAL-ONLY | same callers | Converted, same as above |
| `Operations.AutofdePlannerCandidate` :request_candidate | INTERNAL-ONLY | same callers | Converted, same as above |
| `Operations.CapabilityLivenessReceipt` :check_regressions | INTERNAL-ONLY | only caller is the `*/15` AshOban schedule (the HTTP regressions controller calls `CapabilityLivenessRegressions.detect/1` directly, not this action) | Converted; schedule supplies `default_actor(%Xaas.SystemAuthority{service: :oban_scheduler})` (same shape as `WebhookDelivery` from XAAS-2601) |
| `Library.School` [:create,:update,:destroy] policy | AMBIGUOUS/UNCALLED | zero callers found anywhere (lib/, tests, seeds — only `get_default` reads via `Library.Config`) | NOT converted (fail-closed rule) |
| `Coupling.CouplingRun` :couple | AMBIGUOUS/UNCALLED | only test callers; Coupling domain is served by NO router (not in ApiRouter/InternalApiRouter domain lists), no lib/ caller | NOT converted (fail-closed rule) |
| `Operations.ProjectMeasure.Measurement` :measure/:measure_json | READ-CLASS | stateless computation resource ("no create/update/destroy actions and no database table" — its own moduledoc); exposed via internal GET/RPC behind the token; mutates nothing | Left as-is (read-equivalent, out of the mutation scope) |
| `Library.Book/Curation/Checkout/RecommendationLog` `always()` sites | READ-CLASS | all four are `policy action_type(:read)` guest-browse reads (documented MCP guest-browse design); their mutation policies already require `actor_present()` | Left as-is (prior survey's "wide-open" concern does not hold for mutations) |
| ~75 `bypass action_type(:read)` sites across all domains | READ-CLASS | read bypasses, out of scope by the task boundary | Left untouched |
| `Accounts.Token`/`Accounts.User` always() sites | READ-CLASS | gated by `AshAuthentication.Checks.AshAuthenticationInteraction` (real check, not a bare always()) | Left untouched |
| `Billing.ApprovalSlaCreditApply`/`ApprovalPatchSlaCreditApply`/`ApprovalTierDowngrade` | (already converted before this pass) | their `:create`/`:approve` use `SlaCreditActorOrgMatches`/`ActorOrgMatches` org checks (passes 15/16); only their read bypasses remain | No change needed |

## Impact

Same defect class XAAS-2601 closed for the Ultracode cluster, but on 34 more resources: 61 mutation entry points (55 service-boundary actions across 28 resources + 5 autofde creates + 1 AshOban scheduled action) authorized literally ANY actor that reached them through the normal authorization path. For the service-boundary cluster the practical gate was only the shared internal Bearer token at the HTTP edge; any non-HTTP path (direct domain calls, future mounts, AshAdmin in dev) reached a policy that said "authorize everyone". After this pass each of those actions requires a genuine `Xaas.SystemAuthority` actor evaluated by the real policy calculus; a forged lookalike map is still refused.

## Fix

1. Every converted site replaces `authorize_if(always())` with `authorize_if({Xaas.Checks.SystemActor, []})` inside the same `bypass action(...)` block (the XAAS-2601 shape), with a comment recording the classification evidence.
2. New `XaasWeb.Plugs.SetInternalApiSystemActor` (path-aware, the disclosed `ResolveOrgActor` design): for the 28 converted resources' route segments under `/api` and `/internal-api`, and only after `RequireInternalApiToken` admitted the caller, it supplies `Xaas.SystemAuthority.new(:internal_api)` via `Ash.PlugHelpers.set_actor/2` — the same mechanism AshJsonApi reads. Security level at the HTTP boundary is UNCHANGED (the internal token is still required, fail-closed); the action-level policy is strictly narrower than before. The plug never overrides an already-resolved actor (org actors from `ResolveOrgActor` always win) and never touches resources outside its segment list, so no other resource's policies are loosened.
3. INTERNAL-ONLY callers updated explicitly: `Mix.Tasks.Xaas.CloseCoverageGap` and the two autofde integration tests pass `actor: Xaas.SystemAuthority.new(:autofde_coverage_monitor)`; the `CapabilityLivenessReceipt` AshOban schedule supplies `default_actor(%Xaas.SystemAuthority{service: :oban_scheduler})`.
4. Chicago proof `test/xaas/system_authority_followup_chicago_test.exs` (16 tests): ordinary actor, nil actor, and fabricated lookalike are refused through the real calculus on every converted cluster (create/approve/destroy shapes per domain); the `:internal_api` system actor is admitted with real persisted rows; the `:oban_scheduler` actor is admitted on `:check_regressions`; the autofde falsifier is proven with the real policy calculus (`Ash.can?/2` — this action's own outbound-HTTP change errors during changeset assembly when cnv-deploy is down, which preempts the Forbidden shape at `Ash.create` time; `Ash.can?` evaluates the exact same authorizer Ash.create invokes, verified live).

## Falsifier (acceptance)

Invoke any converted action as an ordinary non-system actor (`%{id: ..., org_id: ...}`) through real Ash authorization — it must be refused; invoke it as `Xaas.SystemAuthority.new(:internal_api)` (or the resource's internal service actor) — it must be admitted. Proven for both directions in the new suite, plus the pre-existing controller tests, which now exercise every converted HTTP route end-to-end through the new plug (they would all 403 without it).

## Operator did NOT have to write this session

The full 144-site sweep and classification, the 34 resource conversions, the plug, the router wiring, the caller updates, the 16-test Chicago proof, and this ticket — the operator's keystrokes were confined to reviewing this classification.
