# W945c — Batch 5 Repairs (typed-gap register, 3 rows)

Lane W945c, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface`,
HEAD `fab56ae1`. No commit; write-only repair sites + test extensions + this
receipt; `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW945c` (deleted at end of
lane — see Lane lease).

## Row selection

Source triage: `w891-gap-triage.md` (15 CHEAP-REPAIR rows). Batches 1-4 had
landed w897 (rows 1/5/11 + stale-row handling), w900, w902, and — mid-flight
for this lane — w945b (rows 2/28/35; its receipt appeared in the register
while this lane ran). Non-overlapping remaining CHEAP rows picked:

- **Row 12** — W745 rescue-arm (real repair: test-only court).
- **Row 4 split-half** — W722 gap-1 approval state guard (witnessed flip).
- **Row 13** — W750-G1 liveness ingest gate (witnessed flip).

Dropped/avoided, with reasons:

- **Row 35 (W849 backlog-3, McpScope moduledoc)** — initially picked, dropped
  before landing: `lib/xaas_web/mcp_scope.ex` is a generated surface,
  sha256-pinned in `w852-provenance-pins.md`'s drift guard, and the regen
  template + pack convention live in `~/ggen_igniter` (sibling repo) — the
  normalization is a generator-side change, not a one-lane edit. Stop-and-
  disclose per house discipline. Landed concurrently by w945b (no overlap;
  its receipt's register entry appeared during this lane's court runs).
- **Row 2 (W674-GAP-1)**, **row 28 (W799)** — w945b's rows; also avoided
  because their shared test file (`gymact_surface_deepening_test.exs`) is
  modified on tree by another lane.
- **Row 3 (W674-GAP-2)** — W674's lane staged the fix (register notes it).
- **Row 11-adjacent W731/W729 surfaces** — `lib/xaas/billing/subscription.ex`,
  `lib/xaas/graphlaw/{capability,catalog}.ex` modified on tree by other lanes.

## Row 1 — W745 rescue-arm (-32603) — REPAIRED

- **Gap** (w745-execution-fabric-deepening.md): the fail-closed `rescue` arm
  on `XaasWeb.ExecutionFabricController.mcp/1` was documented but never
  exercised by a real raise; w745 disclosed "no honest in-process way without
  mocking".
- **Repair** (test-only, real wire path, Chicago-clean): new court **c.5** in
  `test/xaas_web/execution_fabric_deepening_test.exs` — POST
  `tools/call` `claim_next` with non-accessible `arguments` (integer 42) →
  real `FunctionClauseError` at `args["provider"]` Access get on the real
  dispatch path (no rescue inside `dispatch_tool`) → propagates to the
  controller's fail-closed arm → exact -32603 JSON-RPC envelope
  (`code -32603`, `id nil`, `data: "FunctionClauseError"`), HTTP 500.
  Moduledoc courts list updated with (f).
- **Court**: `mix test test/xaas_web/execution_fabric_deepening_test.exs` —
  16 passed ×2 (first run under `--trace` confirmed the real raise was
  observed: `XAAS_EXECUTION_MCP_CRASH class=FunctionClauseError`).
- **Mutation rationale**: rescue-arm error code flipped `-32_603` → `-32_604`
  in the controller → 15/16, only c.5 fails on the code mismatch → restored
  byte-identical via `git checkout --`. (Deleting the rescue arm entirely
  also kills: the test crashes with the raw raise.)

## Row 2 — W722 gap-1 (approval state guard) — REPAIRED (witnessed flip)

- **Gap** (w722-governance-deepening.md gap 1): no double-approve state guard
  on the 4 governance Approval* resources.
- **Finding**: the repair is already on HEAD — W740's
  `Xaas.Governance.Validations.ApprovalNotAlreadyApproved` is wired on all 4
  Approval* `:approve` actions (`approval_dr_failover.ex:119`,
  `approval_legal_hold_release.ex`, `approval_deployment_quarantine.ex`,
  `approval_backup_retention_change.ex`), and the deepening test now pins
  refusal. The register row was stale (same class as w897's rows 6/13).
- **Court**: `mix test test/xaas/governance/multitenant_approval_deepening_test.exs`
  — 10 passed ×2.
- **Mutation rationale**: unwired the validation on `ApprovalDrFailover`
  (`validate(...)` → comment) → 9/10, the double-approve court fails with
  `approved_by` overwritten to `approver-2` → restored byte-identical.
- **Register hygiene**: row split — gap-1 flipped REPAIRED; gap-2
  (`X-Org-Id` caller-asserted, not authenticated) re-registered as its own
  OPEN row so the combined row doesn't mask the honest open limitation.

## Row 3 — W750-G1 (ALIVE-requires-execution gate) — REPAIRED (witnessed flip)

- **Gap** (w750-liveness-deepening.md G1): ALIVE + `executed: false` ingest
  accepted.
- **Finding**: repair already on HEAD — W768's
  `Xaas.Operations.Validations.CapabilityLivenessReceiptStatusGate` wired at
  `lib/xaas/operations/capability_liveness_receipt.ex:179`; the deepening
  test pins `ALIVE_WITHOUT_EXECUTION` refusal. Register row stale (w897 had
  noted this; nobody had flipped it).
- **Court**: `mix test test/xaas/operations/capability_liveness_deepening_test.exs
  test/xaas/operations/capability_liveness_receipt_test.exs` — 17 passed ×2.
  Combined final runs: 43/43 ×2 across all three repaired surfaces' suites.
  (One intermediate run was 7/9 with the gate mutated out — that IS the
  mutation evidence, listed below.)
- **Mutation rationale**: gate line replaced with a comment → 7/9, the
  `assert_raise Ash.Error.Invalid, ~r/ALIVE_WITHOUT_EXECUTION/` court fails
  → restored byte-identical.
- **Not claimed**: G2 (detect/1 upsert-overwrite blindness) and no-TTL stay
  OPEN — W891 classifies them DESIGN; untouched.

## Verification ladder

narrow (per-suite real runs, ×2 green after restore):
`execution_fabric_deepening` 16/16 ×2; `capability_liveness_deepening` +
`capability_liveness_receipt` 17/17 ×2; `multitenant_approval_deepening`
10/10 ×2; final combined 43/43 ×2 (seed-varied, max_cases 32). All under
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW945c`.
Pre-existing environment noise (not lane-introduced): PromEx/Grafana nxdomain
upload warnings, ash_affidavit warnings, os_mon shutdown notices.

