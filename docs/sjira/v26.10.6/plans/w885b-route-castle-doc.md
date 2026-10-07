# W885b — RouteCastleRun wire-projection doc note

- **Date**: 2026-10-07
- **Lane**: W885b (v26.10.6 campaign; fed by W858 finding F1)
- **Subject**: `docs/claude/diataxis/reference/http-api-surface.md` (uncommitted
  working-tree edit on `feat/playwright-surface` @ a0723bf6; per lane contract, not committed)
- **Standing**: PARTIAL_ALIVE — doc-only lane; no build, no tests run (nothing
  executable changed)

## Change

Added one note block to the Operations section of the HTTP API surface
reference, directly after the Operations base-path table. It states, with
file:line citations:

- `/route_castle_run` exposes read-only JSON:API routes only
  (`get(:read)`/`index(:read)`, `lib/xaas/operations/route_castle_run.ex:42-46`).
- The JSON:API wire projection has an **empty attributes object**: Ash 3
  defaults resource attributes to `public?(false)` and neither `requested_by`
  nor `approved_by` declares `public?(true)`
  (`lib/xaas/operations/route_castle_run.ex:69-77`). Runs are therefore
  wire-identifiable by `id` + `type: "route_castle_run"` only.
- This empty projection is the current contract. If a non-empty public
  projection is ever wanted, the lawful fix is `public?(true)` on the
  attributes plus `mix ash.codegen` — not a hand edit
  (`docs/sjira/v26.10.6/plans/w858-route-castle-surface.md`, finding F1).
- The `:execute` action remains private and unrouted
  (`lib/xaas/operations/route_castle_run.ex:57-66`).

## Verification

- Read `lib/xaas/operations/route_castle_run.ex` in full (78 lines); confirmed
  attributes block (69-77), routes block (42-47), private `:execute` (57-66),
  and absence of any `public?(true)` declaration.
- Confirmed the doc's Operations table already listed `/route_castle_run`
  (line 232 pre-edit); note inserted immediately after the table, before the
  Platform section.
- No mock gate / test run required: no `.ex` file touched, docs-only diff.

## Falsifier

A reader applying the note finds `route_castle_run.ex` declaring
`public?(true)` on an attribute, or non-read JSON:API routes — i.e. the note
drifts from the resource source.
