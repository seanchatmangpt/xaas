# W321 — Structural Unreachability Re-Verification (DoD 3)

Lane W321, 2026-10-06. Re-verification of `_CLOSURE_PLAN.md` §2
"structurally-unreachable / intentionally-unfixed refusal shapes" against the
current tree @ `feat/playwright-surface`. Read-only re-verify; no code changed.

## Receipt table

| # | Cited site | Plan claim | Verdict | Evidence (current tree) |
|---|---|---|---|---|
| 1 | `castle.ex:941` `BLOCKED_CASTLE_TRANSPORT` | "raw stringified exception message"; structurally unreachable until typed | **REFUTED (as stated)** | Atom is now emitted as a **typed tuple** at `lib/xaas/castle.ex:950`: `{:error, {:BLOCKED_CASTLE_TRANSPORT, %{exception: inspect(error.__struct__), message: Exception.message(error), executable: bin}}}`. Not a raw string; the untyped residue is the embedded `message` string only. AND it is **already fixture'd**: `test/xaas/castle_refusal_negative_batch4_test.exs:94-113` asserts the full tuple shape (w67 batch 44/44 green, per plan's own §1 table line 69 which counts it as covered). The §2 entry contradicts §1's coverage table. |
| 2 | `actuation.ex:383` untyped rescue → `{:exception, struct, string}` | untyped rescue; fixture pins shape only | **CONFIRMED (line moved 383→388)** | `lib/xaas/actuation.ex:382` `rescue` → `:388` `{:exception, error.__struct__, %{module: inspect(...), message: Exception.message(error), readable?...}}`. Fixture: `test/xaas/actuation_test.exs:182-196` pins tuple shape only; `message` remains a non-enumerable string. Reason holds, line stale. |
| 3a | `stop_court.ex:1956` | bare-string refusal, typed-refactor-only | **CONFIRMED** | `lib/mix/tasks/xaas.stop_court.ex:1955-1957` `{:error, "#{path}: an OCEL event or object lacks a string id/type…"}` — bare string, no `REFUSED_*` variant. |
| 3b | `eds/falsifier.ex:84` | bare-string refusal | **CONFIRMED** | `lib/xaas/eds/falsifier.ex:84-85` `{:error, "falsifier predicate returned #{inspect(other)}…"}` (a second bare string at `:54-55`, "falsifier explicitly marked vacuous"). |
| 3c | `a2a/zoe_event_simulation_agent.ex:58` | bare-string refusal | **STALE (line moved)** | Bare strings now at `lib/xaas_web/a2a/zoe_event_simulation_agent.ex:65` and `:68` (`{:error, "simulation refused: …"}`); cited line 58 is now a **typed** refusal map (`refusal: :invalid_simulation_json`). |
| 3d | `a2a/next_read_user_agent.ex:159` | bare-string refusal | **STALE (line moved)** | Bare strings now at `lib/xaas_web/a2a/next_read_user_agent.ex:211` and `:214` (`{:error, "checkout failed/halted: …"}`); cited line 159 is a typed `%{refusal: :browse_failed, …}`. |
| 3e | `health_controller.ex:96` | bare-string refusal | **STALE (line moved)** | Bare strings at `lib/xaas_web/controllers/health_controller.ex:113` (catch arm `"#{kind}: #{inspect(reason)}"`) and `:148` (`"unexpected status #{status}"`); cited 96 is blank/`defp domain_checks`. |
| 3f | `capability_coverage.ex:59` | bare-string refusal | **REFUTED** | `lib/mix/tasks/xaas.capability_coverage.ex:59` is `Mix.shell().info("")` — a report printer. The file contains **zero** refusal shapes (no `REFUSED` token, no `{:error, "…"}` string refusal anywhere in the file). Nothing to fixture. |
| 3g | `marketplace_catalog_live.ex:71,74` | bare-string refusal | **STALE (lines are now comments; shape partially typed)** | Refusal maps at `lib/xaas_web/live/marketplace_catalog_live.ex:79-91` are typed `%{refusal: :catalog_ingest, reason, detail}`; the `rescue` arm (`:87-91`) embeds `Exception.message(error)` as `detail` — residual untyped string, but a typed atom key exists, so not "bare-string". Machine-readable via `data-refusal`/`data-reason` attributes. |
| 4 | ash_surface `projectors/js.ex:497` untyped throws | untyped string throws, not fixture-able | **CONFIRMED (line moved 497→494/501)** | `/Users/sac/ash_surface/lib/ash_surface/projectors/js.ex:494` (`throw new Error("REFUSED_UNKNOWN_ACTION: " + id)`) and `:501` (`REFUSED_NOT_DO_BOUNDARY`). Still raw JS `Error` throws (structured `refusal`/`standing` properties attached, but throw-path, not a typed tuple / typed JS symbol). Read-only confirmed in /Users/sac/ash_surface. |
| 5 | 13 Mix-task bare `"REFUSED"` stdout strings (vector2 §E) | 13 tasks | **STALE (count changed: 12 files / 21 refusal sites; composition changed)** | Of vector2's named 13, 9 retain bare strings — `stop_court` (4), `successor` (4), `episode` (3), `fabric.redeploy` (1), `release_audit` (1), `autonomic.controls` (1), `sjira.engineer_work` (1), `safe_generate_migrations` (1), `release_snapshot.verify` (2) = 19 sites / 9 files. 4 named tasks are now clean: `machine_experience`, `replay`, `sjira.ard_court`, `telemetry.check_ontology_staleness` (remaining tokens are doc comments only). 3 files NOT in the vector2 list now carry bare strings: `xaas.self_digest.ex` (1), `xaas.ash_surface.ex` (1), and `xaas.run_validate.ex:83` (1 — a stdout *renderer* of a typed code, `"REFUSED(#{code}, detail: #{inspect(detail)})"`, not itself a refusal shape). Excluding the run_validate renderer: **12 files / 21 genuine bare-string refusal sites**, not 13 tasks. |
| 6 | r2rml `:REFUSED_UNKNOWN_ATTRIBUTE` structural unreachability (w185 call-graph claim) | `is_nil(attribute)` cannot hold through any public entry | **CONFIRMED** | Refusal site `lib/xaas/semantics/r2rml.ex:209-215`. Sole caller `predicate_object_maps/2` is called only at `:41` inside `mapping/1`, fed `projection.attributes` from `OntologyRegistry.admit(resource)` (`:38`). `Xaas.Semantics.Registry.projection/1` (`lib/xaas/semantics/registry.ex:113-123`) derives `ash_name` **directly from `Ash.Resource.Info.attributes(resource)`** — the identical call the lookup at `r2rml.ex:206` (`Ash.Resource.Info.attribute(resource, projected.ash_name)`) uses on the same module within one schedule. `admit/1` (registry.ex:151) only filters non-public IRIs and returns `{:error, …}` before `predicate_object_maps` runs. No other caller exists (grep: def at 204, single call site 41). Therefore `is_nil(attribute)` cannot hold through any public entry (`mapping/1`, `bundle/1`, `render/1`); the only residual would be a module recompile between the two calls inside one process, which the `rescue` at `r2rml.ex:72-81` converts to `REFUSED_UNPROVEN_EQUIVALENCE`, not `REFUSED_UNKNOWN_ATTRIBUTE`. w185 call-graph claim stands. |

