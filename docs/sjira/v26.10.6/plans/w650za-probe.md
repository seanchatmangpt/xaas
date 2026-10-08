# W650za Probe — Incident lifecycle-guard burn-down (census pair pick)

- **Standing**: ALIVE (court subject) · DISPOSITIONED UNSUPPORTED(residual orphan) (second pick)
- **Lane**: W650za, xaas v26.10.6, canonical checkout `/Users/sac/xaas`, branch `feat/playwright-surface`
- **Subjects read at HEAD** `b522fb45` (court authored) / `4d00fdcd` (fresh-root witness run)
- **Written**: `test/xaas/operations/w650za_incident_lifecycle_guard_court_test.exs` + this receipt. No lib/config edits. No commit (lane law).
- **Build root**: `_build-laneW650za` — **deleted** after the fresh-root witness (lane lease law).

## Picks (from w650z8 re-census list /tmp/w650z8_map.txt, 171 rows)

1. **Court subject (best):** `Xaas.Operations.Validations.IncidentResolvedAtRequiresResolved`
   (`lib/xaas/operations/validations/incident_resolved_at_requires_resolved.ex`) — real
   state-bearing lifecycle guard wired on `Xaas.Operations.Incident :update` (W902 batch 3,
   closing W793's `GAP(NO_RESOLVED_AT_GUARD)`); with its complement guard it makes
   `status == :resolved <=> resolved_at != nil` a real invariant of the `:update` surface.
   0 prior test references (fresh grep this lane over `test/`).
2. **Second pick, dispositioned:** `Xaas.ResearchRuntime.CommandBudget`
   (`lib/xaas/research_runtime/intervention/command_budget.ex`, 13 lines) — fresh grep:
   zero references anywhere in `lib/` or `test/` outside its own file. Same residual
   orphan class W650z9 established with `ApprovalCastleVerbScheduleApprove`.

## Coordination (skip list honored)

- `Xaas.Library.ILSRepo.FixtureAdapter` — doctrine exception, skipped.
- `Xaas.Bridges.PPlan.DurableAdapter` — W984dq3 (5/5 depth court), skipped.
- Governance-types slice — W984dr/dr2 (Environment, PentestFindingStatus, thin remainder
  enumerated), skipped.
- `SubscriptionChangeTierNotNoOp` — W984dd's proration depth court already covers the
  same-tier typed refusal at action level (census row is stale); skipped.
- `FreezeWindowActive` and Platform validations — test files with in-flight edits by other
  lanes (`freeze_window_active_gate_test.exs`, `platform_route_deepening_test.exs` both
  modified in the shared working tree), collision-avoided.
- `ProviderWorker`/`ReconciliationLoop` (top census rows) — zero references outside their
  own files (orphan gen_servers, same residual class as pick 2); left for the coordinator's
  orphan sweep rather than double-dispositioned.

## Court (5 tests, Chicago, no mocks)

Real sandboxed Postgres, real `Xaas.Operations.Incident` actions, `authorize?: false`
(action layer is the subject). Typed refusals asserted as-real (exact error field/message
through Ash's real error stack). Per-test mutation rationale in comments:

1. **resolved_at on :open** — typed refusal (field `:resolved_at`, message names
   `status :open` and `:resolved`), and the refused row is unchanged on re-read
   (no partial state). Kills deletion of the validate line and a mutate-to-`:ok`
   of the refusal branch.
2. **Predicate witness `== :open`** — the Incident status enum is exactly
   `[:open, :resolved]` (`lib/xaas/operations/types/incident_status.ex`), so the
   `== :open` vs `!= :resolved` mutation pair is equivalent through the action surface;
   pinned at the predicate on a REAL action-built changeset (direct `validate/3`:
   open+timestamp → `{:error, [field: :resolved_at, ...]}`), plus the `:ok` branch on a
   real resolved-row annotation changeset (data-fallback path). Kills data-fallback drops
   and `== :open` → `true`.
3. **Complement pair** — `status :resolved` without `resolved_at` refused by
   `IncidentResolvedRequiresResolvedAt` (field `:resolved_at`, "is required when marking
   an incident resolved"): deleting either half of the `<=>` pair fails this test.
4. **Real resolve + terminality** — resolve persists to Postgres (re-read), and
   `:resolved` is terminal (`IncidentResolvedIsTerminal` refuses reopen — no stranded
   timestamp). Kills wire-order/attr-drop mutations and terminal-guard deletion.
5. **Postmortem guard (incidental complement coverage, disclosed)** — `:draft` on
   `:open` legal, `:final` on `:open` typed-refused (field `:postmortem_status`),
   `:final` on `:resolved` passes. Kills deletion/broadening of
   `IncidentPostmortemFinalRequiresResolved` and its `final_status/1` fallback.
   This is the sibling guard on the same action, witnessed in the same court —
   `IncidentPostmortemFinalRequiresResolved` therefore moves to ALIVE via this court
   too, beyond the task's nominal 2-module scope.

## Verification (real output)

- Run 1 (FRESH root, full 209-dep recompile): 0/5 — all five failed on one lane test bug
  (`Incident |> Ash.Changeset.for_update(...)` — `for_update` needs the record, not the
  module). Fixed in-lane; no lib edits.
- Run 2 (warm): 3/5 — test 2 assumed a `:incomplete` status (enum is only
  `[:open, :resolved]` — mutation-equivalence finding above) and test 3 asserted the
  complement guard's field as `:status` (it is `:resolved_at`). Both are test-side
  corrections informed by reading the real enum/validation; no lib edits.
- Runs 3–4 (warm): 4/5 then 4/5 — direct `validate/2` call needed arity 3 and the
  forced-`:open` attribute change didn't stick (`force_change_new_attribute` no-op on an
  already-changed attribute); test 2 rewritten to build the changeset with
  `status: :open` directly.
- Run 5 (warm): **5 passed, EXIT=0** — `mix test
  test/xaas/operations/w650za_incident_lifecycle_guard_court_test.exs`,
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650za`.
- **Fresh-root witness ×2**: run 1 was a fresh root; run 6 was a second full
  `rm -rf _build-laneW650za` recompile + rerun — **5 passed, EXIT=0**.
- Lane build root deleted after the witness. Only files written: the test file + this
  receipt.

## Standing

- Court subject `IncidentResolvedAtRequiresResolved`: **ALIVE** on subjects
  `b522fb45`/`4d00fdcd` + lane test file (5/5, two fresh-root executions).
- `IncidentPostmortemFinalRequiresResolved` (+ complements
  `IncidentResolvedRequiresResolvedAt`, `IncidentResolvedIsTerminal` witnessed at action
  level): ALIVE via the same court.
- `Xaas.ResearchRuntime.CommandBudget`: **DISPOSITIONED UNSUPPORTED(residual orphan)** —
  13-line `new/admit` struct, zero consumers in `lib/` or `test/`; no court written (no
  live behavior to witness; same class as W650z9's no-op orphan). If the ResearchRuntime
  intervention wave later wires it, the disposition is void and it returns to the census.
- Census delta: −2 genuinely-uncovered modules from the 171-row list (plus the incidental
  postmortem/complement guards inside the same action surface); the
  `SubscriptionChangeTierNotNoOp` row is stale (already covered by W984dd).
- No typed refusals encountered.