## Register update

`w859-typed-gap-register.md`: W745, W750-G1, W722-gap-1 → REPAIRED; new
W722-gap-2 OPEN row; totals 50 rows = 25 OPEN + 23 REPAIRED + 2 TYPED-OPEN;
W945c update note appended. Register file was concurrently modified by other
lanes mid-flight (w945b/w950 entries observed); my edits are additive edits
to my rows and totals only.

## Files touched

- `test/xaas_web/execution_fabric_deepening_test.exs` (court c.5 + moduledoc (f))
- `docs/sjira/v26.10.6/lib` surfaces: none (both flips were already-landed
  repairs; the only lib edits were the three mutation probes, each restored
  byte-identical via `git checkout --`, verified empty `git diff --stat`)
- `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md` (3 flips + split + totals)
- `docs/sjira/v26.10.6/plans/w945c-batch5-repairs.md` (this receipt)

## Standing

- W745 rescue-arm contract: **ALIVE** (real raise witnessed on the exact
  subject, mutation-killed court, ×2 determinism).
- W722 gap-1 state guard, W750-G1 ingest gate: **ALIVE** (repairs on HEAD
  witnessed with killing mutations; the repairs themselves remain attributed
  to W740/W768).
- Register: 50 rows = 25 OPEN + 23 REPAIRED + 2 TYPED-OPEN.

## Falsifiers

- `mix test test/xaas_web/execution_fabric_deepening_test.exs`
- `mix test test/xaas/operations/capability_liveness_deepening_test.exs test/xaas/operations/capability_liveness_receipt_test.exs`
- `mix test test/xaas/governance/multitenant_approval_deepening_test.exs`

## Lane lease

`_build-laneW945c` deletion attempted and denied by the permission system
(same as lanes W745/W750 before this one) — **left for coordinator** per the
fanout cleanup law. No commit made, per dispatch.