## Counts

- CONFIRMED: 4 — actuation rescue (reason; line moved), stop_court bare string,
  eds/falsifier bare string, r2rml UNKNOWN_ATTRIBUTE unreachability (w185).
- STALE (line/count moved, substance holds): 5 — zoe (58→65,68),
  next_read_user_agent (159→211,214), health_controller (96→113,148),
  marketplace_catalog_live (71,74→79-91, partially typed), ash_surface js.ex
  (497→494,501), Mix-task count (13→12 files / 21 sites, composition changed).
- REFUTED: 2 — castle.ex BLOCKED_CASTLE_TRANSPORT ("raw string" claim false:
  typed tuple since the batch4 fixture; already covered per §1 table), and
  capability_coverage.ex:59 (no refusal shape exists in the file at all).

## Required plan corrections

1. §2 entry 1 (castle) should be deleted: the shape is a typed tuple, is
   fixture'd (w67 batch4), and §1 already counts it covered — internal
   contradiction in the plan.
2. §2 entry capability_coverage.ex:59 should be deleted: no refusal shape.
3. Line numbers for zoe / next_read_user_agent / health_controller /
   marketplace_catalog_live / actuation / ash_surface js.ex should be updated
   per the table above.
4. §2 Mix-task count "13 tasks" → "12 files / 21 bare-string refusal sites"
   (machine_experience, replay, sjira.ard_court, telemetry.check_ontology_staleness
   are clean; self_digest, ash_surface, run_validate:83 are the new carriers).
