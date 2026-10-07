# W976 — Design-Wave 5 Receipt

- Lane W976, xaas v26.10.6, repo `/Users/sac/xaas`, branch `feat/playwright-surface`
  (uncommitted; coordinator owns commits per fan-out law).
- Backlog: `docs/sjira/v26.10.6/plans/w905-design-gap-specs.md`.
- Wave receipts checked before spec pick: none of the four wave receipts
  (`w968c`/`w969b`/`w969c`/`w975b`) had landed at lane open; spec pick was made from the
  dirty-tree lane map instead.

## Spec selection (disclosed deviation: only ONE spec, and it is L-estimate)

The task bound this lane to "up to 2 M-estimate specs". Every M-estimate spec in the
W905 backlog was lane-occupied or landed:

| M spec | status at lane open |
|---|---|
| SPEC-04 | `router.ex` + `resolve_org_actor.ex` dirty (lane-occupied) |
| SPEC-07 | `billing/subscription.ex` dirty (lane-occupied) |
| SPEC-14 | `capability_liveness_receipt.ex` dirty (lane-occupied) |
| SPEC-16/17 | landed pre-open (w935 commit `fab56ae1`) |
| SPEC-18 | landed pre-open by W969b (check + wiring + court already on disk) |
| SPEC-20/21 | `route_projects*.ex` dirty (lane-occupied) |
| SPEC-24 | `operations/incident.ex` dirty (lane-occupied) |
| SPEC-26 | library/hold_request/checkout family dirty (banned list) |
| SPEC-27 | `ledger/transfer.ex` dirty (lane-occupied) |
| SPEC-30/31 | `router.ex` dirty; 31 blocked on 30 |

The only lane-free spec remaining in the backlog was **SPEC-10 (W731-GAP-2, EngineLimit
enforcement gate)** — listed **L** in the backlog's estimate summary, not M. Taking it
is the disclosed deviation from the "M-estimate" bound; stop-and-disclose applies. No
second spec was implementable without editing a lane-occupied file.

## SPEC-10 implemented — Xaas.Graphlaw.LimitGate

- `lib/xaas/graphlaw/limit_gate.ex` (NEW): the runtime EngineLimit consumer the W731
  receipt named as absent. `enforce/2` reads `Catalog.limits_by_scope/1` and refuses
  the first measured exceedance with a typed `:limit_exceeded` info map carrying
  `limit` / `limit_value` / `actual` / `refusal_name` / `scope` / `message`.
  `json_depth/1` measures real nesting; `nest/1` builds adversarial payloads.
- Wire 1 — `lib/xaas/bridges/graphlaw.ex`: `assess/2` measures the caller claim's JSON
  depth and gates against the `abi`-scope `max_json_depth` (engine truth: 64,
  `src/abi.rs`) BEFORE engine dispatch; refusal carries the engine's `refusal_name`
  (e.g. `state_quads`), `class: :refused_admission`, `broken_term: :mu_on_O`.
- Wire 2 — `lib/xaas/bridges/registry.ex`: new `Registry.engine_limits/0` reads real
  `EngineLimit` rows (abi scope) — the registry now reads EngineLimit, which no
  registry function did before.
- Migration: none (per spec; rows already exist via `Catalog.ingest/1`).

## Court

`test/xaas/graphlaw_limit_gate_test.exs` (NEW, 13 tests, Chicago — real Postgres rows,
real `Catalog.ingest/1` against the real graphlaw registry, real bridge calls; zero
mocks):

- the receipt falsifier verbatim: depth-65 measured against `max_json_depth=64`
  refuses typed, naming `refusal_name`; equal/below admits; no recorded limit admits.
- bridge seam: depth-65 claim refused at `Bridges.Graphlaw.assess/2` before the engine
  (dead-server probe proves the engine was never reached); depth-64 within-limit claim
  passes through to engine dispatch (dead server yields `:host_not_started`, the only
  refusal available past the gate).
- registry seam: `Registry.engine_limits/0` returns real rows; real registry ingest
  feeds both seams.
- Mutation rationale (in the court's moduledoc): reverting the `LimitGate.enforce/2`
  wiring in `assess/2` flips the depth-65 refusal court RED; deleting
  `Registry.engine_limits/0` flips the registry seam court RED. The fail-open rescue
  (unreadable limit store admits) is disclosed as accepted residual — not killable by
  a green-path court without inducing a read failure.

## Design decision disclosed: fail-open on limit-read error

The W905 spec's fail-closed suggestion was NOT taken at this seam: the landed
`Xaas.Chicago.Bridges.GraphlawTest` dead-host court pins the bridge as DB-independent
(its refusal is `:host_not_started`, never a DB verdict). An unreadable limit store now
admits (monitored gap, not a refusal condition); a live exceedance still refuses. This
flipped 3 pre-existing bridge-court tests back to green after the first run and is the
load-bearing semantic choice of this lane.

## Verification (real output)

- `mix compile` under `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW976`: green (two earlier
  runs failed inside OTHER lanes' in-flight files — `billing/subscription.ex`, then
  `platform/webhook.ex` mid-write; both self-resolved on disk as those lanes
  progressed. Pre-existing/concurrent, not introduced here.)
- Target suites green x2 (run 1 and run 2 identical):
  `mix test test/xaas/graphlaw_limit_gate_test.exs test/xaas/chicago/bridges/graphlaw_test.exs test/xaas/graphlaw_deepening_test.exs test/xaas/graphlaw/catalog_test.exs`
  → **40 passed, 0 failures**, twice.
- Broader blast radius: `mix test test/xaas/chicago/bridges/` → **32 passed**.
- No commit made (per lane contract).

## Standing

- SPEC-10 (W731-GAP-2): **PARTIAL_ALIVE** — gate + two named seams wired and
  court-proven on real rows/registry/bridge; remaining gap to ALIVE: the `abi` scope
  covers `max_json_depth`; other registry limits (15 rows at ingest) are recorded and
  gateable via the same `enforce/2` but not yet measured at any consumer seam.
- Wave-5 as a whole: PARTIAL_ALIVE at 1 of 2 specs — second slot unfilled because
  every M-estimate spec was lane-occupied or landed (table above), a disclosed
  deviation, not a silent shortfall.

## Cleanup

`_build-laneW976/` deleted after verification (lane-lease law).
