# W981m — Diataxis per-repo document deepening receipt

- Date: 2026-10-07 · Lane W981m · repo `/Users/sac/xaas` @ `feat/playwright-surface`
  (uncommitted; coordinator owns commits).
- Task: fold the session's landed-but-undocumented surfaces into the diataxis reference
  set, each cited to its receipt. No new page: every surface had a home in the existing
  reference set, so the map README index is unchanged.
- Docs-only lane: no code change, no mix command, no commit.

## Pages touched

| page | change |
|---|---|
| `docs/claude/diataxis/reference/actuation-and-semantics.md` | +2 sections: "Graphlaw bridge admission gate (`Xaas.Graphlaw.LimitGate`)" (after the Ferroplan bridge section, same sibling-bridge pattern) and an AIRo fleet-wiring-ledger bullet in the "AIRo mapping" section |
| `docs/claude/diataxis/reference/http-api-surface.md` | 2 edits: the stale "Read-only resources (e.g. `Xaas.Platform.RouteProjects`)" claim corrected (SPEC-21 `:create` + routed `patch(:approve)` + `fc14f10b` SystemActor map completion); a `previous_status` paragraph in the `/internal-api/capability_liveness_receipts` section |

`reference/generated-surfaces.md` read per task; no change — none of the four surfaces is
a generated surface.

## Per-surface citations

1. **`Xaas.Graphlaw.LimitGate` (W976, SPEC-10 / W731-GAP-2)** —
   `docs/claude/diataxis/reference/actuation-and-semantics.md`, section "Graphlaw bridge
   admission gate". Documents `enforce/2` (`{:refused, %{code: :limit_exceeded, ...}}`
   with `refusal_name`/`limit_value`/`actual`), the two wires (`Bridges.Graphlaw.assess/2`
   depth gate on `abi`-scope `max_json_depth`=64; `Registry.engine_limits/0`), the
   W981k byte-limit continuation, and the **fail-open** limit-read semantic (disclosed
   design decision; the `Xaas.Chicago.Bridges.GraphlawTest` dead-host court pins the seam
   DB-independent). Court: `test/xaas/graphlaw_limit_gate_test.exs`. Receipt:
   `docs/sjira/v26.10.6/plans/w976-design-wave5.md`.
   Grounded against source (`lib/xaas/limit_gate.ex` moduledoc + `enforce/2` rescue) —
   note the W976 receipt says fail-open and the on-disk source says fail-open; w969d's
   transient mention of a `fail_closed/2` helper was an in-flight hunk, not the landed
   semantic, and is not documented as such.
2. **SPEC-21 `RouteProjects :create` SystemActor registration (`fc14f10b`)** —
   `docs/claude/diataxis/reference/http-api-surface.md`, platform wired-resources
   paragraph. `create :create` (accept `:requested_by`) with
   `bypass action(:create) { authorize_if({Xaas.Checks.SystemActor, []}) }`; routed
   surface is `patch(:approve)` only; `fc14f10b` added
   `{Xaas.Platform.RouteProjects, :create}` to the SystemActor map (the hunk omitted from
   `b2758300`). Receipts: `docs/sjira/v26.10.6/plans/w969c-design-wave3.md` +
   `docs/sjira/v26.10.6/plans/w969d-spec21-completion.md`.
3. **`capability_liveness_receipt.previous_status` + `SetPreviousStatus` (W978b /
   W968c SPEC-14)** — `docs/claude/diataxis/reference/http-api-surface.md`, liveness
   receipts section. Attribute `capability_liveness_receipt.ex:214`, nullable string,
   public, NOT in the `:ingest` accept list (not caller-forgeable); sole writer
   `lib/xaas/operations/changes/set_previous_status.ex`; migration
   `20261007231000_add_previous_status_to_capability_liveness_receipts.exs`; backs
   in-place regression detection
   (`capability_liveness_regressions.ex:56-60`). Receipt:
   `docs/sjira/v26.10.6/plans/w978b-previous-status.md`.
4. **AIRo wiring ledger extension (25 repos)** —
   `docs/claude/diataxis/reference/actuation-and-semantics.md`, "AIRo mapping" section.
   Ledger `docs/cro/artifacts/airo-wiring-ledger.md`: 16 wave rows + 3 (W981e:
   ash_graphlaw, ggen-ecosystem, chatman-ecosystem) + 6 (W981f: ash_atlassian, ash_dspy,
   ash_kudzu, ash_planning_center, ash_expo, ash_autofde) = 25; every added row UNKNOWN
   with a pin-court falsifier; stubs at `docs/airo/<repo>/airo-reference.md`. Receipts:
   `docs/sjira/v26.10.6/plans/w981e-airo-wiring-extension.md`,
   `docs/sjira/v26.10.6/plans/w981f-airo-wiring-wave2.md`.

## Verification (real output)

- All four receipts re-read from disk this lane (not session memory); all cited source
  line claims re-checked against the live tree (`limit_gate.ex`, `route_projects.ex`,
  `checks/system_actor.ex:75,78`, `capability_liveness_receipt.ex:214`,
  `capability_liveness_regressions.ex:56-60`, `bridges/graphlaw.ex` LimitGate wiring).
- Every added line ≤100 chars (checked via `awk 'length > 101'` over `git diff` — the
  only >100 added line is a pre-existing working-tree edit from another lane, not this
  one).
- Read-only otherwise; no mix commands; no commit (per lane contract).

## Standing

Docs-only lane: standing is the standing of the cited receipts (W976 PARTIAL_ALIVE;
W978b/SPEC-14 ALIVE on `fc14f10b`; SPEC-21 completion ALIVE on `fc14f10b`; W981e/f rows
UNKNOWN by design). This lane adds no code standing of its own.
