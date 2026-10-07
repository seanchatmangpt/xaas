# v26.10.6 Frontier (relabeled from v26.10.5 — version correction) — Acceptance Definition

Milestone: **fleet wired through `~/xaas` & `~/ash_surface`, playwright-validated,
v26.10.5 feature complete.**

Lane map: superseded (v26.10.5 `_LANES.md` retired; this campaign's lane
ownership lives in `_INDEX.md` + the w3xx receipts). Integration base:
`feat/playwright-surface` @ `d1db2b03` (xaas).

## Standing vocabulary

`UNKNOWN | PARTIAL_ALIVE | ALIVE | BLOCKED | BUILD_BROKEN | UNSUPPORTED` per
operating doctrine. ALIVE requires observed execution on the exact admitted subject
with a receipt — not plan, inspection, CI presence, or assumption. **Every row below
starts UNKNOWN.** Standings are filled ONLY from lane receipts (lane plan + executed
verification output filed under `docs/sjira/v26.10.5/plans/`). A coordinator must not
edit a standing without a receipt path in the row.

## Definition of done (milestone)

v26.10.5 is feature complete when ALL of the following hold:

1. Every repo row below has standing ≠ UNKNOWN, backed by a receipt.
2. Every ALIVE row has: compile pass, test pass, and — where a UI surface exists —
   a passing Playwright E2E run against the wired surface.
3. Every repo is wired through xaas and/or `~/ash_surface` per its acceptance
   section, or carries an explicit typed `REFUSED`/`BLOCKED` with reason.
4. No standing is asserted without an executed command's real output.

## Verification ladder (per repo)

Cheapest high-info first; each rung's real output goes in the lane receipt.

1. **Compile** — repo's native build command succeeds (mix/build/tsc/cargo per repo).
2. **Test** — native test suite passes (disclosed failures allowed per repo operating
   mode, but disclosed ≠ hidden).
3. **Wiring check** — the repo's surface is reachable through xaas/ash_surface
   (route, pack, dependency edge, or actuation path per acceptance section).
4. **Playwright E2E** — where a UI surface exists: real browser run against the
   wired surface, asserting final rendered state (not interaction counts).

Rung 4 is required for: xaas web surfaces (LiveView/HTTP), ash_surface-generated
surfaces, and any repo surface exposed through them. Repos with no UI surface
(CLI/library/planner repos) terminate at rung 3 with a receipt stating why.

**Scope correction (X7 red team, S0-R1, 2026-10-06 — receipt
`x7-risk-register.md`)**: only `~/xaas` has a `playwright.config.cjs` or `e2e/`
surface. The playwright rung applies ONLY to browser-surface repos (xaas served
surfaces and ash_surface-generated surfaces exposed through them). CLI/library/
planner repos (ggen, ggen_igniter, zcode-cli, wasm4pm, beam4pm, ferroplan,
gymact, ash_pplan, ggen-marketplace) terminate at wiring + typed receipt
("playwright-validated fleet-wide" is unfalsifiable for 12 of 13 repos as
originally worded).

## Per-repo acceptance criteria

### xaas (integration root)

- `mix compile` and `mix test` run under the pinned asdf toolchain; real output
  filed.
- Playwright E2E suite green against the marketplace catalog surface and the
  witness/certified-receipt surface (`test/pw3`, `test/pw*` — exact set from X1's
  inventory).
- All lane seams (router, mix.exs, config) integrated by coordinator; final commit
  contains no leftover lane build roots (`_build-lane*`).
- Acceptance: an end-to-end Playwright run exercises each wired fleet surface
  through the running `mix phx.server`.
- **Receipt update (x1, x1b, x3, x5, x8, vector1–6, x7; 2026-10-06)**:
  x8 — full-app ash-surface generation works on this exact tree (`d1db2b03`):
  committed artifacts verified on disk, `node --check` OK,
  `surface_contract.json` 410 actions, EA34 prod-compile gate exit 0 (per
  commit), CommandCenterAdapter court 9 passed / 0 failed (real run).
  vector5 — compiler/lint under strict flags VERIFIED GREEN; vector1–3, vector6 —
  audits (fenced-gate inventory, refusal-coverage gaps, ignored suites, docs/ABI
  drift: ash_surface corpus NO DRIFT). x1/x1b — gap specs written; a full
  `npx playwright test` green run is still NOT witnessed on this branch (x1b
  ESM/CJS blocker runbook on file). Lane-executed, integration run pending.

