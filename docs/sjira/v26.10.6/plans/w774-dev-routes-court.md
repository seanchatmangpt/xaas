# W774 — dev-routes court (receipt)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD `a0723bf6` (branch tip; test file + receipt uncommitted in working tree, per lane order: DO NOT commit)
- **Standing**: ALIVE (7/7 real HTTP courts green on exact subject; see runs below)
- **New file**: `test/xaas_web/dev_routes_court_test.exs` (only file written besides this receipt)

## Court contents

Chicago-style, real requests, no mocks. Four sections:

1. **Enabled side (real HTTP)** — test config sets `config :xaas, dev_routes: true` (`config/test.exs:81`), so the compile-time block at `lib/xaas_web/router.ex:314` IS mounted under the test endpoint:
   - `GET /dev/dashboard` → 200 `text/html` (302-follow allowed: LiveDashboard canonical-page redirect)
   - `GET /admin` → 200 `text/html` with `<title>Ash Admin</title>` (302-follow allowed: AshAdmin first-domain redirect)
   - `live(conn, "/dev/dashboards/autofde-lab")` → real mount of `XaasWeb.AutofdeLab.StatusLive`; asserts `autofde-lab benchmark history` + `phx-click="refresh"`
   - `live(conn, "/system")` → real mount of `System.CommandCenterLive`; asserts `data-testid="command-center-root"` + `System command center`
2. **Auth posture (honest)**: all requests carry zero credentials and assert 200 — the dev-only trust boundary is unauthenticated local service; production exclusion is enforced ONLY by the compile-time gate. No auth guard exists on these routes; the court asserts that fact rather than a fake guard.
3. **Disabled side (source pin, typed reasoning)**: `Application.compile_env(:xaas, :dev_routes)` is read at router compile time (`lib/xaas_web/router.ex:314`) and cannot be flipped per-test without recompiling the router — so the "never mounted outside dev" doctrine is pinned by source:
   - exactly one `if Application.compile_env(:xaas, :dev_routes) do` guard, no `live_dashboard(`/`ash_admin(`/`AutofdeLab.StatusLive` mount before it, and the guarded tail mounts exactly the documented surface (`/dashboard`, `/mailbox`, autofde-lab, `/system`, `ash_admin("/")`)
   - config pin: `dev_routes: true` present in `config/dev.exs` + `config/test.exs`; absent from `config/prod.exs` + `config/runtime.exs` → `compile_env` is nil/falsy in prod → block never mounted
4. **Determinism**: repeated unauthenticated `GET /admin` — same status + stable `<title>Ash Admin</title>` shell (bodies differ only by per-request CSRF nonce).

## Real command tails

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW774 \
  mix test test/xaas_web/dev_routes_court_test.exs
Result: 7 passed

# determinism reruns
# seed default (3-run loop): "Result: 7 passed" x2 (3rd line lost to pipe truncation)
# --seed 0 (first fix round): 6/7 → fixed autofde marker + /system live-mount + nonce-safe determinism
# final: default seed → "Result: 7 passed"; --seed 12345 attempt hit a concurrent lane's
#   transient compile break in lib/xaas/platform/route_secrets.ex (not this lane's file);
#   after settle → final run "Result: 7 passed"
```

Final observed tail (this session's last run):

```
Finished in 1.4 seconds (0.00s async, 1.4s sync)
Result: 7 passed
```

## Falsifiers + status

- `/admin` and `/dev/dashboard` stop serving 200 under dev_routes:true → kills ALIVE. **Ran, holds.**
- autofde-lab / `/system` LiveView mount refusal → kills ALIVE. **Ran, holds.**
- dev-route mount appearing outside the guard block, or `dev_routes: true` leaking into prod/runtime config → kills the source pin. **Pinned (static), not executed against a compiled prod router** — see gaps.

## Typed gaps

- **DISABLED-SIDE-NOT-EXECUTED**: the disabled branch was courted by source pin, not by compiling a prod router (`MIX_ENV=prod` compile of the router with dev_routes unset was not run — disk pressure, 100%-full volume during the lane, freed mid-lane to ~3 GB by deleting stale Oct 6 lane build roots per the lane-lease cleanup law). Honest standing for the disabled side: **PARTIAL_ALIVE (source-pinned)**.
- Transport warnings in every run: PromEx/Grafana dashboard upload `:nxdomain` warnings (no network in test env) — pre-existing, unrelated, non-fatal.
- Concurrent-lane churn observed mid-lane (transient compile breaks in `lib/xaas/platform/route_secrets.ex` / `RouteFeatureFlags` from other lanes' in-flight edits); this lane's final run is green against the settled tree.
- Lane build root `_build-laneW774` deleted at lane end per the cleanup law.

## Standing summary

| surface | standing |
|---|---|
| enabled side (/admin, /dev/dashboard, autofde-lab, /system) — real HTTP | **ALIVE** |
| disabled side (never mounted outside dev) | **PARTIAL_ALIVE** (compile-time source pin, config pin; no prod-router execution) |
