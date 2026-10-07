# R6 — ferroplan audit & wiring plan (v26.10.5 fleet wiring fan-out)

Lane: R6. Date: 2026-10-06. READ-ONLY audit of `~/ferroplan` @ `c037876` (main).
Plan file only — no repo edits, no git mutations, no builds.

## 0. Dirty-file inventory (untouched, from `git status --porcelain`)

All 4 dirty files are ggen receipt artifacts — churn from a recent `ggen sync`,
not source changes:

| file | diff |
|---|---|
| `.ggen-v2/receipt-log.jsonl` | +3 lines (new receipt entries) |
| `.ggen-v2/receipt.json` | timestamp/hash bump |
| `crates/ferroplan-wasm/.ggen-v2/receipt-log.jsonl` | +2 lines |
| `crates/ferroplan-wasm/.ggen-v2/receipt.json` | timestamp/hash bump |

Safe to commit as chore at integration, or discard — they regenerate. Coordinator
owns that transition.

## 1. What ferroplan is today (standing: real evidence)

- HEAD `c037876` on `main`, clean except the 4 ggen receipt artifacts above.
- **Planner core**: FF-family classical/numeric/ADL/PDDL3/temporal/FOND planner
  in Rust; embeddable `Session` (ground once / replan many). Scoreboard:
  61% over 32 IPC boards, 687 certified optima (`STANDINGS.md`, generated).
- **Fleet-relevant surfaces, all exercised in-repo**:
  - `crates/ferroplan-wasm` — wasm32 planner: `plan`, `fond_validate`,
    `explain` ops + `WasmSession`. WASI ABI described in RDF
    (`ontology/ferroplan-wasm.ttl`); ggen projects `registry/*` and
    `generated/beam-host/*.ex` (abi.ex, engine_load.ex, host.ex, pool.ex,
    wasm_config.ex) — an Elixir/wasmex host, generated, ready to vendor.
  - `crates/ferroplan-hddl` — HDDL parser/grounder/translator/validator
    (`src/{parser,grounder,translate,validate}.rs`); fixtures at repo root
    `domains/solve_x.hddl` + `domains/solve_x.problem.hddl`.
  - `crates/ferroplan-mcp` — 42-tool MCP server over stdio: solve/parse/
    validate/decompose, full session lifecycle, an admission station
    (`canonical_digest`, `bind_plan_receipt`, `verify_receipt` — BLAKE3
    receipt chain), typed refusals (`FP_*` codes).
  - Live browser pages: `crates/ferroplan-wasm/web/{index,bazaar-live,village-live}.html`
    — a real running planner UI; the natural Playwright target.
- **Cross-repo consumption today: NONE.**
  `Xaas.Bridges.Registry` (`/Users/sac/xaas/lib/xaas/bridges/registry.ex:17-19`)
  lists ferroplan as a truthful absence: "separate sibling repository; xaas has
  no bridge module and no vendored dep at this pin".
  `ash_pplan` has a full FOND layer (`AshPPlan.FOND.*`: policy semantics,
  provider_registry, replay, corpus, subject) but `ProviderRegistry` is a pure
  routing catalog — no real planner engine is registered behind it.
  ash_surface's `AshSurface.PlanningEpisode` carries a `planner_identity`
  string field but nothing binds a real planner identity to it.

## 2. Standing vs mission

Mission: "fleet wired through ~/xaas & ~/ash_surface, Playwright-validated,
v26.10.5 feature complete".

| mission clause | standing |
|---|---|
| wired through ~/xaas | **UNSUPPORTED** — typed absence in registry.ex; no bridge, no vendored host, no dep |
| wired through ~/ash_surface | **UNSUPPORTED** — `planner_identity` field exists, no real planner bound |
| Playwright-validated | **UNSUPPORTED** — ferroplan has live planner web pages but no pw specs; xaas has playwright.config.cjs (testDir `./e2e`, which does not exist) and one spec at `test/bdd/next_read.spec.ts` (outside testDir) |
| v26.10.5 feature complete | **PARTIAL_ALIVE** — ferroplan itself is feature-rich and healthy at this pin; the fleet wiring is the missing feature |

## 3. Gaps

1. **xaas bridge** (`Xaas.Bridges.Ferroplan`): no module, no dep. The ggen-projected
   `generated/beam-host/*.ex` is the lawful seam — vendor into xaas exactly as
   documented in `crates/ferroplan-wasm/README.md` (§ Ontology and generated
   host): vendored host modules + built `.wasm` + pin record, following the
   `Xaas.Bridges.Ex4Pm` prod-git-pinned-sibling convention.
   Blocker: no committed `.wasm` artifact or pin at HEAD (`web/pkg/` is build
   output, `build.sh` is local-only). A pinned artifact publication step
   (ferroplan CI or release) is required before the bridge can be
   VERIFIER_ALIVE at an exact subject.
2. **ash_pplan FOND provider binding**: register a `:ferroplan` provider in the
   runtime `ProviderRegistry` consumer (capabilities `[:fond, :hddl]`, health
   from bridge receipt), whose solve runs the wasm host (or `ferroplan-cli`).
   `AshPPlan.FOND` (fond.ex policy semantics, replay.ex) already consumes this
   shape — this is the FOND/HDDL-through-ash_pplan hop.