### ash_surface (`~/ash_surface`)

- Compiles; its full-app generation path works (EA35 namespace plumbing verified by
  real generation, not inspection).
- Every fleet surface it generates is regenerable from its source of truth;
  generated output not hand-edited.
- Playwright-validated where it renders a UI; library-only paths terminate at
  wiring check with receipt.
- Acceptance: one repo surface generated through ash_surface, wired into xaas,
  passing E2E — the self-hosting proof for this milestone.
- **Receipt update (x2, 2026-10-06)**: capability surface PARTIAL_ALIVE —
  Tier 1 ALIVE (one real consumer, digest-verified pipeline, 96 test files;
  ash_pplan FLEET-BASELINE witnessed 1200 tests / 0 failures at 26.10.1);
  Tier 2 built+tested but consumer-less. Fleet wiring UNKNOWN until G1–G5
  falsifiers run (1/11 repos wired today). Residual lane build roots
  (`_build-fleet-ash_surface` etc., 5 dirs) still on disk from the prior
  fan-out — cleanup-law violation, inventoried not deleted.

### ggen

- `feat/v26.10.5-release-cut` @ `000bffb8` compiles and passes its test suite.
- xaas/ash_surface consume ggen through the lawful front door
  (`ggen-marketplace/marketplace.active.toml`, `front_door=ggen-platform-pack`);
  no sibling-pack fallback.
- Acceptance: `ggen sync run` on the pinned SHA regenerates the consumed
  projections byte-identically (drift falsifier).
- **Receipt update (r1, 2026-10-06)**: repo ALIVE at `000bffb8f` (clean tree,
  2 commits past tag `v26.10.5`: MU3 mutation sample 0/6 survivors, CA1 hygiene).
  Version-bump/changelog/tag edits (E1/E2) proposed, NOT executed — deferred to
  implementer pass (no-builds audit lane); ggen ships no browser surface
  (playwright rung n/a).

### ggen-marketplace

- Active pack selection resolves to the packs v26.10.5 consumers need; pack
  contents match what xaas/ash_surface bind.
- Acceptance: a fresh consume through `ggen sync` using marketplace selection
  succeeds for the ash-manufacture profile and any UI-related pack used by the
  Playwright surfaces.
- **Receipt update (r2, 2026-10-06)**: v26.10.5 FINAL receipt on file
  (295 ALIVE / 9 WARN / 1 SKIPPED over base `3ddbfeb7`); version-field drift
  (`v26.10.2` / `26.9.12`) pre-staged for fix at integration. Frozen court
  identity ggen `v26.8.11` @ `402cecdf` pin-bump is **BLOCKED:release-artifacts**
  (user-gated; pre-staged edit, do not bump). Consumer pin currency handled by
  diff-gate decision rule (empty diff → keep pin).

### ggen_igniter

- Manufacture profile (`ash-manufacture-pack`) present at the bound SHA;
  `mix ggen_igniter.sync --pack ash-manufacture-pack` executes.
- Acceptance: an Ash surface change flows ontology → ggen_igniter → real
  Ash/Igniter projection into a consumer repo, verified by compile+test there.
- **Receipt update (r3, 2026-10-06 — criterion invalidated)**: the
  `ash-manufacture-pack` is **fixture-only** — it lives at
  `test/fixtures/ash_manufacture_pack/`, absent from `priv/ggen/`, and is
  excluded from the hex `files:` list (`shipped_packs/0` rejects every `ash`
  path). The hex-install path is UNSUPPORTED: a hex consumer cannot resolve the
  pack by name. Qualification standing is fixture-scoped (ash 3.33.1 / ash_pplan
  2.13.1 / igniter 0.8.4) and does not transfer to consumers' version sets.
  Acceptance therefore terminates at: consumer-local pack dir precedent (xaas
  `priv/packs/xaas_library_pack`, witnessed ALIVE) + fixture-scoped
  qualification, OR a shipped-pack release edge (else
  `REFUSED(PACK_NOT_SHIPPED)` / `BLOCKED(RELEASE_MISSING)`).

