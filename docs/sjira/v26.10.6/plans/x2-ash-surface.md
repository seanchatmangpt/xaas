# X2 — ash_surface capability surface vs. v26.10.5 fleet wiring needs

Lane: X2 (audit lane, read-only). Subject: `/Users/sac/ash_surface` @ `main` @ `db5a8899e41fd87ef4917d07095677ecb057ed3f`, version `26.10.1` (mix.exs:4). Audit date 2026-10-06.
Companion lanes: X1 (playwright inventory), X3 (xaas web endpoint surface), X4 (version pins), R4/R5 (a2a/pplan wiring plans).

## 1. What ash_surface is (fence)

Manifest-first consumer-projection layer for Ash apps. Lawful pipeline: `Ash.Info.Manifest.generate(otp_app:)` → `AshSurface.from_manifest/2` (`custom.ash_surface` profile + verified contract + content digest) → `AshSurface.Compiler.compile/2` (IR sections per action) → projectors (JS `.mjs` client, LiveView map, ARIA). No second resource model; no TS contract (`no .ts, no tsc, no AshTypescript dep` — README). Boundary invariant: "AshSurface determines nothing about existence, meaning, or DO" (README).

## 2. Capability surface inventory (lib/ash_surface, 7,708 lines across top-level + compiler/projector/projectors/ir/intent/resource)

**Tier 1 — pipeline core (has one real fleet consumer: xaas):**
- `AshSurface` (lib/ash_surface.ex): `from_app/2`, `from_manifest/2`, `Surface` struct (manifest/contract/digest/action_ids), `verify_surface_digest/1`, schema/generator identity `26.10.1`.
- `AshSurface.Compiler` (+ compiler/{capability,ash_truth,semantic,schema,presentation,aria,section}).
- `AshSurface.Projectors.{JS, LiveView, ARIA}` (projectors/{js,live_view,aria}.ex) over `AshSurface.Projector.IR` (projector/{ir,ir_entry,expo,voice_kiosk}.ex).
- `digest.ex`, `resource/validator.ex`, `canonical_json.ex`.