3. **ash_surface `PlanningEpisode`**: bind `planner_identity` to a real
   identity from the bridge receipt (`urn:ferroplan:<pin-sha>`) in
   `lib/ash_surface/planning_episode.ex` / `mx_episode.ex`.
4. **Playwright validation**: no spec validates any planner surface. Targets:
   (a) a xaas page/endpoint backed by the new bridge; (b) serve
   `ferroplan-wasm/web/` and spec the live village/bazaar pages (Plan button →
   real plan output). Coordinator seam: xaas playwright testDir `./e2e` does
   not exist while a spec lives in `test/bdd/` — resolve the layout first.
5. **HDDL specifically**: `ferroplan-hddl` is in-repo only; no fleet surface
   consumes it. Options: add HDDL ops to the wasm ontology (regenerate host via
   `ggen sync`), or route HDDL decomposition through ferroplan-mcp `decompose`
   (whether MCP handles HDDL vs only PDDL is UNVERIFIED — see Risks).

## 4. Proposed edits (executor-ready; coordinator owns shared seams)

**Lane R6 lawful scope (ferroplan repo), implement wave only:**

1. `crates/ferroplan-wasm/ontology/ferroplan-wasm.ttl` — add HDDL ops
   (`hddl_parse`, `hddl_decompose`) to the graph; `ggen sync` regenerates
   registry + host; `abi_ontology_drift` test guards the ABI. Never hand-edit
   generated outputs.
2. Pinned artifact publication: commit or CI-publish the built
   `ferroplan_wasm.wasm` + sha256 pin (ggen registry already emits the pin) so
   downstream vendoring is verifiable at an exact subject.

**Coordinator seams (xaas / ash_surface / config):**

3. `xaas/lib/xaas/bridges/registry.ex` — move `:ferroplan` from `@absences` to
   a real bridge entry (`Xaas.Bridges.Ferroplan`, `authority_ceiling: :none`,
   standing from real receipt); flip the absences list in
   `test/xaas/chicago/bridges/registry_test.exs:16` with it.
4. New `Xaas.Bridges.Ferroplan` + vendored `generated/beam-host/*.ex` + pinned
   `.wasm` + pin record (ex4pm vendoring precedent; the ferroplan-wasm README
   documents exactly this consumption path).
5. ash_pplan-side consumer: register `:ferroplan` provider (capabilities
   `[:fond, :hddl]`, health from bridge receipt) in the runtime registry owner.
6. `ash_surface/lib/ash_surface/planning_episode.ex` — `planner_identity`
   bound from bridge receipt identity.
7. Playwright: create xaas `e2e/` (config already points there); specs assert
   real plan output (engine-decided), not DOM-only.

Suggested sequence: artifact pin (1-2) → bridge + registry flip (3-4) →
pplan provider (5) → ash_surface binding (6) → playwright (7).

## 5. Risks

1. **No committed wasm artifact at HEAD** — the #1 wiring blocker; every hop
   downstream of an exact pinned artifact. Mitigate: publish pin first.
2. **wasmex NIF into xaas** — native dep in a repo whose CLAUDE.md warns about
   `_build`/toolchain corruption and prohibits dev compiles during campaign
   (use `MIX_ENV=test` for all verification). Coordinate the mix.exs seam.
3. **Generated-vs-handwritten discipline** — host modules are ggen-generated;
   vendoring must not hand-edit them; any ABI gap → ontology edit + `ggen sync`.
4. **Registry truthfulness floor** — xaas registry must not claim ferroplan
   before a real receipted bridge exists ("No entry claims evidence it does not
   hold"). Bridge + receipt first, registry flip second.
5. **HDDL-through-MCP support is UNVERIFIED** — ferroplan-hddl is a separate
   crate; whether MCP `parse`/`decompose` accept HDDL is UNKNOWN until run.
   Falsifier: push `domains/solve_x.hddl` through the wired surface.

## 6. Falsifiers / acceptance

- Bridge: a mutated PDDL problem flips the outcome through
  `Xaas.Bridges.Ferroplan` (the planner decides, not the bridge) — ex4pm pattern.
- Registry flip: `absences()` no longer lists `:ferroplan` AND a bridge receipt
  exists at the exact pin.
- Playwright: a broken planner (mutated pin) flips the spec red — the spec
  tests the engine, not the DOM.
- HDDL: `domains/solve_x.hddl` parses/decomposes through the wired surface, or
  a typed refusal naming the gap.

## 7. Standing summary

- ferroplan @ `c037876`: repo **ALIVE/PARTIAL_ALIVE** (planner core, ggen-projected
  wasm host, MCP admission station, live web pages, standings infra — all
  exercised in-repo). Fleet wiring standing: **UNSUPPORTED** (typed xaas absence,
  unbound ash_surface planner_identity, zero playwright coverage).
- Dirty files: 4 ggen receipt artifacts — inventory delivered (§0), untouched.
- #1 blocker: no committed pinned `.wasm` artifact; all wiring hops are
  downstream of it.
