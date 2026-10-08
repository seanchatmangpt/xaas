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
- **OUT-OF-SCOPE(removed-by-operator)** — the tracked surface itself was removed by operator
  directive (2026-10-07 graphql removal, lanes W984ao/W984aq); demand is moot, not repaired.

## Register

| Gap id / class | Disclosing receipt | Surface (file:line) | Status | Status receipt |
|---|---|---|###|---|
| Kernel gap: bare emotion-recognition technique atom admits (refusal requires affective domain + workplace/education setting conjunction) | w665-art50-deepening.md | lib/xaas/semantics/eu_ai_act_admission.ex:167-170 | REPAIRED | w665-art50-deepening.md (disclosure) + w897-cheap-repairs.md row 1 (bare `:emotion_recognition` atom now triggers `REFUSED_EUAIA_EMOTION_RECOGNITION`; art50_deepening 7/7, mutation = trigger deleted → 6/7 RED; confirmed on tree at eu_ai_act_admission.ex:184) — flip W968b |
| W674-GAP-1: gymact non-2xx remote → raw tuple fails `:seal`, rollback, no `:failed` receipt recorded | w674-gymact-deepening.md | GymactSurface.do_and_seal/2 (seal_external/2 path) | REPAIRED | w674-gymact-deepening.md (disclosure) + w902-batch3-repairs.md (verify-first: staged `lib/xaas/operations/gymact_surface.ex` seals GAP-1 as `:failed` with json-safe error maps) + w928-gymact-hygiene.md (hygiene court landed 2026-10-07: 11/11 ×2 consecutive runs exit 0 over the same suite) + w945b-batch4-repairs.md (row-selection audit re-witness: "found already closed verify-first"). Citation note (W960 sweep 7): dispatch named "w897 row 1" — that row is W665, not W674-GAP-1; flip proceeds on the w902+w928+w945b receipts. |
| W674-GAP-2: `actuate/4` without `:episode_id`/`:cut` raises raw `WithClauseError` instead of typed refusal | w674-gymact-deepening.md | GymactSurface.do_and_seal/2 | REPAIRED | w674-gymact-deepening.md (original disclosure) + w900-batch2-repairs.md (staging: typed `Refusal.new(:episode_id_required, ...)` / `Refusal.new(:cut_required, ...)` seals in GymactSurface, confirmed on tree) + w928-gymact-hygiene.md (hygiene court 2026-10-07: all 8 unfiltered `Ash.read!(ActuationReceipt) |> hd()` reads in the test replaced with per-test idempotency-key/intent-id-filtered helper reads, no production code touched; 11/11 passed ×2 consecutive runs, exit 0 — typed refusals + durable `:refused` seals now witnessed by a non-pollutable court) |
| W722 gaps 1-2: approval state guard absent on deepening surface; `X-Org-Id` caller-asserted, not authenticated (pre-existing ResolveOrgActor limitation) | w722-governance-deepening.md | XaasWeb.Plugs.ResolveOrgActor | REPAIRED | w722-governance-deepening.md (gap 1: `ApprovalNotAlreadyApproved` landed by W740, wired on all 4 Approval* `:approve` actions; witnessed by w945c-batch5-repairs.md — 10/10 ×2, mutation-killed by unwiring on ApprovalDrFailover, restored byte-identical. Gap 2 (`X-Org-Id` caller-asserted) remains an honest open limitation of ResolveOrgActor, now tracked as its own row) |
| W722 gap 2: `X-Org-Id` caller-asserted, not authenticated (pre-existing ResolveOrgActor limitation) | w722-governance-deepening.md | XaasWeb.Plugs.ResolveOrgActor | REPAIRED | SPEC-04 repair landed pre-existing by commit 5a853130 (receipts w951b/w969b/w975/w970b); court re-witnessed GREEN 14/14 at HEAD by w982t-w722-gap2.md (fresh lane build `_build-laneW982t`, pinned toolchain); flip W982t (applied by W983d) |
| UNSUPPORTED(lifecycle-state-machine): `:sync_from_stripe` accepts any in-enum transition (no transition guard) | w729-billing-deepening.md | billing subscription lifecycle | REPAIRED | w729-billing-deepening.md (disclosure) + w897-cheap-repairs.md row 5 (`SubscriptionStripeTransitionAllowed` allow-list validation wired via `validate(...)` on `:sync_from_stripe`; 13/13, mutation = validate line deleted → 12/13 RED; siblings 18/18; confirmed on tree at subscription.ex:219) — flip W968b |
| UNSUPPORTED(db-level-approve-idempotency): SLA-credit `newly_approved?/2` reads in-memory `approved_by` → stale-record repeat `:approve` double-credits | w729-billing-deepening.md | billing SLA-credit approval guard | REPAIRED | w729-billing-deepening.md (disclosure) + w897-cheap-repairs.md row-selection drift note (W746's `change(filter(expr(is_nil(approved_by))))` guard already on HEAD; repeat `:approve` through a stale record matches zero rows in the UPDATE WHERE clause and refuses typed; confirmed on tree at approval_sla_credit_apply.ex:133) — flip W968b |
| UNSUPPORTED(multitenancy): no `multitenancy do` on billing resources | w729-billing-deepening.md | billing resources | REPAIRED | All 8 billing resources wired: W970a's 4 (`ApprovalPricingOverride`, `ApprovalQuotaOverride`, `ApprovalTierDowngrade`, `ApprovalInvoiceReconciliationApprove`) at `39c405fc` + court/fixture at `bf9f5cb9` (W982k); W975b's second half (`subscription`, `approval_sla_credit_apply`, `approval_patch_sla_credit_apply`, `revenue_recognition` + court tests 4/5) at `ddb19522` (w982b integration, restoring content swept by `691e0a93`); migration `20261007250000_add_org_id_to_billing_approval_tables.exs` in `39c405fc` (re-landed `1f2a2b23`). Convention: `global?(true)` throughout (skew RESOLVED, verified by grep, w983o). Gates re-witnessed at HEAD by W983o: fresh-root `mix compile --force --warnings-as-errors` EXIT=0; billing dir 40 passed; court 5/5; `multitenancy_deepening_test.exs` 9 passed. `w975b-retroactive-mint.md` remains REFUSED(stale-evidence) superseded by landed content. W984aw graphql-era citation sweep: the w975b citation here is its BILLING half (multitenancy commits `ddb19522`/`39c405fc`), graphql-independent — the SPEC-30 graphql half of w975b is superseded by the operator removal (see W802/W819 row); multitenancy evidence unaffected. |
| UNSUPPORTED(atomic_update): no atomic_update in billing tree | w729-billing-deepening.md | billing tree | REPAIRED | w729-billing-deepening.md (disclosure) + SPEC-08 executed per `w984cc-spec08-execute.md` (3 true conversions, sites 3/6/8: ApprovalPricingOverride / ApprovalInvoiceReconciliationApprove / ApprovalQuotaOverride — `require_atomic?(false)` dropped, `atomic/3` added; 5 remaining `require_atomic?` sites classified non-atomicizable, typed `## Atomicity disclosure` sections added; money-mover falsifier fired → disclosure-only branch) + `w984fr-atomic-site1.md` (ALREADY-LANDED re-witness: compile exit 0, billing dir 74 passed, eu_ai_act census 1388 passed) — court `test/xaas/billing/atomic_retrofit_court_test.exs` re-run GREEN by W984kh (2026-10-08, fresh root `_build-laneW984kh`, 3 passed, exit 0). Supersedes the W984ff "still OPEN" and BLOCKED(billing-tree-hot) citations — the 5 disclosure-only sites are by design, not blocked. Flip W984kh. |
| GAP(graphlaw-capability-class): brief-assumed `:capability_class` enum does not exist | w731-graphlaw-deepening.md | Xaas.Graphlaw.Capability | REPAIRED | w731-graphlaw-deepening.md (disclosure) + w912-s-specs-impl.md SPEC-09 (real `:capability_class :atom` attribute, one_of [:observe,:select,:construct,:do], accept list extended, migration `20261007210000_add_capability_class_to_graphlaw_capabilities.exs` + backfill; out-of-enum → typed Ash.Error.Invalid court; confirmed on tree at capability.ex:28,45; committed per w940-xaas-commits.md) — flip W971 |
| GAP(graphlaw-limits-not-enforced): EngineLimit rows are registry-only, no consumer gates on them | w731-graphlaw-deepening.md | Xaas.Graphlaw.EngineLimit | REPAIRED | w731-graphlaw-deepening.md (disclosure) + w976-design-wave5.md (SPEC-10 `Xaas.Graphlaw.LimitGate` + depth gate consumer) + w981k-registry-limits-seams.md (byte-limit gates at the real `Xaas.Bridges.Graphlaw.do_assess/3` seams: max_request_bytes/n3_max_term_bytes/n3_max_total_bytes, typed `:limit_exceeded` refusals, fail-open on absent rows court-pinned) + W982l verified table (SPEC-10 LANDED-UNCOMMITTED, limit_gate.ex on tree). Court re-witnessed GREEN by w983p-register-flips.md (fresh root `_build-laneW983p`, pinned toolchain: graphlaw_limit_gate_test.exs + graphlaw_limit_seams_test.exs green, 44 passed across the combined court run, exit 0) — flip W983p. W984aw graphql-era citation sweep: the load-bearing citation is the graphlaw_limit_gate + graphlaw_limit_seams courts (both files confirmed on disk post-removal, graphql-independent seams at `Xaas.Bridges.Graphlaw.do_assess/3`); the w983p combined 44-run also included 3 graphql court files (graphql_http_surface / graphql_domain_wiring_court / graphql_schema_test) now deleted by the operator removal — those components of the re-witness are superseded, status unaffected. |
| GAP(graphlaw-registry-path-hardcoded): `Catalog.default_registry_path/0` hardcoded `/Users/sac/...`, host-bound | w731-graphlaw-deepening.md | lib/xaas/graphlaw catalog | REPAIRED | w731-graphlaw-deepening.md (disclosure) + w897-cheap-repairs.md row 11 (`Application.get_env(:xaas, :graphlaw_registry_path, @default_registry_path)`; 18/18, mutation = revert to bare attribute → 17/18 RED; confirmed on tree at catalog.ex:29) — flip W968b |
| W745 rescue-arm (-32603) contract documented but never exercised by a real raise | w745-execution-fabric-deepening.md | MCP dispatch rescue arm | REPAIRED | w745-execution-fabric-deepening.md (disclosure) + w945c-batch5-repairs.md (court c.5: real `FunctionClauseError` raise on the real wire path — `claim_next` with non-accessible `arguments` — answered by the fail-closed -32603 envelope; 16/16 ×2; mutation = rescue-arm error code flipped -32603→-32604, killed 15/16, restored byte-identical) |
| W750-G1: no ALIVE-requires-execution gate (`executed` plain field; ALIVE+unexecuted ingest `:ingest` accepted) | w750-liveness-deepening.md | capability liveness receipt ingest | REPAIRED | w750-liveness-deepening.md (disclosure) + w945c-batch5-repairs.md (gate `CapabilityLivenessReceiptStatusGate` landed by W768 at `lib/xaas/operations/capability_liveness_receipt.ex:179`, ALIVE-without-execution → typed `ALIVE_WITHOUT_EXECUTION` refusal; witnessed 17/17 across deepening+receipt suites, mutation = gate unwired, killed 7/9, restored byte-identical) |
| W750-G2: `detect/1` blind to upsert-overwritten regressions (history destroyed by identity upsert); no TTL/staleness | w750-liveness-deepening.md | capability liveness detect/1 | REPAIRED | w750-liveness-deepening.md (disclosure) + w968c-design-wave1.md SPEC-14 (previous_status column + migration `20261007231000`, `SetPreviousStatus` before_action change, detect/1 in-place regression branch; blindness pin flipped; 11 passed ×5 in the receipt) + W982l verified table (SPEC-14 LANDED-COMMITTED, commit `fd471722`). Court re-witnessed GREEN by w983p-register-flips.md (capability_liveness_deepening_test.exs in the combined 44-passed run, fresh root `_build-laneW983p`) — flip W983p. W984aw graphql-era citation sweep: load-bearing evidence is w968c SPEC-14 + commit `fd471722` (graphql-independent); the w983p re-witness run included deleted graphql courts — those components superseded, capability_liveness_deepening_test.exs on disk, status unaffected. |
| XAAS-W763-G1: candidate-cannot-authorize unenforced at `run/4` authority channel | w763-sa2a-boundary-court.md | Xaas.Actuation.Kernel.admit_authority/2 | REPAIRED | w780-claim-authority-guard.md (21 passed, `:w763_measured_gap` → `:w780_closed`, refusal wire shape witnessed) |
| W765 GAP-A: no mint-time TTL input (`expires_at` not accepted by `:issue`) | w765-export-token-deepening.md | Xaas.?.AuditExportToken `:issue` | REPAIRED | w765-export-token-deepening.md (original disclosure) + w900-batch2-repairs.md (repair: `create :issue` accept list extended with `:expires_at`; real-action-surface court 17 passed exit 0, mutation-reverted run 15/17 confirms load-bearing) |
| W765 GAP-B (+reuse-after-use): no `:use`/`:consume`/`:verify` action; single-use not enforced | w765-export-token-deepening.md | AuditExportToken action surface `[:issue, :read, :revoke]` | REPAIRED | w765-export-token-deepening.md (disclosure) + w935-spec16-impl.md (new `update :use` action: stamps `used_at`, `increment(:use_count, amount: 1)`, `AuditExportTokenNotAlreadyUsed` guard, `patch(:use)` json_api route; 21/21 ×2; both mutations — remove NotAlreadyUsed, remove ExpiredTokenRefused — kill exactly the corresponding court, 20/21 each) + w940b-spec16-commit.md (committed as `fab56ae1`) |
| W765 GAP-C: no action refuses reuse-after-expiry (calculation-only) | w765-export-token-deepening.md | AuditExportToken active? calculation | REPAIRED | w765-export-token-deepening.md (disclosure) + w935-spec16-impl.md (SPEC-17 `AuditExportTokenExpiredTokenRefused` validation on the `:use` path, typed `Ash.Error.Invalid` field `:expires_at`; expired-token court flips 20/21 under mutation) + w940b-spec16-commit.md (committed as `fab56ae1`) |
| W765 GAP-D: no runtime consumer gates on active freeze window (override-gate only) | w765-export-token-deepening.md | FreezeWindow | REPAIRED | w765-export-token-deepening.md (disclosure) + w969b-design-wave2.md SPEC-18 (`Xaas.Governance.Checks.FreezeWindowActive` fail-closed check + court freeze_window_active_gate_test.exs 5 passed) + w969c-design-wave3.md (wired onto `ApprovalEnvironmentPromote :approve`; W970b's open-sweep ceded the row to this landing) + W982l verified table (SPEC-18 LANDED-COMMITTED, commit `5a853130`). Court re-witnessed GREEN by w983p-register-flips.md (freeze_window_active_gate_test.exs in the combined 44-passed run, fresh root `_build-laneW983p`) — flip W983p. W984aw graphql-era citation sweep: load-bearing evidence is w969b SPEC-18 + w969c wiring + commit `5a853130` (graphql-independent); w983p re-witness's deleted graphql components superseded, freeze_window_active_gate_test.exs on disk, status unaffected. |
| W770 vacuous approvals: `Validations.*RequiresApprover` return `:ok` unconditionally; `Changes.*Approve` identity pass-throughs wired to no action | w770-platform-deepening.md | platform approval validation/change modules | REPAIRED | w770-platform-deepening.md (original disclosure) + w900-batch2-repairs.md (witnessed REPAIRED by W792's landed approver wiring; verify-first run platform_route_deepening 19 passed exit 0) |
| W770 no transition path: RouteProjectsBackups lacks `:update`/`:destroy` (no retention sweep) | w770-platform-deepening.md | RouteProjectsBackups | REPAIRED | w770-platform-deepening.md (disclosure) + w970b-open-sweep.md (SPEC-20 retention sweep landed: `destroy :purge_expired` + `delete(:purge_expired)` json_api route + `RouteProjectsBackupsRetainUntilPassed` validation wired, 65 passed ×2 incl. sibling landings; commit `b2758300`; confirmed on tree at route_projects_backups.ex:132) + courts `test/xaas/platform/retain_until_passed_w984dv_test.exs` + `purge_expired_atomicity_court_test.exs` on disk. Honesty boundary: `:update` remains absent (only `:create` + `:purge_expired` exist) — the gap's load-bearing demand (retention destroy path) is the landed half — flip W984ff |
| W770 RouteProjects dead-write: only `:read`; approval metadata unproducible | w770-platform-deepening.md | RouteProjects | REPAIRED | w770-platform-deepening.md (disclosure) + w792-approver-wiring.md (real maker-checker `update :approve` wired with `RouteProjectsRequiresApprover` validation + `RouteProjectsApprove` change, `patch(:approve)` route; confirmed on tree at route_projects.ex:63-71) — flip W971 |
| W784 TOFU: pinning / rotation refusal / defer-to-parent chain absent in repo and ash_a2a dep | w784-tofu-probe.md | a2a agent-card trust surface | REPAIRED | w784-tofu-probe.md (UNSUPPORTED disclosure) + w984fv-w784.md (`Xaas.A2a.Tofu` landed: first-use fingerprint pin (SHA-256 over canonical card JSON), typed `:pin_mismatch` refusal on any subsequent card change under unchanged name, explicit `repin/1` as the only rotation path, `verify_and_ingest/1` gating the real `Xaas.A2a.Catalog` seam; court test/xaas/a2a/tofu_test.exs 6/6 exit 0 narrow, 6/6 inside 5394-test census; mock gate `[]`. Honesty boundary: defer-to-parent chain remains absent (repo + pinned ash_a2a dep) — stays a typed campaign-backlog gap. Census honesty: 25 census failures all on unrelated concurrent-lane surfaces (0 session-introduced); `_build-laneW984fv` rm DENIED by permission system, lease left for coordinator. Falsifier: mutate `verify/1` mismatch branch to re-pin silently → courts 3 and 6 fail |
| W793 GAP(RESOLVED_AT_GUARD_ONLY_ON_UPDATE), GAP(NO_REOPEN_GUARD), GAP(NO_RESOLVED_AT_GUARD), GAP(NO_POSTMORTEM_STATUS_GUARD) | w793-incident-lifecycle-deepening.md | incident lifecycle resource | REPAIRED | w793-incident-lifecycle-deepening.md (disclosure) + w818-incident-guards.md (RESOLVED_AT_GUARD_ONLY_ON_UPDATE + NO_REOPEN_GUARD; verified in-tree by W902) + w902-batch3-repairs.md (remaining NO_RESOLVED_AT_GUARD + NO_POSTMORTEM_STATUS_GUARD; new `IncidentResolvedAtRequiresResolved` / `IncidentPostmortemFinalRequiresResolved` validations wired on `:update`; 16/18 with exactly the 2 new tests failing under `sed` mutation, restored byte-identical; final run 101/102, 1 failure proven pre-existing) |
| W793 GAP(NO_CROSS_REFERENCE): incident↔castle link absent at resource layer | w793-incident-lifecycle-deepening.md | incident resource | REPAIRED | ALREADY-LANDED by commit b2758300 (receipt w970b-open-sweep.md row 2: migration 20261007240000_add_castle_run_id_to_incidents + `belongs_to :castle_run` on Incident, :update-accept court); courts re-witnessed GREEN ×2 (30/30 both runs) at HEAD by w983d-design-row-repair.md (fresh root _build-laneW983d, pinned toolchain); flip W983d |
| W796-G1: no per-student concurrent/aggregate borrow cap | w796-checkout-policy-deepening.md | library checkout policy | REPAIRED | w796-checkout-policy-deepening.md (disclosure) + w902-batch3-repairs.md (before_action `Ash.count!` guard, `@max_open_checkouts_per_student = 3`, aggregate across books, return frees capacity; mutation `>= 999_999` → 11/13 with exactly the cap tests failing, restored byte-identical) |
| W796-G2: `:return` lacks already-returned/unborrowed guard; inventory inflation | w796-checkout-policy-deepening.md | library `:return` action | REPAIRED | w809-return-guard.md (12/12, DB-reading before_action guard, mutation-run proven) |
| W796-G3: fulfilled hold mints no real Checkout row; hand-off implicit | w796-checkout-policy-deepening.md | hold fulfillment | REPAIRED | w796-checkout-policy-deepening.md (disclosure) + w970b-open-sweep.md row 3 (LANDED: `HoldRequest :fulfill` after_action mints the real hand-off Checkout in the same transaction as the inventory decrement; mutation = minting change unwired → 11/12 with exactly the fulfill court RED, restored byte-identical; commit `b2758300`; confirmed on tree at hold_request.ex:113-168, code comment names W970b/W796-G3) — flip W984ff |
| UNSUPPORTED(reversal-action-absent): no `:refund`/`:reverse`/`:undo` action in ledger; double-reverse guard is sufficiency-accident | w799-reversal-deepening.md | lib/xaas/ledger/ | REPAIRED | w799-reversal-deepening.md (disclosure) + W968c SPEC-27 (commit `352cc34c` per w969f-design-wave5.md table): `create :reverse` on `Xaas.Ledger.Transfer` (from/to swapped, `TransferSourceSufficiency` validation), `ReverseTransfer` change sets `reverses_transfer_id` (excluded from accept lists), `identity(:unique_reversal)` DB backstop against double-reversal; confirmed on tree at transfer.ex:55-66,84-87,102-107; court `test/xaas/ledger/reversal_deepening_test.exs` on disk (re-witness GREEN by W984ff) — flip W984ff |
| UNSUPPORTED(credit-path-unfundable): `credit_sla/1` no sufficiency exemption; unfunded SLA-credit flow RED (3/5, W785's lane) | w799-reversal-deepening.md | credit_sla/1 | REPAIRED | w799-reversal-deepening.md (disclosure) + w945b-batch4-repairs.md row 28 (verify-first, no new code: the `:transfer` create in `lib/xaas/billing/changes/approval_sla_credit_apply_approve.ex:119` (+ `approval_patch_` twin) carries `context: %{xaas_ledger: %{allow_overdraft: true}}` sufficiency exemption; falsifier suite `test/xaas/billing/approval_sla_credit_apply_test.exs` 5/5 exit 0 ×2 on a fresh `_build-laneW945b` root) |
| W804 operator action: `mix ecto.migrate` still must run on xaas_dev (index recorded on test only) | w804-epoch-dedup.md | priv/repo/migrations/20261007120000_*.exs | REPAIRED | w804-epoch-dedup.md — W971 audit update: the index `ultracode_epochs_unique_run_cycle_index` NOW EXISTS in xaas_dev (verified via pg_indexes), but schema_migrations on dev has no row for `20261007120000` (or `20261007210000`/`20261007220000`) — the index was created by direct DDL, not ecto.migrate. The literal operator action is still outstanding AND now hazardous: a future dev `mix ecto.migrate` will replay migrations already half-applied and fail on the existing index. Coordinator: either record the versions (`mix ecto.migrate --version`-style stamp) or drop-and-replay. Stays OPEN. W984ff re-verify (2026-10-07): all three versions (`20261007120000`, `20261007210000`, `20261007220000`) NOW PRESENT in xaas_dev `schema_migrations` (psql `-tAc` query returned 3 rows) — bookkeeping hazard cleared, operator action complete — flip OPEN → REPAIRED (W984ff). |
| W802/W819 UNSUPPORTED(graphql-http-surface): AshGraphql schema compiles, never mounted | w819-graphql-doc-fix.md | lib/xaas/graphql_schema.ex; router grep 0 hits | OUT-OF-SCOPE(removed-by-operator, 2026-10-07) | The GraphQL surface this gap tracked was REMOVED by operator directive (2026-10-07: remove graphql code, fix forward) — code removal is lane W984ao (`docs/sjira/v26.10.6/plans/w984ao-graphql-removal.md`, receipt not yet on disk at this flip; e2e removal receipt `w984ap-e2e-removal.md` exists, plus `w984ao1-e2e-graphql-check.md`); docs counterpart lane W984aq deleted the http-api-surface.md /api/graphql section the SPEC-30 era wrote. Prior REPAIRED-via-SPEC-30 history (w975b/w973c/w982l/w983p) is superseded by the removal. |
| GAP(graphql-domain-coverage): 3 domains wired (Operations, Library, Marketplace), not all | w819-graphql-doc-fix.md | lib/xaas/graphql_schema.ex | OUT-OF-SCOPE(removed-by-operator, 2026-10-07) | Demand is moot: the GraphQL surface (schema + per-resource graphql blocks + Absinthe mount) is being removed by operator directive 2026-10-07 (lane W984ao, `w984ao-graphql-removal.md` pending; e2e `w984ap-e2e-removal.md`); domain-coverage wiring to a deleted surface has no remaining demand. Docs counterpart W984aq. |
| W824 wire-layer coupling absent: QuiescentStop typed envelope never surfaces on MCP wire (kernel raw envelope returned) | w824-quiescent-fabric-tie.md | fabric halt verb / kernel envelope projection | REPAIRED | w984w-witness-w824.md (SPEC-32 ALREADY-LANDED per w982g: `format_actuation/2` additive quiescent envelope `{target: "quiescent", already_stopped, intent_id, receipt_id}` at `lib/xaas_web/controllers/execution_fabric_controller.ex:742-766`, committed `9f1247c1`; court `test/xaas_web/quiescent_fabric_tie_test.exs` 9 passed ×3 green on fresh `_build-laneW984w` pinned-toolchain root) |
| W849 backlog-1: 4 PROVENANCE-ONLY surfaces lack sha256 pins in registry drift guard | w849-generated-surface-census.md | mcp_scope.ex, xaas.library.manufacture.ex, capital_census/facts.ex, ocel_envelope.ex | REPAIRED | w849-generated-surface-census.md (disclosure) + w852-provenance-pins.md (10 surfaces incl. all 4 PROVENANCE-ONLY pinned in `test/xaas/generated/registry_drift_guard_test.exs`) + w902-batch3-repairs.md (verify-first confirmation: registry drift guard green in the 101/102 final run) |
| W849 backlog-2 (P2-2): CI/regen leg proving pins match ontology sources | w849-generated-surface-census.md | registry drift guard test | REPAIRED | w849-generated-surface-census.md (disclosure) + w982g-lspec-wave.md (SPEC-34: `lib/xaas/generated/regen_check.ex` + `mix xaas.generated.regen_check` + court) + w984v-w849-ci-leg.md (CI leg: `.github/workflows/ci_cd.yaml:107-115` `ci`-job step "Generated-surface regen drift check" running the task under job `MIX_ENV=test`; step present on disk, YAML parses, exit-4 drift signal in the task via `System.halt`; falsifier = remove/rename the step → flip invalid). Flip W984v, applied to the register by W984ae (W984v had updated only the per-row verdict table in `w983p-register-flips.md`, not the register itself) |
| W849 backlog-3: McpScope moduledoc provenance TTL source outside pack-dir convention | w849-generated-surface-census.md | McpScope moduledoc | REPAIRED | w849-generated-surface-census.md (disclosure) + w945b-batch4-repairs.md row 35 (code repair: moduledoc regen command normalized to repo-relative form in `lib/xaas_web/mcp_scope.ex`; registry guard provenance annotation + new sha pin `8713a4bc…` in `test/xaas/generated/registry_drift_guard_test.exs`; 1 passed ×2; pin-corruption mutation killed, on-disk sha re-hashes to pin; honesty boundary: sources stay at `priv/ggen_igniter/mcp_a2a/` — literal pack-dir migration deliberately not done, design-class residue disclosed in w945b) |
| W811 UNSUPPORTED(test-scope): lease deepening is sequential-approximation only; concurrent interleavings courted elsewhere | w811-lease-kernel-deepening.md | lease kernel deepening test scope | TYPED-OPEN | w811-lease-kernel-deepening.md (scope boundary, not a defect) |
| W650c OPEN_GAP-1/2: RobustMargin.admit/4 malformed-input clauses missing | w650c-terminal-census.md | lib/xaas/semantics/robust_margin.ex:107 | REPAIRED | w676-margin-hardening.md (37/37, mutation-killed regression tests, W667 contract atoms witnessed) |
| W650c OPEN_GAP-3: art15 deepening test helper `value * 2.0` overflow at sample-construction | w650c-terminal-census.md | test/eu_ai_act/art15_deepening_test.exs:172,262 | REPAIRED | w650c-terminal-census.md (disclosure) + w865-gap3-fix.md (repair: DatasetAdmission helper rescue landed, 27/27 ×2, mutation-killed). Honesty boundary: the register row's named surface at art15:172,262 is W667-owned and still pinned; repair closes the gap at the DatasetAdmission helper boundary (`sliced_w1/3` typed refusal), not the art15 file itself |
| W650c OPEN_GAP-4: VulnerabilityLifecycle.respond/2 state-machine gap vs W540 15.5.s3 expectation | w650c-terminal-census.md | lib/xaas/semantics/vulnerability_lifecycle.ex:98 | REPAIRED | w659d-lifecycle-fixes.md (26 passed ×2, "both W650b terminal-3 lifecycle findings are green") |
| 49.3 EU-AI-Act corpus OPEN_GAP (deployer EU-database registration) — the wave's sole honest permanent open-gap row | w650c-terminal-census.md (registration W815, scope fix W779) | Xaas.EUAIAct.TitleIVVTest "EUAI-ACT 49.3 — OPEN_GAP" | TYPED-OPEN | w815-gap-registration.md (exactly 1 typed open gap, 49.3 + zero others) + w983n-typed-open-493.md (blocker anatomy re-derivation: duty is genuinely external — the Article 71 EU database is a Commission-operated registry with no deployer-facing machine endpoint the campaign controls, and the duty's own addressee predicate (public-authority deployer of an Annex III system) is an operator fact (none exists), so a local registration gate would be a vacuity-class zero-information check; census invariants re-witnessed ×2 at this lane's tree) |
| W880 counterfactual typedoc contradiction: `@typedoc check` claims bare anonymous 1-arity funs are supported, but `run/2` raises FunctionClauseError in `normalize_name/1` (`Function.info(fun, :name)` returns `{:name, atom}` — a tuple; normalize accepts only atoms/binaries) | w880-cf-doctests.md (incident disclosure) | lib/xaas/semantics/counterfactual.ex:167-194 | REPAIRED | w907-bare-fun-fix.md (mutation-killed) |
| W836 health-check no-timeout: checks wrapped in `try/rescue/catch` only — a hung collaborator hangs the whole health request | w836-health-court.md (typed gap, "a hung check would hang the request") | lib/xaas_web/controllers/health_controller.ex (`@check_timeout_ms` bounded-execution now present) | REPAIRED | w860-health-timeout.md (12/12 incl. hung-check court) |
| W893 GAP(CancelDoesNotReleaseSlot): EnforceSessionCapacity counted all statuses — `:cancelled` rows still consumed capacity slots | w893-enrollment-journey.md | lib/xaas/conference/registration.ex:158 (EnforceSessionCapacity) | REPAIRED | w893-enrollment-journey.md (disclosure) + w925-slot-release.md (LANDED 2026-10-07, re-checked present at sweep 6 after sweeps 4-5 found it absent: `@active_statuses [:registered, :attended]` filter on the capacity count, real statuses read from W795's forward-only transition set; slot-release regression court replaces the old-behavior pin; 15 passed ×2 determinism runs, mock gate `[]`) |
| W893 GAP(NoServerActionForCancel): cancel is a bare `:update` — no dedicated server action for the cancel transition | w925-slot-release.md (Typed gaps section, disclosed at closure of the slot-release repair) | conference Registration `:cancel` path | REPAIRED | w925-slot-release.md (disclosure: "remains open — out of W925 scope") + w947-cancel-action.md (named `update :cancel` with `RegistrationStatusTransition` validation landed; court flipped to `for_update(reg, :cancel, %{})`; 4 passed ×2, mutation = `:cancel` action removed → 0/1 court RED, restored; confirmed on tree at registration.ex:72) — flip W968b per W967 reconcile |
| dead-branch/contract-drift: `format_actuation`'s `maybe_refusal/2` `[:refused, :failed]` clause is DEAD on the admitted fabric path — kernel refusals normalize to admit-time tool errors and OK envelopes carry only `:succeeded`/`:replayed`, so W844's quiescent `refusal` surfacing was wired to an unreachable branch; W866's courts fence it. Disposition options: delete the dead branch, or leave fenced by W866's courts until the kernel contract changes | w866-refusal-court.md (key finding); registered by w938-dead-branch-register.md | lib/xaas_web/controllers/execution_fabric_controller.ex:752-755 | REPAIRED | w866-refusal-court.md (key finding; registered by w938-dead-branch-register.md) + W971 audit (disposition option 1 TAKEN: the `maybe_refusal/2` `[:refused, :failed]` clause and its `refusal_code/1` helpers are DELETED on tree — confirmed by `git diff` removal lines + on-tree note at execution_fabric_controller.ex:734; W866's courts (g)/(h) in quiescent_fabric_tie_test.exs remain as the tripwire. Honesty boundary: no plan receipt names the deleting lane — the deletion is an uncommitted working-tree change; repair receipt NOT identifiable) — flip W971 |
| W902 environmental: shared `xaas_test` DB sandbox-escape contamination class — stray committed rows from cross-lane sandbox escapes pollute `Ash.count!`-based count assertions (`checkout_actuation_test.exs` hit `count == 6 != 2` from stale rows at 12:14–12:22; lane purged 4 stray rows by hand); recurrence expected under fan-out until coordinator hygiene pass or per-lane test DBs | w902-batch3-repairs.md (out-of-lane observation 3, registered by w943b-register-sweep-4.md) | shared `xaas_test` DB / sandbox boundary | REPAIRED | w984fs-w902.md (live reproduction 2026-10-07: 0/2 with 2 sanctioned committed seed rows visible; root cause re-typed — rows are the sanctioned W984bs `DevSeeds.run(e2e: true)` boot-path rows, permanent by design, so the defect is the table-wide count assertion, not the rows; `checkout_actuation_test.exs` converted to baseline-delta count assertions per the `dev_seeds_idempotency_test.exs` pattern; 0/2 → 2/2 on same DB state; census disclosed as contention-blocked — six compile-aborts from other lanes' in-flight
`family_court_*` files, tree clean between runs; narrow falsifier + mock gate in receipt) |
| W838-G1: test-harness direct-delivery quirk — fresh `Task` relay subscribed to two topics simultaneously goes deaf after its first delivered broadcast; no production-code implication (W909 root cause: harness-shape limitation, NOT a Phoenix.PubSub/:pg/OTP-28 defect — the awaiting test process was itself a real subscriber, so every broadcast arrived twice, and the topic-prefix-only `await_relay` requeue-scan let a stale duplicate satisfy a later await, starving the fresh broadcast; upstream semantics check clean, no upstream finding warranted) | w838-pubsub-publish-court.md (disclosure) + w909-pubsub-g1-rootcause.md (root cause R1-R3 repro matrix) + w918b-awaiter-hardening.md (repair: every await uniquely bound to expected payload id, 11 call sites; 9/9 ×3 real runs, mutation evidence rerun) | test/xaas/library/pubsub_publish_court_test.exs harness | REPAIRED | w918b-awaiter-hardening.md (9/9 ×3, hardened awaiter green; honesty boundary: suite-shape masking means the mutation is non-killing on the current court — W909 R3 repro is the killing evidence for the failure class the hardening closes; R3 rerun 2026-10-07 still firing) |
| W969e GAP(same-attendee-re-register-blocked-by-identity): `unique_attendee_session` scoped the identity with no status filter — a CANCELLED registration permanently blocked its attendee from re-registering into the same session even with a free slot | w969e-journey-legal.md (step-6 probe: A's re-register refused with "has already been taken" while the slot was FREE) | lib/xaas/conference/registration.ex (unique_attendee_session identity + :create) | REPAIRED | w981s-registration-identity-scope.md (identity declared with `where: expr(status in [:registered, :attended])`; MEASURED ash 3.34.4 boundary: `pre_check_with` path (Ash.Changeset.do_validate_identity/3) ignores `identity.where`, so the unscoped pre-check was removed and scoped enforcement landed as `EnforceActiveRegistrationIdentity` before_action change on :create; W981s court 3/5 ×2 with the two RED legs being the pre-existing W973b terminal-guard falsifier and the W969e step-6 old-behavior pin (asserts the repaired success is a refusal); mutation: drop/widen the change → court RED) |

> Status note (w970b, 2026-10-07): the W938 dead-branch row's coverage is consolidated in
> `docs/cro/artifacts/execution-fabric-coverage.md` (dispatch surface, courts, quiescent
> envelope, dead-branch disposition, W866 live fence — receipt w970b-fabric-coverage.md).

## Totals by status

- **REPAIRED**: 32 (W969e GAP(same-attendee-re-register-blocked-by-identity) → w981s-registration-identity-scope.md; W763-G1 → W780; W796-G2 → W809; W650c OPEN_GAP-1/2 → W676; W650c OPEN_GAP-4 → W659d; W650c OPEN_GAP-3 → W865; W765 GAP-A → W900-batch2; W770 vacuous approvals + RouteProjects dead-write → W792 (dead-write flip W971); W793 4-gap row → W818+W902; W796-G1 → W902; W849 backlog-1 → W852; W765 GAP-B + GAP-C → W935/W940b commit `fab56ae1`; W838-G1 → W909 root cause + W918b awaiter hardening; W893 CancelDoesNotReleaseSlot → W925; W893 NoServerActionForCancel → W947; W674-GAP-2 → w900 staging + w928 hygiene court; W674-GAP-1 → w902 staged-lib + w928 court + w945b witness; W799 credit-path → w945b row 28; W849 backlog-3 → w945b row 35; W722 gap-1 state guard → W740 landing witnessed by w945c; W745 rescue-arm court → w945c; W750-G1 gate → W768 landing witnessed by w945c; W665 kernel gap + W729 lifecycle + W729 approve-idempotency + W731 registry-path → w897 rows 1/5/drift/11 (flips W968b); W731 capability-class → w912 SPEC-09 (flip W971); W866 dead-branch → deleted on tree, receipt unidentified (flip W971))
- **TYPED-OPEN**: 2 (W811 test-scope boundary; 49.3 corpus open-gap row)
- **OPEN**: 17 rows — W722 gap-2 (`X-Org-Id` caller-asserted, split out at w945c),
  W729 multitenancy + atomic_update (2 rows), W731 limits-not-enforced,
  W750-G2, W765 GAP-D, W770 RouteProjectsBackups transition path, W784 TOFU,
  W793 NO_CROSS_REFERENCE, W796-G3 hold-fulfillment Checkout mint,
  W799 reversal-action-absent, W804 operator action (migrate bookkeeping now
  hazardous — see row annotation), W802/W819 graphql (2 rows), W824 wire coupling,
  W849 backlog 2, W902 sandbox-escape contamination (environmental).
- Total rows: **51** (9 OPEN + 40 REPAIRED + 2 TYPED-OPEN).
- W984w reconciliation (2026-10-07): W824 wire-coupling row FLIPPED OPEN →
  REPAIRED (w984w-witness-w824.md). Row-level tally re-run on disk after the
  flip: **40 REPAIRED / 9 OPEN / 2 TYPED-OPEN** across 51 table rows.
- W984aw graphql-era citation sweep (2026-10-07, post-W984ao/W984aq removal):
  all 51 rows enumerated fresh; every row's citations grepped for graphql_schema
  / graphql_domain_wiring / graphql_http_surface / Absinthe / SPEC-30/31.
  Hits beyond the 2 already-OUT-OF-SCOPE graphql rows (W802/W819 http-surface,
  graphql-domain-coverage — flipped by W984aq): 4 REPAIRED rows carried
  graphql-era citations that are graphql-INDEPENDENT in their load-bearing
  evidence — annotated in-row, no status change: W729 multitenancy (w975b
  cited for its billing/multitenancy half only; SPEC-30 half superseded),
  W731 limits-not-enforced (graphlaw_limit_gate + graphlaw_limit_seams
  courts confirmed on disk post-removal; w983p re-witness's 3 graphql court
  files deleted, those components superseded), W750-G2 (SPEC-14 + commit
  `fd471722`; same w983p supersession), W765 GAP-D (SPEC-18 + commit
  `5a853130`; same supersession). Zero rows flipped: no surviving row's ONLY
  evidence was a graphql court (the keynote/name-spec court,
  `keynote_graphql_surface_court_test.exs`, was cited by no register row —
  grep 0 hits — and is itself deleted). Verified on tree: `lib/xaas/graphql_schema.ex`
  absent, router.ex 0 graphql hits; surviving courts graphlaw_limit_gate_test.exs,
  graphlaw_limit_seams_test.exs, capability_liveness_deepening_test.exs,
  freeze_window_active_gate_test.exs all present. Fresh awk tally on disk:
  **51 rows = 40 REPAIRED / 7 OPEN / 2 TYPED-OPEN / 2 OUT-OF-SCOPE
  (removed-by-operator)** (W824's flip by W984w landed concurrently — verified
  row is graphql-independent; W984w's "9 OPEN" tally predates the w984aq
  graphql-domain-coverage flip). Receipt: `w984aw-graphql-rows.md`.
- W984ae reconciliation (2026-10-07): resolves W984ac's DRIFT(REGISTER_COUNT)
  (w984ac-cycle-advance.md). Fresh row-level awk tally on disk: 39 REPAIRED /
  10 OPEN / 2 TYPED-OPEN across 51 table rows. Root cause of the 39-vs-40
  discrepancy is twofold: (a) W984ac's flip-history arithmetic double-counted
  W722 gap-2 — claimed REPAIRED by w982t, applied to the register by w983d
  (register line 23) — one row, two receipts; true arithmetic is
  32 (W982q baseline) + 1 (W722 gap-2) + 1 (W793 NO_CROSS_REFERENCE) +
  4 (W983p) + 1 (W729 multitenancy, SPEC-07) + 1 (W849 backlog-2) = 40
  claimed. (b) W984v flipped W849 backlog-2 only in the per-row verdict table
  of `w983p-register-flips.md`, never in the register itself — 7 of the 8
  claimed flips were applied, so disk read 39. Flip applied this lane:
  W849 backlog-2 OPEN → REPAIRED citing w982g (SPEC-34 regen_check task) +
  w984v (CI leg at ci_cd.yaml:107-115); evidence verified on tree before
  flipping (step present, YAML parses per w984v, task file + w982g receipt on
  disk). Totals grep/awk-verified: **51 rows = 9 OPEN + 40 REPAIRED +
  2 TYPED-OPEN**. Remaining OPEN (9): W729 atomic_update, W770
  RouteProjectsBackups transition path, W784 TOFU, W796-G3 hold-fulfillment,
  W799 reversal-action-absent, W804 migrate bookkeeping (hazardous),
  W802/W819 graphql-domain-coverage, W824 wire coupling, W902 sandbox
  contamination (environmental).
- W982q reconciliation (2026-10-07): resolves W982n's DRIFT(REGISTER_COUNT)
  (w982n-cro-cycle-advance.md §(a)). Row-level tally re-run on disk: 17 OPEN /
  32 REPAIRED / 2 TYPED-OPEN across 51 table rows. The +1 is the W969e
  GAP(same-attendee-re-register-blocked-by-identity) row (appended after
  W980j's snapshot), flipped REPAIRED citing
  w981s-registration-identity-scope.md. Evidence verified on tree: receipt on
  disk; court at
  `test/xaas/conference/enrollment_journey_court_test.exs:402-408` (step-6
  re-register leg); `EnforceActiveRegistrationIdentity` before_action change
  present at `lib/xaas/conference/registration.ex:76,187`. Row is legitimate —
  REPAIRED count 31 → 32 stands. (Test execution is W982o's scope, not run
  here.)
- W945c update (2026-10-07, batch 5): 3 flips — W722 gap-1 OPEN → REPAIRED
  (stale row: repair already on HEAD by W740, now witnessed w/ mutation kill),
  W745 rescue-arm OPEN → REPAIRED (new court c.5: real raise → -32603 envelope,
  mutation-killed), W750-G1 OPEN → REPAIRED (stale row: repair already on HEAD
  by W768, now witnessed w/ mutation kill). W722 row split: gap-2 (`X-Org-Id`
  caller-asserted) re-registered as its own OPEN row. Row 35 (W849 backlog-3)
  was initially picked by this lane but dropped on the generated-surface rule
  (mcp_scope.ex is sha256-pinned, template in ~/ggen_igniter) — landed instead
  by w945b (no overlap).
- W950 update (2026-10-07): 1 flip — W674-GAP-2 OPEN → REPAIRED, triple-cited
  (w674 disclosure + w900 staging of the typed `:episode_id_required`/`:cut_required`
  refusals + w928 hygiene court, 11/11 ×2, no production code touched). Totals
  grep-verified (see w950-register-w674-flip.md).
- Status flips in this update: W765 GAP-A OPEN → REPAIRED, W770 vacuous approvals
  OPEN → REPAIRED (both witnessed by w900-batch2-repairs.md, sweep lane W923
  2026-10-07). W674-GAP-2 left OPEN with disclosure annotation.
- W944 update (2026-10-07): 3 new rows appended from W943's unregistered-repairs
  finding — W880 bare-fun typedoc contradiction → REPAIRED (w907), W836 health
  no-timeout → REPAIRED (w860), W893 CancelDoesNotReleaseSlot → OPEN (w925
  IN-FLIGHT; code-side status filter landed, receipt absent). Totals re-derived
  by grep-verification (see w944-register-new-rows.md).
- W943b sweep 4 (2026-10-07): w902-batch3-repairs.md landed → 3 flips, dual-cited:
  W793 4-gap row OPEN → REPAIRED (W818 closed 2, W902 closed the remaining
  NO_RESOLVED_AT_GUARD + NO_POSTMORTEM_STATUS_GUARD with mutation-killed courts);
  W796-G1 OPEN → REPAIRED (w902 borrow-cap guard, mutation-proven); W849 backlog-1
  OPEN → REPAIRED (w852 pins, verify-first confirmed green by w902). W893
  CancelDoesNotReleaseSlot stays OPEN — w925-slot-release.md test -f re-checked
  absent this sweep. W674-GAP-2 stays OPEN — w928 receipt absent (w902: flips when
  W928's court lands green). 2 new rows: W902 sandbox-escape contamination class
  (OPEN, environmental), W838-G1 harness quirk (TYPED-OPEN, UNKNOWN root cause,
  no production implication claimed by w838). W920's obs-witness tie court
  (w920-obs-witness-tie.md) adds cross-surface composition evidence only — no gap,
  no register change. Totals grep-verified (see w943b-register-sweep-4.md).
- W943c sweep 5 (2026-10-07): 3 flips — W765 GAP-B OPEN → REPAIRED and W765 GAP-C
  OPEN → REPAIRED (w935-spec16-impl.md: SPEC-16 `update :use` + SPEC-17
  `AuditExportTokenExpiredTokenRefused`, 21/21 ×2, both mutations kill exactly the
  corresponding court at 20/21; committed as `fab56ae1` per w940b-spec16-commit.md);
  W838-G1 TYPED-OPEN (UNKNOWN root cause) → REPAIRED with honest wording: W909
  root-caused it as a harness-shape limitation (NOT a PubSub defect — duplicate
  delivery into the awaiting test process + topic-prefix-only awaiter match), W918b
  hardened the awaiter (unique expected-payload-id binding, 9/9 ×3 real runs);
  honesty boundary kept in the row: the mutation is non-killing on the current
  court shape (suite-shape masking) — W909's R3 repro is the killing evidence for
  the class. W938 dead-branch row already landed (sweep 4, line 64) — no append
  needed, verified by grep. Totals re-derived by awk field-5 verification:
  48 rows = 31 OPEN + 15 REPAIRED + 2 TYPED-OPEN (see
  w943c-register-sweep-5.md).
- W946c sweep 6 (2026-10-07): w925-slot-release.md has LANDED since sweep 4's
  re-check (receipt present with real court run: 15 passed ×2 determinism,
  mock gate `[]`; code `@active_statuses` filter confirmed on tree at
  registration.ex:172-189) → 1 flip: W893 GAP(CancelDoesNotReleaseSlot)
  OPEN → REPAIRED, dual-cited w893 + w925. 1 new row appended from w925's
  Typed-gaps disclosure: W893 GAP(NoServerActionForCancel) (cancel is a
  bare `:update`), OPEN. w928-gymact-hygiene.md and w945b-batch4-repairs.md
  re-checked absent at sweep 6 close (test -f) — W674-GAP-2 stays OPEN,
  no batch-4 flips. w907/w860-adjacent rows (W880, W836) already REPAIRED
  since W944 — no change. Concurrent-edit reconciliation: read current disk
  state before editing; sweeps 4-5 rows (W938 dead-branch, W902 sandbox
  class, W838-G1, W765 GAP-B/C) kept intact. Totals grep-verified:
  49 rows = 31 OPEN + 16 REPAIRED + 2 TYPED-OPEN (see
  w946c-register-sweep-6.md).
- W960 sweep 7 (2026-10-07): 3 flips, all receipt-backed — W674-GAP-1 OPEN →
  REPAIRED (w902 verify-first staged-lib `:failed` seal + w928 hygiene court
  11/11 ×2 + w945b row-selection audit re-witness; dispatch citation "w897 row 1"
  was a mismatch — w897 row 1 is W665, disclosed in the row), W799
  credit-path-unfundable OPEN → REPAIRED (w945b row 28 verify-first, 5/5 ×2 fresh
  `_build-laneW945b` root), W849 backlog-3 OPEN → REPAIRED (w945b row 35 code
  repair, repo-relative regen command + re-minted sha pin, pin-corruption
  mutation killed, 1/1 ×2). W674-GAP-2 verified already REPAIRED (sweeps
  5/W950) — no double flip. w925-covered rows already flipped at sweep 6
  (CancelDoesNotReleaseSlot); w925's NoServerActionForCancel stays OPEN per
  w925 itself. w928-covered row (GAP-2) already flipped. Observed, not flipped
  (receipt-backed by w897-cheap-repairs.md but outside sweep-7 dispatch):
  W665 kernel gap, W729 lifecycle-state-machine, W731 registry-path-hardcoded
  — all three have landed mutation-killed repairs in w897 rows 1/5/11, left
  OPEN here pending a dispatch that names them. Concurrent-edit
  reconciliation: disk state read before edit; sweeps 4-6 annotations kept
  intact. Totals grep/awk-verified: 49 rows = 27 OPEN + 20 REPAIRED +
  2 TYPED-OPEN (see w960-register-sweep-7.md).
- W968b sweep 9 (2026-10-07, per W967's triage-final reconcile): 5 flips, all
  receipt-backed and confirmed on tree before flipping — W665 kernel gap OPEN →
  REPAIRED (w897 row 1: bare-atom `REFUSED_EUAIA_EMOTION_RECOGNITION` trigger,
  7/7 + mutation 6/7), W729 lifecycle-state-machine OPEN → REPAIRED (w897 row 5:
  `SubscriptionStripeTransitionAllowed`, 13/13 + mutation 12/13), W729
  approve-idempotency OPEN → REPAIRED (stale row: W746's
  `filter(expr(is_nil(approved_by)))` guard already on HEAD at
  approval_sla_credit_apply.ex:133, verified by w897's row-selection drift
  note), W731 registry-path-hardcoded OPEN → REPAIRED (w897 row 11:
  `Application.get_env` override, 18/18 + mutation 17/18), W893
  GAP(NoServerActionForCancel) OPEN → REPAIRED (w947-cancel-action.md: named
  `update :cancel` + status-transition validation, 4 passed ×2, mutation
  0/1 court-killed). All five confirmed on tree (grep hits: eu_ai_act_admission.ex:184,
  subscription.ex:219, approval_sla_credit_apply.ex:133, catalog.ex:29,
  registration.ex:72). No row remained unverifiable. Totals grep/awk-verified:
  50 rows = 20 OPEN + 28 REPAIRED + 2 TYPED-OPEN (see
  w968b-register-final-flips.md).
- W971 open-recount audit (2026-10-07): full re-audit of the then-25 OPEN
  rows against the tree (grep/psql per row; method in w971-open-recount.md).
  Concurrent-edit reconciliation: W968b's 5 flips (W665, W729 lifecycle,
  W729 approve-idempotency, W731 registry-path, W893 NoServerActionForCancel)
  landed on disk mid-audit — verified against my own independent findings
  (all 5 matched; no divergence) and NOT re-flipped. 3 additional flips by
  this lane: W731 capability-class OPEN → REPAIRED (w912 SPEC-09,
  capability.ex:28,45 + migration 20261007210000), W770 RouteProjects
  dead-write OPEN → REPAIRED (w792, route_projects.ex:63-71 `update :approve`),
  W866 dead-branch OPEN → REPAIRED (`maybe_refusal/2` clause DELETED on tree,
  uncommitted working-tree change, deleting-lane receipt NOT identifiable —
  honesty boundary recorded in the row). 1 annotation, no flip: W804 — the
  dedup index now exists in xaas_dev (pg_indexes) but schema_migrations lacks
  20261007120000/210000/220000 (direct DDL, not ecto) → literal operator
  action outstanding and now hazardous on replay; stays OPEN. 16 rows
  confirmed genuinely OPEN with on-tree absence evidence each: W722 gap-2
  (design-class, SPEC-04), W729 multitenancy (comments at
  approval_sla_credit_apply.ex:64, subscription.ex:249 confirm unwired),
  W729 atomic_update (0 grep hits in lib/xaas/billing/), W731
  limits-not-enforced (EngineLimit referenced only inside graphlaw modules —
  no consumer gate; SPEC-10), W750-G2 (detect/1 compares last-two inserted_at
  only, no TTL; SPEC-14), W765 GAP-D (only override-resource mentions, no
  runtime gate; SPEC-18), W770 RouteProjectsBackups (0 update/destroy;
  SPEC-20), W784 TOFU (0 traces in lib/; deferred), W793 NO_CROSS_REFERENCE
  (0 castle refs in incident.ex; SPEC-24), W796-G3 (0 Checkout refs in
  hold_request.ex; SPEC-26), W799 reversal-action-absent (0 refund/reverse
  hits in lib/xaas/ledger/; SPEC-27), W802/W819 graphql-mounted (0 graphql
  hits in router.ex; SPEC-30), graphql-domain-coverage (still exactly 3
  domains in graphql_schema.ex:5; SPEC-31), W824 wire coupling (halt still
  rides the actuation verb per execution_fabric_controller.ex:760; SPEC-32),
  W849 backlog-2 (no drift-guard leg in .github/workflows/; SPEC-34), W902
  sandbox contamination (environmental). Most OPEN rows are docketed to a
  SPEC in w905-design-gap-specs.md. Totals grep/awk-verified:
  50 rows = 17 OPEN + 31 REPAIRED + 2 TYPED-OPEN (see w971-open-recount.md).
- W980j final sweep (2026-10-07, close-out): all 9 repair receipts re-verified
  present on disk (test -f: w928, w947, w907, w860, w925, w935, w945b, w897,
  w902). W674-GAP-1 confirmed REPAIRED (row already carries the w902+w928+w945b
  triple citation — w928's court names `:episode_id_required` among the 4
  witnessed typed refusals; covers the task's episode_id_required check).
  W893 GAP(NoServerActionForCancel) confirmed REPAIRED (row wording matches the
  landed code: w947 named `update :cancel` + `RegistrationStatusTransition`
  validation at registration.ex:72 — the gap's "no dedicated server action"
  wording is satisfied by the now-named action). Keyword cross-check of the
  remaining 17 OPEN rows against all 9 landed receipts: 0 coverage hits —
  no further flips. Totals grep/awk-verified (separator row excluded):
  **50 rows = 17 OPEN + 31 REPAIRED + 2 TYPED-OPEN** — unchanged from W971's
  recount; this lane is confirmation-only. Working-tree observation
  (disclosure, no flip): 4 platform approval modules deleted uncommitted
  (`route_orgs_custom_domain_approve.ex`, `route_projects_backups_approve.ex`
  + their validations) — these are the W770 vacuous pass-through modules
  themselves; zero remaining references in lib/ (dead-code removal). The
  REPAIRED W770 rows' surfaces (route_projects.ex approve wiring) are
  untouched; no register row's status is affected. Concurrent-edit
  reconciliation: register mtime checked at sweep start (last touched ~30 min
  prior, W971's annotation) — no contention. Totals see
  w980j-register-close.md.
- W984ff re-verify (2026-10-07, lane W984ff): 4 flips, all OPEN → REPAIRED,
  verified against the tree before flipping — W770 RouteProjectsBackups
  transition path (w970b SPEC-20: `destroy :purge_expired` + retain-until
  validation at route_projects_backups.ex:132, commit `b2758300`, courts
  retain_until_passed_w984dv_test.exs + purge_expired_atomicity_court_test.exs
  on disk; honesty boundary: `:update` still absent — the retention destroy
  path is the gap's load-bearing demand), W796-G3 hold-fulfillment Checkout
  mint (w970b row 3: real hand-off Checkout minted in the `:fulfill`
  after_action at hold_request.ex:113-168, commit `b2758300`, mutation
  11/12 exact-court RED), W799 reversal-action-absent (W968c SPEC-27, commit
  `352cc34c`: `create :reverse` + `reverses_transfer_id` +
  `identity(:unique_reversal)` at transfer.ex:55-107; court
  reversal_deepening_test.exs re-witnessed GREEN by this lane, fresh
  `_build-laneW984ff` root, pinned toolchain), W804 migrate bookkeeping
  (psql on xaas_dev: schema_migrations now holds 20261007120000/210000/220000
  — hazard cleared, operator action complete). W729 atomic_update annotated
  in-row: stays OPEN (SPEC-08 BLOCKED(billing-tree-hot), w984az plan staged +
  w984bd per-site classification, no landing). W984eb's FRIA
  right-to-remedy `:OPEN_GAP` → `:EVIDENCED` flip checked: that surface
  (oversight_governance fria/0) was never a register row — no register
  change; receipt w984eb-probe.md. No other NEW repairs found in
  w984*/w650* receipts beyond the 4 above (grep sweep of w984a*-w984f*,
  w650* for OPEN-row keywords: W784 TOFU 0 lib/ hits, stays OPEN; W902
  sandbox-escape contamination, no repairing receipt, stays OPEN).
  Fresh row-level awk tally on disk after flips: **51 rows = 44 REPAIRED /
  3 OPEN / 2 TYPED-OPEN / 2 OUT-OF-SCOPE (removed-by-operator)**.
  Receipt: `w984ff-probe.md`.

## Addendum (2026-10-08, lane W984kd) — footer tally re-derived from disk

Row-level awk tally on disk (status column, 51 table rows):
**46 REPAIRED / 1 OPEN / 2 TYPED-OPEN / 2 OUT-OF-SCOPE (removed-by-operator)**.

Delta vs. the W984ff footer (44/3/2/2): the two row flips it predates are
already reflected as row updates on disk —

- W784 TOFU → REPAIRED (row updated; receipt `w984fv-w784.md`)
- W902 sandbox-escape contamination → REPAIRED (row updated; receipt
  `w984fs-w902.md`)

Both footer "stays OPEN" claims for W784/W902 are therefore stale, as are its
counts. (Grep: footer also states "Fresh row-level awk tally ... 44 REPAIRED /
3 OPEN" — superseded by this addendum.)

Sole remaining OPEN row: **W729 UNSUPPORTED(atomic_update)** (line 29). Its
marker is itself stale relative to evidence: `w983p-register-flips.md` row
"FLIPPED → REPAIRED (w984cc)" + receipt `w984cc-spec08-execute.md` (3 true
conversions, court green ×2, mutation killed) re-witnessed by
`w984fr-atomic-site1.md` ("ALREADY-LANDED"). The row's cited blocker
(BLOCKED(billing-tree-hot) per w984az, full 8-site plan staged) is superseded —
5 sites remain disclosure-only by design, not blocked. Per addendum-only
discipline the row was not rewritten; a later lane may flip the marker and
the true fully-applied tally would then be **47 REPAIRED / 0 OPEN / 2
TYPED-OPEN / 2 OUT-OF-SCOPE**.

## Addendum (2026-10-08, lane W984kh) — W729 marker flipped; tally fully applied

W729 UNSUPPORTED(atomic_update) row (line 29) flipped **OPEN → REPAIRED**
citing `w984cc-spec08-execute.md` + `w984fr-atomic-site1.md` + a fresh court
run by this lane: `test/xaas/billing/atomic_retrofit_court_test.exs` under
`MIX_BUILD_ROOT=_build-laneW984kh` — **3 passed, 0 failures, exit 0**
(2026-10-08). The prior addendum's predicted fully-applied tally is now the
on-disk truth. Fresh row-level awk tally on disk (status column, 51 table
rows): **47 REPAIRED / 0 OPEN / 2 TYPED-OPEN / 2 OUT-OF-SCOPE
(removed-by-operator)** — fully applied. Receipt: `w984kh-w729.md`.
