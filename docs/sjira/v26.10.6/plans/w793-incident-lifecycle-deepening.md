# W793 — Incident / Route-Castle Lifecycle Deepening (receipt)

- **Lane**: W793, v26.10.6 campaign
- **Subject**: `/Users/sac/xaas` @ `a0723bf6`, branch `feat/playwright-surface` (canonical checkout, no worktree)
- **Standing**: ALIVE (exact subject, observed execution, real sandboxed Postgres, zero mocks — mock grep over the new file: zero matches)
- **Artifacts**:
  - new test file: `test/xaas/operations/incident_lifecycle_deepening_test.exs` (18 tests)
  - receipt: `docs/sjira/v26.10.6/plans/w793-incident-lifecycle-deepening.md`
  - nothing else touched; nothing committed (per lane contract)

## What was docketed and closed

The Operations incident / route-castle lifecycle Ash resources were undocketed
(the semantics-layer `Xaas.Semantics.IncidentReport` is courted separately in
`test/xaas/semantics/incident_report_test.exs`; this lane courts the row-level
lifecycle).

## Court contents (18 tests, all passing)

- **(a) Real lifecycle state machine, per the actual actions**
  - `Xaas.Operations.Incident` action surface asserted exactly `[:create, :read, :update]` — no `:destroy` anywhere.
  - Full happy path: `create(:open)` → `update(:resolved + resolved_at + postmortem :final)`, real row state re-read and asserted.
  - The one real guard holds: `:update` to `:resolved` without `resolved_at` → `Ash.Error.Invalid`, row unchanged on disk.
  - Closed enums (`:incident_severity` / `:incident_status` / `:incident_postmortem_status`) reject out-of-set values at the type layer; no rows written by rejected attempts.
  - **Typed gaps (observed live, not assumed):**
    - `GAP(RESOLVED_AT_GUARD_ONLY_ON_UPDATE)`: `:create` accepts `status: :resolved` with `resolved_at == nil` — the resolved-at invariant is wired only onto `:update` (`Xaas.Operations.Validations.IncidentResolvedRequiresResolvedAt`).
    - `GAP(NO_REOPEN_GUARD)`: `resolved → open` is permitted and retains the stale `resolved_at` (no guard clears it).
    - `GAP(NO_RESOLVED_AT_GUARD)`: `resolved_at` may be set while status stays `:open`.
    - `GAP(NO_POSTMORTEM_STATUS_GUARD)`: postmortem may be `:final` while the incident is still `:open`.
- **(b) Cross-resource integrity**
  - `GAP(NO_CROSS_REFERENCE)`: none of the four route-castle ledgers
    (`RouteCastleDeploy` / `RouteCastleRun` / `RouteCastleSchedule` /
    `RouteCastleSunset`) carries an incident reference or relationship, and
    Incident carries no castle reference — the architecture docs' implied
    incident↔castle link does not exist at the resource layer (typed gap,
    observed via `Ash.Resource.Info.attributes/relationships`).
  - The real cross-resource coupling is Incident ↔
    `Xaas.Governance.Validations.ApprovalDrFailoverRequiresOpenIncident`'s
    region/org/status query: asserted that the real `:update` transition
    `open → resolved` clears the DR-failover precondition, and that
    `GAP(NO_REOPEN_GUARD)` has real cross-resource consequence (reopen
    re-satisfies the precondition). Org-mismatch invariant re-asserted.
- **(c) W747/W745 fabric-court consumption (read-only cross-check)**
  - `RouteCastleRun` is the from-node of the nested-BRCE edge (sequence 50,
    authority `BRCE_ONLY`, `do_boundary?/receipt_before?/receipt_after?/
    replayable?` all true) in `Xaas.Castle.Generated.EdgeCatalog`
    (`lib/xaas/generated/castle_bridge_edges.ex`) — the W745/W77 courts
    drive `Xaas.Actuation.run/4` down this edge.
  - `RouteCastleRun.ontology_projection_hash/0` — stable and non-empty
    (the exact value `Xaas.Castle` admission at `lib/xaas/castle.ex:379`
    verifies the persisted intent against).
  - `RouteCastleRun :execute` is `public?(false)` + `transaction?(true)` —
    not caller-reachable; asserted via `Ash.Resource.Info.action/2`.
  - `Incident` appears in no bridge edge — it sits outside the castle DO boundary.
  - All four route-castle ledgers have `write_actions == []` (no
    create/update/destroy at the Ash layer — they cannot be populated
    through the Ash surface at all; typed gap noted, consistent with
    their generated-projection role).
  - Route-castle reads deterministic across repeated calls.
- **(d) Determinism**: identical payloads project identically (id aside),
  re-read idempotent.

## Commands / exits (real tails)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW793 \
    mix test test/xaas/operations/incident_lifecycle_deepening_test.exs
..................
Finished in 0.8 seconds (0.8s async, 0.00s sync)
Result: 18 passed

$ mix test test/xaas/operations/incident_test.exs   # pre-existing regression
Result: 11 passed
```

Transport failures during the lane (all repaired, none outstanding):
- cold `_build-laneW793` dep compile failed twice on ordering/transient
  write errors (`:sparql` → `:rdf` → transitive `protocol_ex`/`uniq`);
  a full `mix deps.compile` repaired it, exit 0.
- 3 first-run test failures were wrong introspection API names in MY test
  (`execute.public` → `public?`; `Xaas.Generated.CastleBridgeEdges.edges/0`
  → real module `Xaas.Castle.Generated.EdgeCatalog.all/0`); fixed, rerun
  green. No product code touched.

## Standing vocabulary

- **ALIVE**: Incident lifecycle machine (actions, guard, closed enums,
  determinism), DR-failover precondition coupling, `RouteCastleRun` BRCE
  edge + private `:execute`, EdgeCatalog cross-check.
- **GAP(RESOLVED_AT_GUARD_ONLY_ON_UPDATE)**, **GAP(NO_REOPEN_GUARD)**,
  **GAP(NO_RESOLVED_AT_GUARD)**, **GAP(NO_POSTMORTEM_STATUS_GUARD)**,
  **GAP(NO_CROSS_REFERENCE)** — all observed live on the exact subject,
  tested as behavior so any guard added later flips these tests
  (the intended falsifier).

## Cleanup

`_build-laneW793` deletion was attempted and DENIED by the permission
system; left in place as a lease for the coordinator to delete at
integration per the same-checkout fan-out cleanup law.

## Replay

```
cd /Users/sac/xaas && git rev-parse HEAD   # a0723bf6
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW793 \
  mix test test/xaas/operations/incident_lifecycle_deepening_test.exs \
  test/xaas/operations/incident_test.exs
```