**Tier 2 — MX/agent-facing projections (ADR-0005 targets; no fleet consumer outside ash_surface's own 96-file test suite):**
- `observation.ex` — ObservationProjection(W_t)
- `planning_episode.ex` — PlanningEpisode(π_t)
- `mx_episode.ex` — composed MX closed-loop episode (mx-episode-schema@v26.10.1)
- `event.ex` — realtime server→client event projection
- `transport.ex` — pure pre-dispatch transport selection
- `idempotency.ex`, `intent.ex` + `intent/{dispatch,candidate}.ex` (delegated-DO dispatch boundary)
- `obligation.ex`, `standing.ex`, `health.ex`, `castle_capability_intake.ex`
- `command_center.ex` — DfCM operational command-center projection
- `vocabulary.ex` / `standing.ex` — canonical cross-boundary standing vocabulary

Tier 2 is tested but consumer-less: the v26.10.5 gap is **consumer wiring**, not ash_surface capability.

## 3. Fleet wiring state (evidence: git grep across each repo @ current HEAD)

| repo | HEAD | ash_surface wiring | evidence |
|---|---|---|---|
| xaas | d1db2b03 | **WIRED (only real consumer)** | mix.exs:115 `{:ash_surface, path: "../ash_surface"}`; mix.exs:271 alias `ash_surface: ["xaas.ash_surface"]`; task `lib/mix/tasks/xaas.ash_surface.ex` runs the full Tier-1 pipeline into `priv/ash_surface/` (surface_contract.json, live_view.json, aria.json, `xaas_ash_surface_client.mjs`, runtime .mjs); served statically at `/ash_surface` per mix.exs:267–269 comment |
| ash_a2a | 07180bd3 | **NOT WIRED** | git grep "ash_surface" over lib/config/mix.exs: zero hits (only direction is ash_surface→ash_a2a as hex dep, ash_surface mix.exs:133) |
| ash_pplan | 414a393 | **NOT WIRED (code)** | zero code hits; docs-only mentions in `bench/fleet/FLEET-BASELINE.md` (row: "ash_surface 26.10.1 ok, 1200 tests 0 failures, no bench") and receipts/fleet-wave-* |
| ggen | 000bffb8f | NOT WIRED | zero grep hits |
| ggen_igniter | 7dbcdb3 | NOT WIRED | zero grep hits |
| ggen-mkt | 93895f808 | **PLAN-ONLY** | ADR-0005 (`docs/adr/ADR-0005-ash-surface-mx-consumer-projection.md`, Accepted): XaaS/Ash → AshSurface_MX → ZOELA with observation/planning-episode/MX-receipt/event projections; `packs/experience-projection-pack/ontology.ttl:44` carries "MX CONSUMER SURFACE PROPERTIES (ash_surface v26.9.13 support)" — no pack actually projects surfaces |
| ferroplan | c037876 | NOT WIRED | zero hits (planning-episode projection is its natural consumer edge — PlanningEpisode(π_t) matches ferroplan's strong-cyclic policy output) |
| wasm4pm / beam4pm / gymact / zcode-cli | 32deb59 / 813eb92 / d3eb5e8 / 7fc62da | NOT WIRED | zero hits each |
| zoela | (untracked HEAD) | NOT WIRED | no ash_surface hits in ex/ts/mjs/json (ADR-0005 names it as the intended MX consumer; gap) |
| ash_r2rml | (hex dep) | inverse only | ash_surface consumes it (mix.exs:132); r2rml does not project through ash_surface |

**Conclusion:** 1 of 11 fleet repos consumes ash_surface. Every Tier-2 projection (observation, planning_episode, mx_episode, event, transport, intent dispatch) has zero external consumers.

## 4. Playwright validation edge (lane mission hook)

- ash_surface ships `priv/static/ash_surface_playwright.mjs` + `ash_surface_runtime.mjs`; xaas serves the generated surface statically at `/ash_surface` (mix.exs comment + `priv/ash_surface/` artifacts present, incl. `conference/` and `xaas_ash_surface_client.mjs`).
- xaas lane PW3 already has marketplace-catalog Playwright E2E (xaas commit `d24d48a1`); the ash_surface-generated client surface is the natural next Playwright target — cross-ref lane X1's spec gap plan.

## 5. Untracked _build-* lane leases (inventory only, do not delete)

`/Users/sac/ash_surface` root (du -sh, 2026-10-06):
| dir | size | status |
|---|---|---|
| `_build` | 315M | tracked/existing |
| `_build-fleet-ash_surface` | 153M | untracked |
| `_build-nsprefix` | 312M | untracked |
| `_build-pub` | 312M | untracked |
| `_build-tdb-surface` | 312M | untracked |
| `_build-w16-11` | 312M | untracked |

Total untracked lane leases: ~1.40 GB. Per the 2026-10-01 cleanup law these are leases, not assets — the coordinator deletes at integration. Recorded here so the cleanup is admitted, not ad hoc. Also untracked: `doc/` (ex_doc output). ash_surface working tree otherwise clean (5 untracked entries, no dirty tracked files).

## 6. Gap plan — "every fleet project wired through ash_surface at v26.10.5"

Sequenced by dependency, cheapest falsifier first. Each step names its falsifier.

**G1 — version alignment gate (X4 cross-ref).** Bump ash_surface `26.10.1` → `26.10.5` (mix.exs:4 + lib/ash_surface.ex `@surface_schema_version`/`@generator_identity`), regen fixture digests. Falsifier: `mix test test/ash_surface/version_sync_test.exs` + `digest_parity_fixture_test.exs` green at 26.10.5; R4/R5 plans consume the pinned version.

**G1b — convert xaas path dep to versioned dep (coordinator-only seam).** xaas mix.exs:115 `path: "../ash_surface"` is a lease-shaped dep; v26.10.5 acceptance should pin a hex/git ref. Falsifier: fresh-clone `mix deps.get` + `mix xaas.ash_surface` regenerates byte-identical `priv/ash_surface/` artifacts (digest-verified).

**G2 — ash_a2a wiring (R4 cross-ref).** Natural edge already exists in reverse (ash_surface→ash_a2a hex). Add ash_surface projection of the a2a AgentCard/capability surface: `AshSurface.from_app(:ash_a2a)` task in ash_a2a, artifacts to `priv/surfaces/` (pattern exists: priv/surfaces/tdb_burn_in_manifest.exs). Falsifier: `mix ash_surface.generate` in ash_a2a produces digest-verified surface; a2a action set in contract matches `AshA2A.AgentCard` actions exactly.

**G3 — ash_pplan wiring (R5 cross-ref).** ash_pplan already benchmarks the fleet and names ash_surface 26.10.1 in FLEET-BASELINE. Wire its task surface: pplan's durable task store is the server-side seam for ash_surface's `intent/dispatch.ex` delegated-DO boundary (MX episode dispatch → durable pplan task). Falsifier: an MX episode dispatch with `adapter: :pplan` survives a restart and is wire-visible (mirrors composition C26 in the catalog).

**G4 — ferroplan wiring.** PlanningEpisode(π_t) projection (`lib/ash_surface/planning_episode.ex`) is the exact projection for ferroplan's strong-cyclic policy output. Add a ferroplan mix task producing PlanningEpisode JSON from a generated policy. Falsifier: a generated policy's every action-outcome appears in the projected PlanningEpisode; injecting a missing outcome fails the digest check.

**G5 — ggen-marketplace pack (R2 cross-ref).** ADR-0005 is Accepted but no pack implements it. Create/extend a pack (experience-projection-pack already carries the MX ontology properties) to project fleet surfaces via the ggen pipeline rather than hand-written mix tasks, so the projection is generated, not authored. Falsifier: `ggen sync run` renders a fleet surface matching the xaas mix-task output digest.

**G6 — zoela MX consumer (smallest value-per-cost, largest scope).** ADR-0005's end state: ZOELA = MobileProjection(XaaS/Ash), delete handwritten FOND/HDDL/Zod in zoela. Only after G1–G5 give it a generated contract to consume.

**G7 — wasm4pm/beam4pm/gymact/zcode-cli/ggen/ggen_igniter.** Deferred: these are process/planning/CLI repos — ash_surface is an Ash-consumer-surface layer; wiring them without an Ash domain is forced. Recommend declaring them OUT-OF-SCOPE for "every fleet project wired through ash_surface" with a typed UNSUPPORTED(no-ash-domain) note in the frontier (lane X6), or scope the mission to Ash-domain repos (xaas, ash_a2a, ash_pplan, ferroplan + ash_surface itself).

## 7. Standing

- ash_surface capability surface: PARTIAL_ALIVE — Tier 1 ALIVE (one real consumer, digest-verified pipeline, 96 test files; ash_pplan FLEET-BASELINE witnessed `1200 tests, 0 failures` at 26.10.1), Tier 2 built+tested but consumer-less.
- Fleet wiring at v26.10.5: UNKNOWN until G1–G5 falsifiers run. 1/11 repos wired today.
- Nothing was modified outside the plan file; no git commands ran in ash_surface beyond read-only inspection.
