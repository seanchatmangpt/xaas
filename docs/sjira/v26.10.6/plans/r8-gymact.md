# R8 — gymact audit & wiring plan (v26.10.5 fleet wiring fan-out)

Lane R8, 2026-10-06. Repo: `/Users/sac/gymact`, branch
`v26926/gymact-land-aloop-execution-kernel` @ `d3eb5e8`, 3 dirty files
(CHANGELOG.md, README.md, docs/reference.md — documentation-only diff recording
the survival CLI, retirement module, and SA2A replan envelope landing; inventoried
in the diff itself, not touched).

## 1. Standing (real evidence, observed this session)

- gymact is the fleet's BRCE/actuation/receipt layer, per its own scope doc
  `docs/actuation-layer-scope.md`: it receives an already-admitted
  `ActuationIntent` and decides admit → actuate → verify → receipt, fail-closed
  authority (`src/gymact/brce.py`, `src/gymact/authority.py`).
- Actuation HTTP surface already exists and is real:
  `src/gymact/surfaces/fastapi.py` `create_app()` exposes `/health`, `/profile`,
  `/contract`, `/evidence`, `/evidence/prov`, `/providers`, `POST /candidates`,
  `POST /possibilities/explore`, `POST /episodes`, episode capabilities /
  observations / actions / verify / checkpoint / restore / teardown.
  Sibling surfaces: `surfaces/fastmcp.py`, `surfaces/faststream.py`.
- ALOOP execution kernel is real: `src/gymact/execution_loop.py`
  (ExecutionRequest/Provider/Receipt, kernel-owned actuation ledger, OCEL 2.0
  event vocabulary, exactly-five LegalOutcome with WaitForHumanToNotice
  unreachable as IllegalOutcome; fault corpus `tests/explore_execution_loop/`).
- Playwright-adjacent surface: `src/gymact/gyms/browsergym.py` — real
  BrowserGym 0.14.3 + Playwright sync API on a dedicated worker thread,
  `goto`/`go_back`/`go_forward` DO capabilities, Chromium pinned to
  ServiceNow/BrowserGym @ `9e779f0`. This is Chromium-driving, but it is a gym
  provider, not a Playwright E2E spec of the fleet surface.
- Existing xaas wiring (consume side): `~/xaas/config/dev.exs` lines 197–201
  registers a `gymact` repo entry (sensing `gymact-jira`, suite `gymact-dod`,
  canonical `gymact-canonical`); `~/xaas/lib/xaas/ultracode/target_suites.ex`
  defines `gymact-dod`/`gymact-canonical` Python suites running
  `~/gymact/.venv/bin/python`. Suite name contracts `gymact-jira` (jira_dir
  `docs/jira`) and suites exist in the xaas judge.
- CI: ~50 workflows under `.github/workflows/` incl. `ci.yml`, `release.yml`,
  `federated-capability-owner.yml`, `survival-campaign-closure.yml`. No
  Playwright workflow.

## 2. Gaps to "fleet wired through xaas/ash_surface, Playwright-validated, v26.10.5 feature complete"

1. **Broken xaas-side path ( BLOCKING for the xaas judge )**:
   `~/xaas/config/dev.exs:198` points the gymact repo entry at
   `~/xaas/worktrees/repos/gymact` — that directory does not exist (observed).
   Violates one-canonical-checkout law; the real checkout is `/Users/sac/gymact`.
   Until fixed, `gymact-dod`/`gymact-canonical` sensing can't resolve the repo
   root.
2. **gymact venv absent**: `~/gymact/.venv/bin/python` does not exist (observed).
   Both xaas-registered suites would fail on invocation. Need
   `cd /Users/sac/gymact && uv sync --extra gyms` (or plain `uv sync`) to mint
   the venv the suites pin.
3. **No xaas → gymact actuation bridge**: zero gymact references in
   `~/xaas/lib/**` (grep: only ultracode repos/suites mention the name as a
   test target) and zero in `~/ash_surface/**`. Nothing in xaas posts an
   admitted intent to gymact's `/candidates` → `/episodes` → actions → `/verify`
   surface, so the gym actuation surface is not "wired through xaas".
4. **No ash_surface projection**: gymact's capability surface has no
   ash_surface counterpart (no Ash resource / surface module referencing
   gymact capabilities `urn:gymact:*`).
5. **No Playwright E2E validation**: no Playwright spec exercises the gym
   actuation surface (neither gymact's FastAPI surface nor an xaas-hosted page
   proxying it); no Playwright CI workflow in gymact.
6. **Version skew**: gymact `pyproject.toml` `version = "26.9.28"` vs the
   v26.10.5 milestone; FastAPI surface embeds a hardcoded `version="26.8.7"`
   string in `create_app()` — two stale version strings in one repo.
   `fastapi.py:37`.
7. **Dirty doc diff unmixed**: 3 dirty files are landing-notes for the survival
   CLI / retirement / SA2A envelope work; they belong to the v26.10.x landing
   commit set and must be committed (by coordinator) before any wiring diff
   stacks on top.

## 3. Proposed edits (exact, coordinator-owned integration)

### gymact repo (`/Users/sac/ga... /Users/sac/gymact`)

- E1 `pyproject.toml`: `version = "26.10.5"`; ensure `gymact-survival` script
  entry point exists (dirty-diff docs reference it; verify
  `[project.scripts]` declares it).
