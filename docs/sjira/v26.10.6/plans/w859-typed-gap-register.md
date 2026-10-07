# W859 — Consolidated Typed-Gap Register (v26.10.6)

Lane W859, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD `a0723bf6`.
Method: grep of `docs/sjira/v26.10.6/plans/w*.md` for `UNSUPPORTED(`/`GAP(`/`OPEN_GAP`/typed-gap
disclosures, then each disclosing receipt's tail/status section re-read for the CURRENT status —
rows are never transcribed from the disclosure line alone. Every row cites a disclosing receipt
and a status-bearing receipt. Lane receipt: `w859-register-receipt.md`.

Status vocabulary:
- **OPEN** — no repairing receipt exists; docketed/backlog.
- **REPAIRED** — a later receipt's real run closed it.
- **TYPED-OPEN** — honest permanent disclosure (capability intentionally absent; the test/corpus
  pins the absence as the real surface).

## Register

| Gap id / class | Disclosing receipt | Surface (file:line) | Status | Status receipt |
|---|---|---|###|---|
| Kernel gap: bare emotion-recognition technique atom admits (refusal requires affective domain + workplace/education setting conjunction) | w665-art50-deepening.md | lib/xaas/semantics/eu_ai_act_admission.ex:167-170 | OPEN | w665-art50-deepening.md |
| W674-GAP-1: gymact non-2xx remote → raw tuple fails `:seal`, rollback, no `:failed` receipt recorded | w674-gymact-deepening.md | GymactSurface.do_and_seal/2 (seal_external/2 path) | OPEN | w674-gymact-deepening.md |
| W674-GAP-2: `actuate/4` without `:episode_id`/`:cut` raises raw `WithClauseError` instead of typed refusal | w674-gymact-deepening.md | GymactSurface.do_and_seal/2 | OPEN | w674-gymact-deepening.md (original disclosure) + w900-batch2-repairs.md (update 2026-10-07: typed-refusal fix staged on tree by W674's lane; suite 7/11 — the 4 failures are the tests' unfiltered `Ash.read!(ActuationReceipt) |> hd()` reading oldest durable receipt, shared-DB pollution; row stays OPEN pending one-line test-side hygiene fix) |
| W722 gaps 1-2: approval state guard absent on deepening surface; `X-Org-Id` caller-asserted, not authenticated (pre-existing ResolveOrgActor limitation) | w722-governance-deepening.md | XaasWeb.Plugs.ResolveOrgActor | OPEN | w722-governance-deepening.md |
| UNSUPPORTED(lifecycle-state-machine): `:sync_from_stripe` accepts any in-enum transition (no transition guard) | w729-billing-deepening.md | billing subscription lifecycle | OPEN | w729-billing-deepening.md |
| UNSUPPORTED(db-level-approve-idempotency): SLA-credit `newly_approved?/2` reads in-memory `approved_by` → stale-record repeat `:approve` double-credits | w729-billing-deepening.md | billing SLA-credit approval guard | OPEN | w729-billing-deepening.md |
| UNSUPPORTED(multitenancy): no `multitenancy do` on billing resources | w729-billing-deepening.md | billing resources | OPEN | w729-billing-deepening.md |
| UNSUPPORTED(atomic_update): no atomic_update in billing tree | w729-billing-deepening.md | billing tree | OPEN | w729-billing-deepening.md |
| GAP(graphlaw-capability-class): brief-assumed `:capability_class` enum does not exist | w731-graphlaw-deepening.md | Xaas.Graphlaw.Capability | OPEN | w731-graphlaw-deepening.md |
| GAP(graphlaw-limits-not-enforced): EngineLimit rows are registry-only, no consumer gates on them | w731-graphlaw-deepening.md | Xaas.Graphlaw.EngineLimit | OPEN | w731-graphlaw-deepening.md |
| GAP(graphlaw-registry-path-hardcoded): `Catalog.default_registry_path/0` hardcoded `/Users/sac/...`, host-bound | w731-graphlaw-deepening.md | lib/xaas/graphlaw catalog | OPEN | w731-graphlaw-deepening.md |
| W745 rescue-arm (-32603) contract documented but never exercised by a real raise | w745-execution-fabric-deepening.md | MCP dispatch rescue arm | OPEN | w745-execution-fabric-deepening.md |
| W750-G1: no ALIVE-requires-execution gate (`executed` plain field; ALIVE+unexecuted ingest accepted) | w750-liveness-deepening.md | capability liveness receipt ingest | OPEN | w750-liveness-deepening.md |
| W750-G2: `detect/1` blind to upsert-overwritten regressions (history destroyed by identity upsert); no TTL/staleness | w750-liveness-deepening.md | capability liveness detect/1 | OPEN | w750-liveness-deepening.md |
| XAAS-W763-G1: candidate-cannot-authorize unenforced at `run/4` authority channel | w763-sa2a-boundary-court.md | Xaas.Actuation.Kernel.admit_authority/2 | REPAIRED | w780-claim-authority-guard.md (21 passed, `:w763_measured_gap` → `:w780_closed`, refusal wire shape witnessed) |
| W765 GAP-A: no mint-time TTL input (`expires_at` not accepted by `:issue`) | w765-export-token-deepening.md | Xaas.?.AuditExportToken `:issue` | REPAIRED | w765-export-token-deepening.md (original disclosure) + w900-batch2-repairs.md (repair: `create :issue` accept list extended with `:expires_at`; real-action-surface court 17 passed exit 0, mutation-reverted run 15/17 confirms load-bearing) |
| W765 GAP-B (+reuse-after-use): no `:use`/`:consume`/`:verify` action; single-use not enforced | w765-export-token-deepening.md | AuditExportToken action surface `[:issue, :read, :revoke]` | OPEN | w765-export-token-deepening.md |
| W765 GAP-C: no action refuses reuse-after-expiry (calculation-only) | w765-export-token-deepening.md | AuditExportToken active? calculation | OPEN | w765-export-token-deepening.md |
| W765 GAP-D: no runtime consumer gates on active freeze window (override-gate only) | w765-export-token-deepening.md | FreezeWindow | OPEN | w765-export-token-deepening.md |
| W770 vacuous approvals: `Validations.*RequiresApprover` return `:ok` unconditionally; `Changes.*Approve` identity pass-throughs wired to no action | w770-platform-deepening.md | platform approval validation/change modules | REPAIRED | w770-platform-deepening.md (original disclosure) + w900-batch2-repairs.md (witnessed REPAIRED by W792's landed approver wiring; verify-first run platform_route_deepening 19 passed exit 0) |
| W770 no transition path: RouteProjectsBackups lacks `:update`/`:destroy` (no retention sweep) | w770-platform-deepening.md | RouteProjectsBackups | OPEN | w770-platform-deepening.md |
| W770 RouteProjects dead-write: only `:read`; approval metadata unproducible | w770-platform-deepening.md | RouteProjects | OPEN | w770-platform-deepening.md |
| W784 TOFU: pinning / rotation refusal / defer-to-parent chain absent in repo and ash_a2a dep | w784-tofu-probe.md | a2a agent-card trust surface | OPEN | w784-tofu-probe.md (UNSUPPORTED, deferred to campaign backlog) |
| W793 GAP(RESOLVED_AT_GUARD_ONLY_ON_UPDATE), GAP(NO_REOPEN_GUARD), GAP(NO_RESOLVED_AT_GUARD), GAP(NO_POSTMORTEM_STATUS_GUARD) | w793-incident-lifecycle-deepening.md | incident lifecycle resource | OPEN | w793-incident-lifecycle-deepening.md |
| W793 GAP(NO_CROSS_REFERENCE): incident↔castle link absent at resource layer | w793-incident-lifecycle-deepening.md | incident resource | OPEN | w793-incident-lifecycle-deepening.md |
| W796-G1: no per-student concurrent/aggregate borrow cap | w796-checkout-policy-deepening.md | library checkout policy | OPEN | w796-checkout-policy-deepening.md |
| W796-G2: `:return` lacks already-returned/unborrowed guard; inventory inflation | w796-checkout-policy-deepening.md | library `:return` action | REPAIRED | w809-return-guard.md (12/12, DB-reading before_action guard, mutation-run proven) |
| W796-G3: fulfilled hold mints no real Checkout row; hand-off implicit | w796-checkout-policy-deepening.md | hold fulfillment | OPEN | w796-checkout-policy-deepening.md |
| UNSUPPORTED(reversal-action-absent): no `:refund`/`:reverse`/`:undo` action in ledger; double-reverse guard is sufficiency-accident | w799-reversal-deepening.md | lib/xaas/ledger/ | OPEN | w799-reversal-deepening.md |
| UNSUPPORTED(credit-path-unfundable): `credit_sla/1` no sufficiency exemption; unfunded SLA-credit flow RED (3/5, W785's lane) | w799-reversal-deepening.md | credit_sla/1 | OPEN | w799-reversal-deepening.md |
| W804 operator action: `mix ecto.migrate` still must run on xaas_dev (index recorded on test only) | w804-epoch-dedup.md | priv/repo/migrations/20261007120000_*.exs | OPEN | w804-epoch-dedup.md |
| W802/W819 UNSUPPORTED(graphql-http-surface): AshGraphql schema compiles, never mounted | w819-graphql-doc-fix.md | lib/xaas/graphql_schema.ex; router grep 0 hits | OPEN | w819-graphql-doc-fix.md |
| GAP(graphql-domain-coverage): 3 domains wired (Operations, Library, Marketplace), not all | w819-graphql-doc-fix.md | lib/xaas/graphql_schema.ex | OPEN | w819-graphql-doc-fix.md |
| W824 wire-layer coupling absent: QuiescentStop typed envelope never surfaces on MCP wire (kernel raw envelope returned) | w824-quiescent-fabric-tie.md | fabric halt verb / kernel envelope projection | OPEN | w824-quiescent-fabric-tie.md |
| W849 backlog-1: 4 PROVENANCE-ONLY surfaces lack sha256 pins in registry drift guard | w849-generated-surface-census.md | mcp_scope.ex, xaas.library.manufacture.ex, capital_census/facts.ex, ocel_envelope.ex | OPEN | w849-generated-surface-census.md |
| W849 backlog-2 (P2-2): CI/regen leg proving pins match ontology sources | w849-generated-surface-census.md | registry drift guard test | OPEN | w849-generated-surface-census.md |
| W849 backlog-3: McpScope moduledoc provenance TTL source outside pack-dir convention | w849-generated-surface-census.md | McpScope moduledoc | OPEN | w849-generated-surface-census.md |
| W811 UNSUPPORTED(test-scope): lease deepening is sequential-approximation only; concurrent interleavings courted elsewhere | w811-lease-kernel-deepening.md | lease kernel deepening test scope | TYPED-OPEN | w811-lease-kernel-deepening.md (scope boundary, not a defect) |
| W650c OPEN_GAP-1/2: RobustMargin.admit/4 malformed-input clauses missing | w650c-terminal-census.md | lib/xaas/semantics/robust_margin.ex:107 | REPAIRED | w676-margin-hardening.md (37/37, mutation-killed regression tests, W667 contract atoms witnessed) |
| W650c OPEN_GAP-3: art15 deepening test helper `value * 2.0` overflow at sample-construction | w650c-terminal-census.md | test/eu_ai_act/art15_deepening_test.exs:172,262 | REPAIRED | w650c-terminal-census.md (disclosure) + w865-gap3-fix.md (repair: DatasetAdmission helper rescue landed, 27/27 ×2, mutation-killed). Honesty boundary: the register row's named surface at art15:172,262 is W667-owned and still pinned; repair closes the gap at the DatasetAdmission helper boundary (`sliced_w1/3` typed refusal), not the art15 file itself |
| W650c OPEN_GAP-4: VulnerabilityLifecycle.respond/2 state-machine gap vs W540 15.5.s3 expectation | w650c-terminal-census.md | lib/xaas/semantics/vulnerability_lifecycle.ex:98 | REPAIRED | w659d-lifecycle-fixes.md (26 passed ×2, "both W650b terminal-3 lifecycle findings are green") |
| 49.3 EU-AI-Act corpus OPEN_GAP (deployer EU-database registration) — the wave's sole honest permanent open-gap row | w650c-terminal-census.md (registration W815, scope fix W779) | Xaas.EUAIAct.TitleIVVTest "EUAI-ACT 49.3 — OPEN_GAP" | TYPED-OPEN | w815-gap-registration.md (exactly 1 typed open gap, 49.3 + zero others) |
| W880 counterfactual typedoc contradiction: `@typedoc check` claims bare anonymous 1-arity funs are supported, but `run/2` raises FunctionClauseError in `normalize_name/1` (`Function.info(fun, :name)` returns `{:name, atom}` — a tuple; normalize accepts only atoms/binaries) | w880-cf-doctests.md (incident disclosure) | lib/xaas/semantics/counterfactual.ex:167-194 | REPAIRED | w907-bare-fun-fix.md (mutation-killed) |
| W836 health-check no-timeout: checks wrapped in `try/rescue/catch` only — a hung collaborator hangs the whole health request | w836-health-court.md (typed gap, "a hung check would hang the request") | lib/xaas_web/controllers/health_controller.ex (`@check_timeout_ms` bounded-execution now present) | REPAIRED | w860-health-timeout.md (12/12 incl. hung-check court) |
| W893 GAP(CancelDoesNotReleaseSlot): EnforceSessionCapacity counted all statuses — `:cancelled` rows still consumed capacity slots | w893-enrollment-journey.md | lib/xaas/conference/registration.ex:158 (EnforceSessionCapacity) | OPEN | w893-enrollment-journey.md (w925-slot-release.md IN-FLIGHT — receipt file absent 2026-10-07; NOTE: code-side status filter `@active_statuses [:registered, :attended]` IS landed in EnforceSessionCapacity with moduledoc claiming closure; row stays OPEN until the w925 receipt with its court run exists) |
| dead-branch/contract-drift: `format_actuation`'s `maybe_refusal/2` `[:refused, :failed]` clause is DEAD on the admitted fabric path — kernel refusals normalize to admit-time tool errors and OK envelopes carry only `:succeeded`/`:replayed`, so W844's quiescent `refusal` surfacing was wired to an unreachable branch; W866's courts fence it. Disposition options: delete the dead branch, or leave fenced by W866's courts until the kernel contract changes | w866-refusal-court.md (key finding); registered by w938-dead-branch-register.md | lib/xaas_web/controllers/execution_fabric_controller.ex:752-755 | OPEN | w866-refusal-court.md |

## Totals by status

- **REPAIRED**: 9 (W763-G1 → W780; W796-G2 → W809; W650c OPEN_GAP-1/2 → W676; W650c OPEN_GAP-4 → W659d; W650c OPEN_GAP-3 → W865; W765 GAP-A → W900-batch2; W770 vacuous approvals → W900-batch2/W792)
- **TYPED-OPEN**: 2 (W811 test-scope boundary; 49.3 corpus open-gap row)
- **OPEN**: 35 rows — kernel gap (W665), W674-GAP-1, W674-GAP-2 (fix staged per
  w900-batch2-repairs.md; open pending suite `hd()` hygiene fix), W722 gaps 1-2 (2 rows),
  W729 gaps 1-4 (4 rows), W731 gaps 1-3, W745 rescue-arm, W750-G1/G2,
  W765 GAP-B/C/D (3 rows), W770 gaps (2 rows), W784 TOFU, W793 gaps (5 rows), W796-G1/G3,
  W799 gaps (2 rows), W804 operator action, W802/W819 graphql (2 rows), W824 wire coupling,
  W849 backlog 1-3, W866 dead-branch `maybe_refusal/2` (W938 registration),
  W893 GAP(CancelDoesNotReleaseSlot) (w925 receipt IN-FLIGHT).
- Total rows: **46** (35 OPEN + 9 REPAIRED + 2 TYPED-OPEN).
- Status flips in this update: W765 GAP-A OPEN → REPAIRED, W770 vacuous approvals
  OPEN → REPAIRED (both witnessed by w900-batch2-repairs.md, sweep lane W923
  2026-10-07). W674-GAP-2 left OPEN with disclosure annotation.
- W944 update (2026-10-07): 3 new rows appended from W943's unregistered-repairs
  finding — W880 bare-fun typedoc contradiction → REPAIRED (w907), W836 health
  no-timeout → REPAIRED (w860), W893 CancelDoesNotReleaseSlot → OPEN (w925
  IN-FLIGHT; code-side status filter landed, receipt absent). Totals re-derived
  by grep-verification (see w944-register-new-rows.md).
