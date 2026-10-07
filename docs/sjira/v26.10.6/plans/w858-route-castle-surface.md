# W858 — RouteCastleRun read-only surface court

- **Lane**: W858, xaas v26.10.6 campaign, canonical checkout `/Users/sac/xaas`,
  branch `feat/playwright-surface`, HEAD `a0723bf6`.
- **Subject**: `test/xaas/operations/route_castle_run_surface_test.exs`
  (new, sole written file; 10 tests).
- **Standing**: ALIVE (10/10 real passes on the exact subject, run twice;
  second run byte-stable).
- **Command** (real, both runs):
  ```
  PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW858 \
    mix test test/xaas/operations/route_castle_run_surface_test.exs
  ```
- **Real tails**:
  ```
  Finished in 0.6 seconds (0.00s async, 0.6s sync)
  Result: 10 passed
  ```
  (second run: `Finished in 1.2 seconds ... Result: 10 passed`)
- **Mock gate** (real): `scan_mock_usage` on the new file → `[]`.

## What the court pins (real ConnCase HTTP, real sandboxed Postgres, zero mocks)

- (a) `GET /api/route_castle_run` (index) and
  `GET /api/route_castle_run/:id` return 200 with a real sandboxed row and
  the REAL public field set — which is **empty attributes**
  (`%{}`), not the moduledoc-implied `requested_by`/`approved_by`.
  Rows are manufactured at the repo layer (`Repo.insert_all` with returning)
  because the resource declares no create action. `Ash.get!` from the wire
  id proves the same row: `requested_by`/`approved_by` are real and readable
  at the resource layer; unknown id → real AshJsonApi 404.
- (b) read-only doctrine over the real wire: `POST /api/route_castle_run/:id/execute`
  (execute-shaped), `POST /api/route_castle_run` (create-shaped), and
  `PATCH /api/route_castle_run/:id` (update-shaped) each answer the real
  AshJsonApi 404 document — exactly
  `code "no_route_found"`, `detail "no route found"`, `title "NoRouteFound"`,
  `status "404"`, `meta {}`, per-response uuid `id`, `jsonapi 1.0`. There is
  no routed web path that can execute or mutate a run. GraphQL is
  unreachable by content negotiation: any non-json-api Accept on /api raises
  `Phoenix.NotAcceptableError` (`Expected one of ["json-api"]`) before route
  evaluation — pinned via `assert_raise`, so no mutation document is even
  constructible on this scope.
- (c) fabric-consumption cross-check at the resource level (the W745
  consumption entry `Xaas.Actuation.prepare_external/4`, exactly what
  `Xaas.Castle.run/2` calls): consuming a run writes real durable
  `Xaas.Operations.ActuationIntent` + `ActuationReceipt` rows read back from
  the real tables — `status :prepared`, `resource_module ==
  "Xaas.Operations.RouteCastleRun"`, `action == "execute"` — while the run
  row itself re-reads byte-unchanged on the wire (`attributes == %{}`) and
  at the resource layer. NOTE: RouteCastleRun carries **no status column**;
  the fabric's real status lives on the receipt, not the run — asserted
  there.
- (d) determinism x2: index read replays byte-identical; the 404 refusal
  replays identical after excluding the per-response error `id` uuid (the
  only nondeterministic member, itself asserted uuid-shaped).

## Findings (typed)

- **F1 — PRIVATE_COLUMNS_EMPTY_WIRE_PROJECTION** (real, pinned): both
  `requested_by`/`approved_by` are declared without `public? true` (Ash 3
  default private), so the JSON:API surface serves rows whose attributes
  object is empty. A run is wire-identifiable by `id`+`type` only; the
  columns remain readable at the resource layer. If the intended projection
  is non-empty, the lawful fix is `public? true` on the two attributes in
  `lib/xaas/operations/route_castle_run.ex` + `mix ash.codegen` — not a
  test-side change. Test pins current reality and documents the gap.
- **F2 — 404 ERROR ID NONDETERMINISM** (informational): AshJsonApi's
  `no_route_found` error carries a fresh uuid per response, so byte-level
  determinism on that body is unattainable modulo `id`. Documented in the
  (d) assertion.
- **F3 — NO RUN-LEVEL STATUS** (design note): a run has no status of its
  own; fabric status is receipt-borne (`ActuationReceipt.status`), so the
  (c) cross-check asserts from the receipt + unchanged run row, as read
  directly from the resource/tables.

## Env / cleanup discipline

- `INTERNAL_API_TOKEN` untouched (test_helper provides it); no application
  env mutated; no commits. `_build-laneW858` left in place for coordinator
  removal (rm denied by the permission system this session).

## Standing

- Court: **ALIVE** — 10/10 real passes ×2 runs on
  `feat/playwright-surface@a0723bf6`.
- Resource projection currency: **PARTIAL_ALIVE** pending F1 decision
  (private-columns public projection is an open product decision, not a
  test defect).
