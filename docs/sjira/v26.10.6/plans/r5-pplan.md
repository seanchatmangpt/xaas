# R5 — ash_pplan fleet-convergence audit (v26.10.6)

Subject: /Users/sac/ash_pplan @ fix/ggen-verify-header 414a393 (1 dirty file, untouched).
Audit date: 2026-10-06. READ-ONLY audit; only this plan file written.

## 1. Standing (real evidence)

- ash_pplan local HEAD = 414a393 "docs(ggen-verify): update stale header for re-homed
  vendor packs"; branch fix/ggen-verify-header, 1 commit ahead of origin/main (5f10c97)
  by docs only. Version declared in mix.exs: `@version "26.10.3"`. **Not yet at
  v26.10.6** — no 26.10.6 tag/CHANGELOG entry exists.
- Dirty file (inventoried, untouched): `docs/demonstration.md` — a regenerated
  demonstration receipt (2026-10-05T07:05:09Z, manifest root tmp/mf-dem-33641, build root
  `_build-laneP4`). Real content change: the full-test-suite row went 7 → 8 failures
  (2309 tests, 76 skipped). HEAD has one net-new test failure vs the last receipted run,
  unadjudicated.
- Durable/pplan durability surface exists at HEAD and is courted in-tree:
  `lib/ash_pplan/a2a/facade.ex` (`AshPPlan.A2A.Facade`: start_or_adopt/attempt/signal/
  status/cancel/fetch, idempotent by run id, consume-once signal resume, nine-status
  machine mapped to A2A task states; lane P4 commit 57d4370, doctested court
  `test/a2a_facade_test.exs`), plus `lib/ash_pplan/providers/{durability,
  durable_dispatch,event_state}.ex` and a deep `test/durable/` suite (engine, cancel,
  await, races, chaos, migrations).
- Consumers observed:
  - **xaas** (`/Users/sac/xaas/mix.exs:251-253`): prod dep, git ref pin
    `b9da1ad7590d70afac5eace3bd7ba1a644f7249f` (26.9.8-era; comment cites v26.9.27).
    Consumed by `lib/xaas/ultracode/recovery_policy.ex` (FOND recovery), frontier_evidence,
    `lib/xaas/bridges/pplan.ex` (SubscriptionRenewal P-PLAN bridge), ultracode wave loop /
    plan_next. mix.lock honors b9da1ad.
    **The "~> 26.10" test consumption is NOT in xaas** — it is
    `/Users/sac/ash_a2a/mix.exs:358`: `{:ash_pplan, "~> 26.10", only: :test}` (lane C26
    pplan adapter). The task prompt's "xaas already consumes ash_pplan ~> 26.10 in test
    for the TaskStore adapter" is a misattribution: that consumption lives in ash_a2a,
    not xaas.
  - **ash_surface**: NO dependency on ash_pplan (0 matches in mix.exs/mix.lock).
    `lib/ash_surface/planning_episode.ex` and `mx_episode.ex` reference ash_pplan only in
    moduledocs as the intended planner/producer ("AshSurface != Planner"). No wiring.
  - **ash_a2a**: `{:ash_pplan, "~> 26.10", only: :test}` (mix.exs:358) — the TaskStore
    adapter consumption (composition C26, standing ALIVE in the catalog).
- `/marketplace-pplan` LiveView (`lib/xaas_web/live/marketplace_pplan_explorer_live.ex`,
  router line 63) is **render-only and unrelated to ash_pplan durability**: it parses
  `priv/gcp/marketplace_lifecycle.ttl` (GCP marketplace p-plan/prov ontology) with
  RDF.Turtle/SPARQL.ex. Name-similarity trap — do not count it as pplan durability
  surface. Courted: `test/xaas_web/live/marketplace_pplan_explorer_live_test.exs`.
- Fleet version skew: ash_pplan declares 26.10.3; xaas pins a 26.9.8-era SHA; ash_surface
  consumes planning episodes via its own projection with no pplan dep at all.