### ash_a2a

- v1.0 protocol surface intact (codec, plug, auth); conformance report runs and
  verdict is filed (`mix ash_a2a.v1_conformance_report`).
- Wiring: a2a surface reachable/registered through xaas where the milestone wiring
  requires it (per R4's plan).
- Acceptance: conformance report + real transport test green at the pinned SHA;
  no UI surface expected (rung 3).
- **Receipt update (r4, 2026-10-06)**: protocol core ALIVE (courts + TCK verdict
  doc + CI); TCK PARTIAL_ALIVE (235/30/0, 79.0% at `b6b79dea`). Fleet runtime
  wiring **BLOCKED on both consumers**: xaas pins the wrong SHA (`3325032d`) and
  mounts the hex `a2a` Plug, not `AshA2A.Protocol.Plug`; ash_surface dep is
  compile-time-only (`runtime: false`). X4 owns pin alignment before the mount
  edit.

### ash_pplan

- Durable task store adapter (`adapter: :pplan`) behind the TaskStore seam
  compiles and its courts pass.
- Acceptance: restart-survival court passes through the adapter at the pinned
  SHA; no UI surface (rung 3).
- **Receipt update (r5, 2026-10-06)**: durability surface (`AshPPlan.A2A.Facade`
  + `providers/{durability,durable_dispatch,event_state}.ex`, deep `test/durable/`
  suite) exists and is courted at HEAD `414a393`. Correction to the mission
  brief: **xaas does NOT consume ash_pplan `~> 26.10`** — xaas pins a 26.9.8-era
  git SHA `b9da1ad`; the `~> 26.10` test consumption (C26 TaskStore adapter)
  lives in **ash_a2a** (`mix.exs:358`). ash_surface has no dep (moduledoc mention
  only). Head carries 1 unadjudicated net-new test failure (2309 tests, 7→8
  failures vs last receipted run) and declares 26.10.3, not 26.10.6.

### ferroplan

- Inventory of the 4 dirty files filed (R6; inventory only, no touch from lanes).
- Compiles + tests at HEAD.
- Acceptance: planner wiring edge into the fleet consumed where required
  (C01/pplan surface), else typed NOT_REQUIRED receipt for this milestone.
- **Receipt update (r6, 2026-10-06)**: repo core PARTIAL_ALIVE/ALIVE at
  `c037876` (planner core, wasm host, MCP station, standings infra exercised
  in-repo; 687 certified optima). Fleet wiring standing: **UNSUPPORTED** (typed
  absence in xaas registry.ex, unbound `planner_identity` in ash_surface, zero
  playwright coverage). #1 blocker: no committed pinned `.wasm` artifact — all
  wiring hops downstream of it. 4 dirty files = ggen receipt artifacts,
  inventoried, untouched.

### zcode-cli

- Inventory of 18 dirty files filed (R7; inventory only).
- Compiles + tests; gall-work / sjira HDDL plan surfaces parse at the pinned SHA.
- Acceptance: CLI surface invocation exercised end-to-end once with real output;
  no UI surface (rung 3).
- **Receipt update (r7, 2026-10-06)**: gall-work + remote-relay contract sha
  parity ALIVE (byte-identical, verified both sides this session). xaas-fabric
  plugin PARTIAL_ALIVE (pinned 26.9.17, xaas side moved). `/internal-api/execution`
  transport PARTIAL_ALIVE (router-present; no witnessed e2e). Dirty 18-file
  stream (max-turns/expert-strategy/typed-skip): committed nowhere, tests unrun
  — BUILD_BROKEN-unknown. ash_surface coupling: none, typed UNSUPPORTED(n/a).

### gymact

- Compiles + tests; gym actuation path runs a real episode/receipt (R8 plan
  defines the exact falsifier).
- Acceptance: one actuation receipt minted at the pinned SHA; no UI surface
  unless R8's inventory finds one (then rung 4).
- **Receipt update (r8, 2026-10-06)**: plan-only lane — nothing executed, no
  builds/tests run. Standing stays UNKNOWN; falsifier (E5 seam + gymact-dod
  suite + Playwright spec) unrun by design of the read-only audit.

### beam4pm

- 2462 dirty files classified (R9) with a split-commit plan filed; classification
  receipt distinguishes generated vs hand-written.
- Acceptance: at minimum compiles at a classified head; full test pass or a
  disclosed BLOCKED with the split plan as the repair path.
- **Receipt update (r9, 2026-10-06)**: classification receipted at `813eb92`
  (2,462 dirty rows; ggen-regenerated OTP-29 toolchain move; 677→673 record
  types; 30 aloop resources minted; frontier packs unwired FM-PACK-001;
  island — comment-only fleet coupling, no dep edge). **Compile/test under
  OTP-29 never run — UNKNOWN**; this is the qualification gate before the
  split-commit groups land.

### wasm4pm

- CI/fmt/tsc state filed (R10); build green at classified head.
- Acceptance: library surface consumed through the fleet wiring where required,
  else typed NOT_REQUIRED receipt.
- **Receipt update (2026-10-06)**: no r10 receipt was filed under
  `docs/sjira/v26.10.6/plans/` (r10 absent; wasm4pm named only in X-lane
  inventories). Standing cannot be filled from receipt evidence — remains
  UNKNOWN pending the audit lane's receipt.

### autofde-lab

- doctrine-lab wiring plan (R11) executed to the extent it binds v26.10.5
  surfaces.
- Acceptance: compile + test at classified head; wiring edge receipt or typed
  NOT_REQUIRED.
- **Receipt update (r11, 2026-10-06)**: PARTIAL_ALIVE — read path
  (`status_parser.ex` → `~/autofde-lab/docs/STATUS.md`, observed on disk),
  StatusLive surface + ExUnit + `e2e/autofde-lab.spec.cjs` all present. Gap:
  `config/dev.exs` program path points at `~/xaas/worktrees/repos/autofde-lab`
  which does NOT exist (ENOENT) — program declared but cannot resolve the
  canonical checkout at `/Users/sac/autofde-lab`.

## Frontier table

Standing column: filled from lane receipts ONLY. Receipt column: path to the lane
plan/receipt under `docs/sjira/v26.10.6/plans/`. Falsifier: the observation that
would kill the ALIVE claim.

**Integration refresh (W123, 2026-10-06)**: standings above now integrate the
EXECUTION receipts filed under `docs/sjira/v26.10.6/plans/` (w-lanes), on top of
W31's audit citations (kept where the standing is unchanged). Upgrades applied
only where a receipt shows an executed gate: beam4pm UNKNOWN → PARTIAL_ALIVE
(`w52`/`w74`), wasm4pm UNKNOWN → PARTIAL_ALIVE (`r10` filed this wave + `w94`),
zcode-cli PARTIAL_ALIVE → ALIVE repo-level unit suite (`w46`/`w58`). No upgrade
without an executed gate: gymact stays UNKNOWN — the coordinator-cited
`w9`/`w19`/`w21`/`w36`–`w38`/`w40`(exists)/`w42`–`w48`(only `w45`,`w46` exist)/`w50`/`w53`–`w56`/`w59`/`w79`/`w90`/`w92`/`w93`/`w95`/`w98`–`w102`/`w104`–`w107`/`w109`/`w112`/`w113`/`w115`–`w119`/`w121`–`w125` receipts are absent from the plans directory; only the files listed in the rows exist. `w114` is a PLAN-ONLY receipt (no commits executed) and upgrades nothing.

| repo | standing | receipt | falsifier |
|---|---|---|---|
| xaas | PARTIAL_ALIVE | audits (W31): `x8-ash-surface-gen.md`; `vector5-limits-lints.md`; `x1`, `x1b`, `x3`, `vector1-3`, `vector6`, `x7`. Execution: `w69-gates-rerun.md`, `w82-oracle-rerun.md`, `w108-sibling-build.md`, `w120-web-suite.md`, `w103-prod-compile.md`, `w87-ci-validation.md`, `w91-permission-sweep.md`, `w111-pw-interim.md`, `w70-playwright-full.md`, `w30-playwright-baseline.md`, `w68-full-suite.md`, `w51-integration-verify.md`, `w85-mix-generator-parity.md`, `w251` (suite-with-token classification 3125/3230, 105F — dominant async-env class FIXED by `w280`, gates 18/16/13 + 91/91; Class D refuted by `w281`; definitive post-W280 re-measure = `w289` in flight), `w259`/`w260` (87/9/2 + ground truth: all 5 "real" failures = probe-subject drift, server truth matches landed fixes; spec-side TASK_STATE_* enum alignment CLOSED by `w270-a2a-sse.md` — a2a-v1 spec 7/7 incl. SSE TASK_STATE_COMPLETED, witness 3/3, ggen-workbench 6/6, exit 0; but per `w302-pw-post-w270.md` the streaming court asserted an unimplemented capability — real streaming remains open lib-side), `w289-final-dod-suite.md` (3230/3232 run 1, run 3 3230/3235 — DoD-1 residue 5 subprocess-infra tests, W158 105-class collapsed to zero; superseded by `w315-final-dod-suite.md`: full `mix test` ×2 — run 1 fully green, run 2 3232/3235; mock gate `[]`; standing ALIVE, DoD-1 measurement complete). Fresh audit receipts (W345, all `test -f`-verified): `w321-unreachable-reverify.md` (structural-unreachability re-verify: 4 CONFIRMED / 5 STALE-line-moved / 2 REFUTED — refusal-shape inventory corrected against current tree), `w322-zero-config-posture.md` (zero-config refusal/safety posture HELD — zero category-(c) safety-adjustable knobs in xaas and ash_surface), `w339-pin-alignment.md` (pin alignment audit — xaas mix.lock reads ash_a2a `86214551`, ash_pplan `5f10c979`, ash_r2rml `0d5320f6`, ex4pm `9f7aecda`; sibling HEADs + dirty counts read real) | RUN: web layer 347/347 green (`w120`); generator pipeline + drift guard byte-identical green (`w69`); actuation/castle/boundary 16/17 (`w69`); CI YAML 21/21 + mock gate `[]` (`w87`); oracle suites — r_projection 9/9, consistency 18/18, yield 8/8, successor 8/8, origin_authority 10/10 after sibling rebuild (`w82`/`w108`). FAILED/OPEN: full `npx playwright test` green still NOT witnessed — `w70` 49 pass/37 fail (17 token-absent 503, 6 spec bug, 6 app gap, 7 seed), `w111` 25/6 residual; prod compile `--warnings-as-errors` exit 1, 16 app-code warnings (`w103`); WitnessLiveTest 3F (Ash.create/3 form + sandbox ownership, `w69`); anchor 8/10 live `mu_on_O` REFUSED (`w108`); goal 17F + stop-court 12F = receipt-schema-v2 harness drift (`w82`); `xaas-mapping.generated.ttl` generator permanent-UNKNOWN (`w85`); `w229`: Autonomic.build_ctx single-repo suite-precedence defect fixed (Keyword.merge clobbered registry suite; 3-line fix + regression test, 8/8). W298 integration update: `w251` suite-with-token classification 3125/3230, 105F — dominant async-env class now FIXED by `w280` (gates 18/16/13 + 91/91), Class D refuted by `w281`, definitive post-W280 re-measure CLOSED (`w289`/`w315` as above); `w259`/`w260` ground truth 87/9/2 — all 5 "real" failures = probe-subject drift, server truth matches landed fixes, spec-side TASK_STATE_* enum alignment CLOSED (`w270`, streaming residual per `w302`). W297c convergence: `w261` ash_a2a full suite 3708/0 — W77's order-dependent failures confirmed gone (boot sweep + W130 TTL). FAILED/OPEN (supersedes the old "full PW green NOT witnessed" item): full `npx playwright test` green now WITNESSED — `w317-pw-final-tokened.md` 96 executable / 0 failed / 0 flaky on exact subject `d1db2b03`; `w299-pw-final2.md`/`w310g-pw-final.md`: `/internal-api/health` 503-with-token real defect (`w310g`), ggen-workbench tokenless 406-vs-401/503 (`w299`). W415 refresh (post-W345 closures, all `test -f`-verified under `docs/sjira/v26.10.6/plans/`): the three remaining real defects from W345's text are RESOLVED — (1) health 503-with-token FIXED (`w344-health-503-diagnosis.md`, warmup-window typing in `health_controller.ex` re-witnessed green on the e2e boot path); (2) ggen-workbench tokenless 406 CLOSED (`w347-workbench-matrix.md` — tokenless answers typed 401, never 406, unit court green at `_build-laneW347`); (3) lib-side streaming residual RESOLVED as spec-aligned (`w368-sse-residual-probe.md` — `AshA2A.Transport.Plug.stream_message/4` pushes real chunked SSE incrementally; verdict SPEC-ALIGNED-BUT-BUFFERED-ACCEPTABLE, nothing open lib-side). Fresh citations: `w329-unignored-suites.md` (bounded suites real run counts — receipt dir 27/27 incl. r_projection 9/9, origin_authority 10/10, ard_court 51/0, yield 8/8, consistency 18/18, 0 skipped), `w375-receipt-hygiene.md` (receipt hygiene audit: python byte-scan authority for emptiness/NUL over all plans files), `w378-vkg-kill.md` (REFUSED_VKG_EMPTY_CATALOG = typed structural unreachability, clause (b), no kill test needed), `w379-actuation-kill.md` (actuation identity-mismatch kill test landed append-only; inverted-gap finding → OS-18 pointer), `w382-anti-vacuity-r2.md` (round-2 kills executed with revert-net-zero proof; empty-bearer guard `require_internal_api_token.ex:130` SURVIVED = vacuous as tested — anti-vacuity gap open, `w414` fix in flight), `w385-conformance-court.md` (ash_a2a v1 conformance court CONFORMANT 26/26 (100%) at `07180bd3`, offline no-bootstrap form), `w395-format-rewitness.md` (format GATE-CLEAN — `mix format --check-formatted` PASS on touched files, full-tree spot green), `w396-zeroconfig-delta.md` (zero-config posture STILL-HELD post-OS-17 — all new env reads fail-closed-safety). Remaining OPEN: empty-bearer anti-vacuity gap (`w382`, fix `w414` in flight); server-death mechanism classified (`w299b`: dispatch paths ALIVE 30/30, run-2 attribution probable not witnessed) |
| ash_surface | PARTIAL_ALIVE | audits (W31): `x2-ash-surface.md`. Execution: `w69-gates-rerun.md`, `w80-pack-repin-diff.md`, `w91-permission-sweep.md`. W415: `w348-ash-surface-fleet-falsifiers.md` (G1 version-alignment gate ALIVE at `db5a8899e4` @ 26.10.6; G1b–G5 typed BLOCKED per receipt), ash-surface refusal ledger at `docs/cro/artifacts/ash-surface-refusal-ledger-v26.10.6.md` (`w403`, cited from `docs/cro/artifacts/cycle0-dryrun.md`) | RUN: generator pipeline end-to-end + byte-identical drift guard GREEN via xaas path dep (`w69`); perm sweep repaired 58 dirs (`w91`). UNRUN: G1–G5 fleet-wiring falsifiers (1/11 repos wired); Tier-2 projections zero external consumers; ash-extension re-pin render-verify unrun (`w80` — diff-only receipt, predicted byte-identical, falsifier = `ggen sync` at new pin shows any non-`ggen.lock` delta) |
| ggen | ALIVE (repo-level @ `000bffb8f`) | `r1-ggen.md` (W31). Execution: `w81-ggen-cargo-check.md` | RUN: `cargo check --workspace` exit success on exact subject `000bffb8`, zero compile errors; W50 LOCK_STALE RESOLVED (Cargo.lock settled, 9 entries at 26.10.6) (`w81`). UNRUN: E1/E2 cargo test + `ggen sync` drift falsifiers; version-bump/changelog/tag proposed, not executed (W114 plan-only) |
| ggen-marketplace | PARTIAL_ALIVE | `r2-marketplace.md` (W31). Execution: `w80-pack-repin-diff.md` | RUN: baa5f117→3ddbfeb7 ash-extension pack diff materialized + analyzed (94 files, +11231/−218); existing outputs predicted byte-identical, 2 named risks (`w80`). UNRUN: validate/catalog/PW3 re-run after version-field fix; re-pin render verification; frozen ggen pin v26.8.11 pin-bump BLOCKED:release-artifacts (user-gated) |
| ggen_igniter | PARTIAL_ALIVE | `r3-igniter.md` (W31). Execution: `w108-sibling-build.md`, `w82-oracle-rerun.md`, `w91-permission-sweep.md`, `w114-commit-plan.md` (plan-only) | RUN: sibling rebuilt — `mix deps.get` + `MIX_ENV=test mix compile` exit 0 (178 files), `_build/test` restored; origin_authority 10/10 green after rebuild (`w108`). OBSERVED on tree, commit pending: ash-manufacture-pack promoted `test/fixtures/` → `priv/ggen/` (W6/W38 tree state per `w82`/`w108`; W114 C1 stages it). UNRUN: §6 falsifier (pack resolves by name from shipped hex, consumer compiles+tests green) — r3's UNSUPPORTED(hex) verdict stands until that gate executes |
| ash_a2a | PARTIAL_ALIVE | `r4-a2a.md` (W31). Execution: `w109` (court 5/5), `w113-a2a-pw.md` (residual classes), `w150` (fix in flight) | Pin advanced: live pin IS `86214551` (verified `mix.exs:103-107`), `/a2a/v1` mount real (`router.ex:211`), W109 court 5/5 green. Stale BLOCKED-pin framing retired — wiring no longer blocked at current pins. Open falsifier: e2e at scale — W113's residual classes (PendingMigrationError 500s, -32700-vs--32600 parse defect, 406-before-auth on `:api` pipeline), W150 fix in flight |
| ash_pplan | IN-FLIGHT (W291 verdict pending — no W291 receipt on disk as of W345; standing frozen, not guessed) | `r5-pplan.md` (W31). Execution: `w41-pplan-facade.md` (facade 5/5) | Ref advanced to `5f10c979` (`mix.exs:252-254`, origin/main — A2A durable Facade present); W41 facade courts 5/5 green. IN-FLIGHT: W291 verdict pending — standing frozen, not guessed. UNRUN: adjudicate the net-new test failure at `414a393`; exact-head consumer-side court unrun |
| ferroplan | PARTIAL_ALIVE | `r6-ferroplan.md` (W31). Execution: `w45-ferroplan-wasm-pin.md` | RUN: pinned wasm artifact BUILT via repo's own path (`cargo build --locked -p ferroplan-wasm --release --target wasm32-wasip1`, 51.68s), digest reproduces registry+ontology pin byte-identically (`088d9c3b…`); wasmtime in-loop court 54 pass / 0 fail; `pin_drift` 7/7 (`w45`). r6's #1 blocker (no committed pinned `.wasm`) CLOSED — artifact on disk, untracked; W114 ferroplan C1 commits it. UNRUN: downstream fleet-wiring hops (xaas bridge vendoring, pplan provider, ash_surface binding) — now unblocked at this digest |
| zcode-cli | ALIVE (repo-level unit suite @ `7fc62da`) | `r7-zcode-cli.md` (W31). Execution: `w46-zcode-stream-tests.md`, `w58-zcode-deps.md`, `w40-zcode-release-workflow.md` | RUN: after `bun install` (195 pkgs, lockfile unchanged) full unit suite **1072 pass / 0 fail** (125 files, 90.8s) (`w58`); stream-patch tests 19/19 green (`w46`); prepare-release workflow diagnosed — 5 consecutive scheduled failures, 2 classes (runtime smoke self-resolved; active blocker = version drift, main `3.14.4-1` behind npm latest `3.14.4-32`, guard correctly refusing) (`w40`). UNRUN: end-to-end CLI invocation; 18-file dirty stream committed nowhere (W114 C1/C2 plan-only); release unblock needs version decision on `main` |
| gymact | ALIVE | `w42` (adapter 9/9, config seam), `w79-gymact-dcm.md` (DCM 17 STRUCTURAL / 1 UNKNOWN; crown OS-10 unwitnessed), `w129-gymact-crown.md` (witnessed ALIVE transition, receipt_id adae920d…), `w95-gymact-full-suite.md` (full pytest 2356/0/41skips), **`w325-gymact-e2e-falsifier.md` (END-TO-END ALIVE 2026-10-06: pytest courts exit 0 ×3, 2378 collected, typed env skips only; W129 crown finding re-confirmed `witnessed_crown` unreachable by construction — OS-10, convergence-honest; `e2e/autofde-lab.spec.cjs` 2/2 tokened on the real server)**, `w373-gymact-wpj.md` (WP-J NO-OP: 26.10.6 coherent) | End-to-end falsifier executed green (w325). Falsifier (unchanged, future): witnessed_crown flip — OS-10 standing-feedback overlay + crown-premark-law change, v26.10.7+ |
| beam4pm | PARTIAL_ALIVE | `r9-beam4pm.md` (W31). Execution: `w52-beam4pm-qualification.md`, `w74-rust4pm-wasm.md` | RUN: OTP-29 qualification gate EXECUTED — `mix compile` exit 0 (all 677 regenerated resources); full suite 1506/1509 passed, 13 invalid, 179 skipped (`w52`); rust4pm wasm artifact built (sha256 `6a66c0f1…`), W52's missing-wasm cause CLOSED — failure 1 fixed, all 13 invalid groups cleared, 34 pass / 0 fail (`w74`). FAILED: 2 AuthorshipGate tests, `REFUSED_SHA_DRIFT` on dirty-tree edit to `test/beam4pm_evidence_chain_test.exs` (pre-existing, tree-owner's; out of lane scope). 2495 dirty lines uncommitted (W114 SKIP) |
| wasm4pm | PARTIAL_ALIVE | `r10-wasm4pm.md` (filed this wave), `w94-wasm4pm-flake.md`, `w331-wasm4pm-ci-assessment.md` | RUN: `cargo fmt --check` exit 0 at exact head; CI real-but-red — main-head CI sole failure = ml float-boundary test flake (`r10`); flake FIXED test-side (epsilon `0.3 + 1e-9` at `algorithm-selection-with-scaling.test.ts:407`), vitest 25/25 green locally (re-witnessed W331 2026-10-06, 279ms) at dirty head `32deb59f6` (`w94`, `w331`); local `pnpm test` BLOCKED(local-deps-install) pre-fix, resolved by `w94`'s install. UNRUN: full `pnpm test` monorepo-wide locally (prior lanes scoped to the ml suite). GATED-ON integration commit: ci.yml has no path filters (fix file in trigger scope), pins exact head, runs `pnpm test` → fixed assertion exercised and ALIVE receipt emitted on green; CI-exact-head confirmation run does not exist yet — do not upgrade to ALIVE until the post-merge CI run on the exact integration SHA is observed (`w331` §4); xaas executable wiring edge typed NOT_REQUIRED (`r10`) |
| autofde-lab | PARTIAL_ALIVE | `r11-autofde-lab.md` (W31). Execution: `w35-autofde-oracle-gate.md`, `w78-autofde-baseline.md`, `w110-autofde-import.md`, `w111-pw-interim.md` | RUN: xaas oracle gate ALIVE — `mix test test/xaas/sjira/yield_test.exs` 8 passed / 0 skipped over real `autofde beam-bridge` Port (`w35`); baseline `just test` BLOCKED-red recorded (92F/68E: Class A env import-shape + missing optional deps, Class B real assertion failures) (`w78`); W78's `DeterministicPlanningDomain` ImportError class does NOT reproduce on canonical checkout — 0 occurrences, 290 pass / 18 fail subset (`w110`); `e2e/autofde-lab.spec.cjs` 2/2 green (`w111`). OPEN: r11's `config/dev.exs` program-path ENOENT; Class B assertion failures unadjudicated; `test-full` ladder not run |

## Rules for updates

- Standing changes require: executed command output + receipt path in the row +
  lane id. Never assumption, never CI presence, never another repo's green.
- BLOCKED rows keep their falsifier and add the blocking reason inline; a blocker
  branches the search graph, it does not close the row.
- Coordinator owns all edits to this file during integration; lanes submit receipt
  lines via their plans.
