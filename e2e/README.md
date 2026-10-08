# e2e — Playwright surface suite

Verified 2026-10-08 (lane W984kz) against the working tree at
`feat/playwright-surface`, post-W984fw. Receipt:
`docs/sjira/v26.10.6/plans/w984fw-seed-writer.md` (writer identification +
pinned-dev fix) and `docs/sjira/v26.10.6/plans/w984kz-probe.md` (this pass).

## Boot pipeline

`npx playwright test` (any spec under `e2e/`):

1. Playwright starts the `webServer` BEFORE `globalSetup`.
2. `playwright.config.cjs` BOOT command:
   - `node ./e2e/global-setup.cjs --catalog` — generates the real
     ggen-marketplace catalog JSON (`scripts/marketplace.py catalog` in
     `/Users/sac/ggen-marketplace`) into
     `$(mktemp -u)/xaas-e2e-marketplace-catalog.json`, and seeds the
     next-read fixtures. Always exits 0; on failure the mount-time ingest
     surfaces a typed refusal in the UI.
   - `PHX_SERVER=true MIX_ENV=dev PATH="$HOME/.asdf/shims:$PATH" mix run -e
     'Application.put_env(:xaas, :marketplace_catalog_source, ...)' --no-halt`
     — boots the full Phoenix app (equivalent to `mix phx.server`).
     **MIX_ENV is pinned to `dev`** (W984fw): an inherited `MIX_ENV=test`
     used to serve `xaas_test` with no sandbox checkout, so LiveView writes
     committed foreign rows (W650h23 root cause). Server stdout/stderr are
     redirected to `/tmp/xaas-e2e-server.log` so a lost pipe reader cannot
     SIGKILL the VM mid-suite.
   - Readiness probe: polls the leased port until 200
     (`/internal-api/health` with `INTERNAL_API_TOKEN`, `/` tokenless).
3. `globalSetup` (`e2e/global-setup.cjs`): re-generates the catalog, sets
   `PW3_EXPECTED_PACK_COUNT`, seeds W55 witness rows
   (`e2e/seed-witness.exs`) and next-read fixtures (`e2e/seed-library.exs`)
   — both under `MIX_ENV=dev` — into `xaas_dev`. Every step is idempotent
   and failure-tolerant; a failed seed surfaces as the affected spec's
   degraded branch, not a setup crash.

## Database targeting (post-W984fw)

| Step | MIX_ENV | Database |
|---|---|---|
| webServer boot | `dev` (pinned) | `xaas_dev` |
| witness seed | `dev` (pinned) | `xaas_dev` |
| library seed | `dev` (pinned) | `xaas_dev` |
| ExUnit suite | `test` | `xaas_test` (SQL sandbox) |

The Playwright pipeline can no longer write `xaas_test` regardless of the
inherited environment. `grep -rn "MIX_ENV=test" e2e playwright.config.cjs`
shows only comment mentions; zero executable test-env invocations.

## DevSeeds env guard interplay (W983f / W984bs / W984fw)

`Xaas.DevSeeds.refute_non_dev_target!/0` (`lib/xaas/dev_seeds.ex`) refuses
unsandboxed non-dev calls with `REFUSED(dev_seeds, env=test)`. On the e2e
path this guard is now a belt-and-braces backstop: the seed runs in `:dev`
env (always admitted). The `e2e: true` opt-in and sandbox-owner branch in
`:test` remain for the ExUnit courts (`test/xaas/dev_seeds_test.exs`,
`test/xaas/dev_seeds_env_guard_test.exs`).

## Ports and concurrent lanes

- The webServer port is `PW_PORT` (default 4000); the app binds the same
  port via `PORT`. Concurrent lanes MUST lease distinct `PW_PORT` values.
  Never kill beams on `:4000` — cross-lane SIGKILL channel (retired
  cleanup, W310f).
- `reuseExistingServer: true`: an already-running server on the leased port
  is reused. Only reuse a server you booted with the same pinned-dev
  contract.

## Falsifier status

- W984fw fix: ALIVE at the config/JS layer (syntax + grep verified in the
  receipt).
- Full e2e re-run under the pinned-dev boot: **OWED — coordinator** (the
  falsifier is `MIX_ENV=test PW_PORT=4199 npx playwright test
  e2e/next-read-ml.spec.cjs` must produce 0 new committed rows in
  `xaas_test` with `inserted_at > boot time`).