## 2. Gaps to wiring the durability surface through xaas / ash_surface

1. **Pin skew (hard prerequisite)**: xaas prod-pins b9da1ad (26.9.8). The facade
   (`AshPPlan.A2A.Facade`) and durable engine surface consumed by ash_a2a's C26 adapter
   exist only at 26.10.x HEAD. Until xaas's ref moves to a 26.10.x (ideally v26.10.6)
   SHA, no facade wiring is even compilable in xaas. Bumping a prod dep pin in xaas is a
   consequential transition — it must carry its own court run.
2. **No durable TaskStore adapter in xaas**: xaas has zero `AshPPlan.A2A.Facade` call
   sites. Gap = a thin xaas-side adapter binding the facade
   (start_or_adopt/attempt/signal/status/fetch/cancel) to a real store
   (`AshPPlan.Reactor.Durable.Run.store_module/1`), plus a Chicago court asserting
   restart survival: start a run, kill/restart the store, `fetch` still returns the run,
   signal-resume completes it, same-key re-dispatch adopts (run count stays 1 on real
   state).
3. **No ash_surface wiring**: ash_surface consumes planner output only as its own
   PlanningEpisode projection; no dep, no adapter. Gap (optional, lower priority) =
   `only: :test` dep on ash_pplan ~> 26.10 in ash_surface plus a parity court mapping
   facade statuses → `AshSurface.PlanningEpisode` fields with the canonical-digest
   identity law intact. Defer unless a real consumer demand exists (novelty minimal).
