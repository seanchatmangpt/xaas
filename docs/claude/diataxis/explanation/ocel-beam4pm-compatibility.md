# OCEL compatibility between xaas and `~/beam4pm`

Verified: 2026-08-30, via `test/xaas/telemetry/ocel_beam4pm_compatibility_test.exs`
(real, executable — not a description).

## What was checked

`~/beam4pm` (a sibling, unpublished BEAM process-mining substrate, version `0.1.0`, no
hex.pm release, no git tags, ~60 commits landed in the last 2 days at time of writing) has
no code-level relationship to xaas today. It appears only as a named aspirational sibling
product in its own `VISION-2030.md`/portfolio-strategy docs.

xaas already emits real OCEL 2.0 events for every real Ash action
(`Xaas.Telemetry.OcelAshEmitter`, `lib/xaas/telemetry/ocel_ash_emitter.ex`), in the
standard JSON-OCEL wire shape (`ocel:eid`, `ocel:activity`, `ocel:timestamp`, `ocel:omap`,
`ocel:vmap`). beam4pm's `BeamPM.Types.OcelEvent` (`lib/beam4pm_types.ex`) is a reduced,
atom-keyed record for the same OCEL 2.0 concept (`:event_id`, `:event_type`, `:event_time`,
`:attributes`). The compatibility question: can a real xaas-emitted event satisfy
beam4pm's real `OcelEvent.new/1` validation without modification to either side?

## Method

The test drives a real Ash action (`Xaas.Operations.CapabilityLivenessReceipt.ingest`),
reads back the real line `OcelAshEmitter` appended to `priv/ocel/ash-actions.ndjson`, maps
its real JSON-OCEL keys onto beam4pm's real atom keys, and calls beam4pm's real
`BeamPM.Types.OcelEvent.new/1` (loaded read-only via `Code.require_file/2` against
`~/beam4pm/lib/beam4pm_types.ex` — no mix dependency added to either repo) with that mapped
map. No struct field, validation branch, or return shape was assumed; all were read from
beam4pm's real source before writing the test.

## Result: compatible, with one named translation gap

**Compatible** — a straightforward key-rename (`ocel:eid` → `:event_id`, `ocel:activity` →
`:event_type`, `ocel:timestamp` → `:event_time`, `ocel:vmap` → `:attributes`) is sufficient;
`BeamPM.Types.OcelEvent.new/1` accepts the mapped xaas event and round-trips every field
exactly.

**Gap** — `ocel:omap` (the JSON-OCEL object-reference list; xaas populates it with the
acting resource's short name) has **no corresponding field** on beam4pm's `OcelEvent`
struct at all. beam4pm instead models object participation as separate records:
`BeamPM.Types.OcelObject` (`:object_id`, `:object_type`, `:attributes`) and
`BeamPM.Types.OcelRelationship` (`:qualifier`, `:object_id`). A real translator from xaas's
OCEL log to beam4pm's record set would need to additionally emit one `OcelRelationship` per
`ocel:omap` entry per event (and a corresponding `OcelObject` the first time each object id
is seen), keyed by a real qualifier — not yet built, named here as the one concrete
remaining gap.

## What this does and doesn't justify

- Does **not** justify adding `beam4pm` as a mix dependency of xaas: it remains unpublished,
  version `0.1.0`, with no hex.pm release or git tag, actively churning (its own dependency
  `ggen_igniter` still has open gaps around `Controller`/`Sync` defaults, `mode: eval`
  compensation coverage, and lock-heartbeat liveness). This repo's established convention
  (see `ash_r2rml`/`ggen_igniter` comments in `mix.exs`) is to depend only on published hex
  releases of sibling repos.
- Does **not** justify adopting beam4pm's `Entitlement`/`Billing`/`ReceiptChain` modules —
  xaas already has its own real, wired, tested Ash-based `Xaas.Billing` domain and
  `Xaas.Actuation` receipt/idempotency control plane (see
  `docs/claude/diataxis/reference/actuation-and-semantics.md`); duplicating those from an
  unpublished library would be pure regression risk with no capability gain.
- **Does** establish, with a real executable check (not an opinion), that xaas's existing
  OCEL emission is shape-compatible with a real downstream process-mining consumer's schema
  today, modulo the one named `ocel:omap` → `OcelObject`/`OcelRelationship` translation gap
  — useful groundwork if/when beam4pm reaches a published, stable state and a real
  process-mining consumer of xaas's OCEL log becomes a live requirement.

## See also

- `lib/xaas/telemetry/ocel_ash_emitter.ex` — the real emitter this check exercises
- `test/xaas/telemetry/ocel_beam4pm_compatibility_test.exs` — the real, re-runnable check
- `test/kanban_web/controllers/ocel_summary_controller_test.exs` — existing real OCEL
  aggregate-endpoint coverage this check builds on the same fixture pattern from