- E2 `src/gymact/surfaces/fastapi.py:37`: replace hardcoded
  `version="26.8.7"` with import of the package version
  (`importlib.metadata.version("gymact")` with fallback), so the /profile
  contract stops reporting 26.8.7.
- E3 commit the 3 dirty doc files as the landing receipt commit (coordinator).
- E4 (optional, defer if scope tight) add `docs/integrations/xaas.md` mirroring
  `docs/integrations/consumer-setup.md` for the xaas consumer shape.

### xaas repo (seams — coordinator edits, not lane)

- E5 `config/dev.exs:198`: path → `Path.expand("~/gymact")` (canonical
  checkout, worktree path is dead).
- E6 new `lib/xaas/operations/gymact_surface.ex`: an adapter over gymact's
  HTTP surface — `create_client/1` (base URL + `INTERNAL_API_TOKEN`-style
  header pass-through), `post_candidate/2`, `open_episode/2`,
  `select_action/3`, `verify/3`, mapping gymact receipts into
  `Xaas.Actuation` authority context (stable idempotency key, explicit
  authority; no bypass of `:actuate_status`). Real HTTP client (Req/Finch),
  Chicago-testable against a real locally-run gymact `create_app()` uvicorn
  process (real subprocess fixture, not a mock).
- E7 route exposure: mount the gym surface in `XaasWeb.Router` under the
  existing gated `/internal-api` scope (e.g. proxy resource
  `/internal-api/gym/*` → gymact), reusing `RequireInternalApiToken`; no
  unauthenticated sibling.
- E8 test: `test/xaas/operations/gymact_surface_test.exs` spinning the real
  gymact FastAPI app via `uvicorn` subprocess (Chicago: real collaborator).

### Playwright validation

- E9 xaas-side Playwright spec `priv/static or test/e2e/gym-surface.spec.ts`
  (name per X1's spec layout): drive the gated gym surface page — list
  providers, open episode, submit action, see verified receipt rendered in the
  LiveView — asserting on the receipt DOM, through the real xaas server and
  the real gymact subprocess behind it.
- E10 wire the spec into the xaas Playwright suite on
  `feat/playwright-surface` and gymact CI: add `.github/workflows/playwright-gym.yml`
  (or reuse xaas playwright workflow via P-shape SHA-pinned reusable workflow,
  catalog primitive P).

### ash_surface

- E11 `~/ash_surface`: add a gymact capability surface module projecting
  gymact capabilities (`urn:gymact:browsergym:capability:goto` etc.) as Ash
  resources/surfaces so the actuation surface appears in the ash_surface
  catalog; consume from xaas via the existing ash_surface dep seam. (Shape
  follows whatever X2's surface audit standardizes; coordinate with X2.)

## 4. Risks

- **Dirty-file stacking**: any gymact commit must sit on the 3 dirty doc files
  being committed first, else the wiring diff tangles with unrelated landing
  notes. Mitigation: coordinator commits those first (E3).
- **venv/env drift**: `uv sync` will resolve current locks; the xaas suites
  pin `~/gymact/.venv/bin/python` by path — minting the venv is a mutation of
  gymact's tree (untracked `.venv/`), harmless but must be disclosed in the
  receipt. Also check the `GYMACT_ALLOW_DEGRADED_STANDINGS` allowlist in
  target_suites matches current standings after sync.
- **Ash policy floor / auth**: E6/E7 must keep deny-by-default and the
  `RequireInternalApiToken` gate; the gym proxy is a consequential-DO path —
  route through `Xaas.Actuation.run/4` with idempotency key, never a bare
  proxy that bypasses `:actuate_status`.
- **Cross-language test cost**: E8's uvicorn subprocess fixture is the most
  expensive item; if the lane budget is tight, E6+E7 can land with the
  FastAPI surface exercised through gymact's own pytest courts
  (`tests/`) instead, and E8/E9 as a follow-up — but then Playwright-validated
  is PARTIAL, not complete.
- **browsergym pin**: the browsergym bridge pins Chromium/BrowserGym at a
  frozen SHA; a venv re-sync could drift `browsergym-core` off 0.14.3 — pin in
  lockfile, verify with the bridge's own guard (it refuses on version mismatch).
- **Parallel-lane conflicts**: E5/E7 touch xaas seams (config/, router) that
  other lanes may also want — coordinator-only edits, sequence at
  integration.
- **Version bump blast radius**: bumping to 26.10.5 will make existing
  version-pinned tests/docs stale; grep for `26.9.28` across tests/docs at
  implementation time.

## 5. Falsifier (how this plan is killed)

- A run of `~/xaas` gymact-dod suite with E5 fixed and venv minted that still
  cannot resolve the gymact repo root, or
- E6–E9 landed and `mix test test/xaas/operations/gymact_surface_test.exs`
  plus the Playwright spec pass while the gym actuation surface is still
  unreachable from any xaas HTTP route — i.e. wiring landed that does not
  actually connect.

## 6. Sequencing

1. E3 (commit dirty docs) → 2. E1/E2 + venv mint (gymact side) → 3. E5
  (xaas seam) → 4. E6/E7/E8 (bridge + tests) → 5. E9/E10 (Playwright) → 6. E11
  (ash_surface, coordinate with X2).

Standing: UNKNOWN (plan only; nothing executed this session — read-only lane,
no builds/tests run, no git mutations performed).