4. **Playwright validation**: xaas has prior art (commit d24d48a1 "test(pw3): Playwright
   E2E for the marketplace catalog surface") on the current checked-out branch
   feat/playwright-surface. Gap = a PW spec driving a LiveView that exposes the durable
   run lifecycle (list runs, status, signal-resume). Prerequisite: the adapter from gap 2
   needs a minimal LiveView surface first. Restart-survival is the load-bearing PW
   assertion; render-only is secondary. Do NOT extend /marketplace-pplan — it renders a
   GCP ontology, not the durability surface; a new small LiveView avoids conflating the
   two.
5. **Version convergence (closure only)**: cut ash_pplan v26.10.6 (version bump,
   CHANGELOG, tag) from a green demonstration receipt; the dirty +1-failure
   demonstration.md must be committed/adjudicated first (fix, or typed exclusion with
   reason). xaas's pin then moves to the v26.10.6 SHA; ash_a2a's `~> 26.10` range already
   covers 26.10.6.

## 3. Proposed edits (exact, ordered)

All xaas edits on the canonical checkout, branch feat/playwright-surface (d1db2b03),
after ash_pplan v26.10.6 is cut:

1. ash_pplan (`/Users/sac/ash_pplan`): adjudicate dirty `docs/demonstration.md`
   (net-new 8th failure — fix or typed exclusion), land green, bump `@version
   "26.10.3"` → `"26.10.6"` in mix.exs, CHANGELOG entry, tag v26.10.6.
2. `/Users/sac/xaas/mix.exs:251-253` — replace `ref: "b9da1ad..."` with the v26.10.6
   SHA; `mix deps.update ash_pplan`; commit lockfile with the bump.
3. New `lib/xaas/actuation/pplan_store.ex` — `Xaas.Actuation.PplanStore` adapter over
   `AshPPlan.A2A.Facade` (exact entry points: `start_or_adopt/5`, `attempt/3`,
   `status/3`, `signal/5`, `fetch/2`, `cancel/3`), store via
   `AshPPlan.Reactor.Durable.Run.store_module/1` (file/ETS per config), idempotency key
   = the existing stable `Xaas.Actuation.run/4` key (doubles as facade run key). Run
   lifecycle stays behind the admitted `Xaas.Actuation.run/4` boundary; no public route
   for run-lifecycle mutations (CLAUDE.md actuation floor).
4. `test/xaas/actuation/pplan_store_test.exs` — Chicago court: real store
   (store_module, no mocks), restart-survival (spawn → kill/restart store → fetch
   returns run → signal resume → completed), start-or-adopt idempotency (same key
   re-dispatch adopts; run count asserted on real state).
5. New minimal LiveView `lib/xaas_web/live/durable_runs_live.ex` + route `/durable-runs`
   (router.ex near line 63): list/status from `Xaas.Actuation.PplanStore.status/2`;
   resume posts a signal via the adapter only — no direct engine calls from the web
   layer.
6. `test/xaas_web/live/durable_runs_live_test.exs` — ConnCase court (render + resume
   event against a real store).
7. PW spec following the existing PW3 harness (commit d24d48a1, present on this branch —
   confirm helpers/config exist before spec-writing): navigate /durable-runs, create/seed
   run, assert status renders, restart backend, reload, same status persists,
   signal-resume, assert completed.
8. Regression court for the pin bump (step 2): `test/xaas/ultracode/
   recovery_policy_test.exs`, `test/xaas/frontier_evidence_test.exs`,
   `test/xaas/chicago/bridges/pplan_test.exs`.
9. Optional (ash_surface): `/Users/sac/ash_surface/mix.exs` add
   `{:ash_pplan, "~> 26.10", only: :test}` + parity court
   `test/ash_surface/pplan_episode_parity_test.exs` (facade status → PlanningEpisode
   mapping, digest identity intact). Skip absent real consumer demand.

## 3.5 Order of operations (serialized transitions)

1. ash_pplan: adjudicate dirty demonstration.md, land green (or typed exclusion), bump
   version → 26.10.6, CHANGELOG, tag.
2. xaas: bump pin b9da1ad → v26.10.6 SHA, `mix deps.update ash_pplan`, run the three
   regression courts (step 8), commit.
3. xaas: adapter + store court + LiveView + ConnCase court + PW E2E.
4. ash_surface: optional `only: :test` dep + parity court (skip if no consumer demand).
5. Catalog: composition C26 standing is ALIVE for ash_a2a only; extend its falsifier
   surface to xaas once step 3 lands.

## 3.6 Risks

- **Dirty receipt at ash_pplan HEAD (top blocker)**: the uncommitted demonstration.md
  shows a net-new 8th test failure at HEAD, unadjudicated. Tagging v26.10.6 over this
  mints a release receipt over an ungreen suite. Fix/adjudicate before the tag.
- **Prod-dep pin bump in xaas**: the facade did not exist at b9da1ad, so recovery_policy
  / frontier_evidence / bridges consumers must be re-courted against 26.10.x (possible
  API drift 26.9.8 → 26.10.x). This is a consequential transition with its own court run.
- **Name-similarity trap**: /marketplace-pplan renders a GCP p-plan ontology
  (RDF/SPARQL), unrelated to ash_pplan durability. Extending it would conflate two
  surfaces; the new /durable-runs LiveView is the correct edit.
- **PW harness reuse**: PW3 harness lives on feat/playwright-surface (current xaas
  branch, d1db2b03). Reuse OK, but confirm helpers/config before spec-writing and watch
  merge ordering (no worktrees; canonical checkout only).
- **LiveView auth surface**: /durable-runs must sit behind the same gating pattern as
  sibling internal LiveViews (router.ex:63 pattern); do not open an unauthenticated
  sibling route (CLAUDE.md API-auth floor).
- **Actuation boundary**: run lifecycle mutations stay behind `Xaas.Actuation.run/4`;
  the web/PW surface is read + signal-resume only, never direct engine writes from the
  web layer.
- **Unreleased-SHA risk**: wiring against 414a393 pre-tag means replay identity rests on
  a SHA, not a release; re-pin to the tag once v26.10.6 exists.
- **Chicago discipline**: real store_module, no mocks; restart survival asserted on real
  state, not call counts.

## 4. Falsifier for the whole lane

Restart survival of a durable run through the xaas adapter fails a court, or the xaas
adapter bypasses the facade (direct engine/store writes from xaas code), or v26.10.6 is
tagged over the ungreen demonstration receipt (8 failures).
