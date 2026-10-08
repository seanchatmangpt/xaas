# W984ky — truth-pass: docs/claude/diataxis/tutorials/ (2026-10-08)

Lane W984ky, docs-only, no commit, no build root. Branch `feat/playwright-surface`,
HEAD at pass time `7d9968d0` + working tree (sibling-modified files read from disk:
`lib/xaas/ultracode/lease.ex`, `lib/xaas_web/controllers/execution_fabric_controller.ex`,
`test/xaas/operations/capability_liveness_deepening_test.exs`).

Dir listing: 2 files — `build-an-autonomic-capability-loop.md`,
`receipted-provider-lifecycle.md`. README.md fall-through not needed.

## Per-file verification

### build-an-autonomic-capability-loop.md

Checked on disk (grep/sed, real paths):

- `Xaas.Actuation.run/4` at `lib/xaas/actuation.ex:26` — OK.
- `lib/xaas/operations/capability_liveness_receipt.ex`: oban block `:45-59`
  (schedule `*/15 * * * *`, `default_actor` `:oban_scheduler`) — OK; read bypass
  `:80` — OK; `bypass action(:ingest)` `:100-102` — OK; StatusGate validate
  `:175` (doc said `:179` — STALE, corrected to `:175`); `json_api` routes block
  `:114+` read-only — OK.
- `lib/xaas/operations/capability_liveness_regressions.ex`: `detect/1` defaults
  `authorize?: true` (`:34`) — OK.
- `lib/mix/tasks/xaas.ingest_capability_receipts.ex` exists; runs through
  authorization as `:oban_scheduler`, no `authorize?: false` — OK.
- `lib/xaas/ultracode/lease.ex` (sibling-modified, disk state): `live_leases/1`
  `:372`, `renew/1` `:513`, both judge on `DurationBudget.now()` — OK (W840
  clock-seam claim intact after sibling edits).
- `lib/xaas_web/controllers/execution_fabric_controller.ex` (sibling-modified,
  disk state): 10 MCP tool names still at `:72-220` (`claim_next`, `heartbeat`,
  `admit_tool`, `record_provider_event`, `close_candidate`, `refuse`,
  `cancel_work`, "actuate", `resolve_capability`, `surface`); `mcp/2` action at
  `:323` — doc anchor `:72-220` still exact.
- Router: specific `/internal-api` GET routes registered before catch-all
  `forward` (`lib/xaas_web/router.ex:92-140`) — OK; plug
  `require_internal_api_token.ex` exists — OK.
- `api_router.ex` 7 domains `:12-20` — OK. `org.ex` routes block `:175-181`
  (doc said `:178-188` — STALE, corrected).
- All 7 cited court receipts exist (w723/w817/w768/w840/w811/w749/w666) — OK.
- All cited test files exist — OK.
- New-since-doc note added: `:ingest` now also carries
  `change {Xaas.Operations.Changes.SetPreviousStatus, []}` (W968c/SPEC-14) —
  disclosed in a Verified note rather than rewriting the excerpt.

Edits: 2 anchor fixes (`:179`->`:175`, `org.ex:178-188`->`:175-181`), one dated
"Verified 2026-10-08 (W984ky truth-pass)" block appended before See Also.

### receipted-provider-lifecycle.md

Checked on disk:

- `Xaas.Marketplace.Provider` (`lib/xaas/marketplace/provider.ex`): `:create`
  accepts `[:name, :slug, :description, :org_id]` (`:69`); `status` default
  `:pending` (`:104-107`); `:actuate_status` `public?(false)` +
  `validate(Xaas.Actuation.Validations.ReactorContext)` (`:79-84`) — step-3
  refusal claim holds. Doc's `org_id` create input is in the accept list — OK.
- `Xaas.Actuation.run/4` opts: `:subject_id`, `:idempotency_key` (required,
  `:177`), `:authorize?` (default `true`), `:authority` (default `%{}`) —
  tutorial calls valid.
- `intent.ontology_projection_hash` rides the intent (`actuation.ex:155`) — OK.
- Falsifier `test/xaas/actuation_test.exs` exists on disk — OK.

Edits: no drift found; one dated "Verified 2026-10-08 (W984ky truth-pass)"
section appended. No corrections required.

## Standing

ALIVE (docs-only lane): both tutorial files verified against live code on the
exact working-tree subject; 2 stale line anchors corrected fix-forward; dated
Verified notes landed in both files; this receipt written at
`docs/sjira/v26.10.6/plans/w984ky-probe.md`. No graphql/SpgGate/custom-types
drift surfaced in either tutorial (neither doc references those surfaces).
No commit performed (per lane contract).
