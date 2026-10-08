# Reference: Playwright e2e harness

Verified 2026-10-08 against the working tree at `819c116f`. Contracts are
grounded in `playwright.config.cjs` (103 lines) and `e2e/README.md` (verified
2026-10-08, lane W984kz).

## Suite structure

Spec files under `e2e/` (23 spec files on disk at the time of writing:
`a2a-marking.spec.cjs` through `zcode-cli-fabric.spec.cjs`, plus
`global-setup.cjs`, `seed-witness.exs`, `seed-library.exs`, and `README.md`).
The suite covers the real HTTP/LiveView surfaces: A2A marking and v1 protocol,
Ash admin matrix/state-change/destroy, surface client, autofde-lab,
chicago-pplan-deep, dev routes, execution fabric, full surface (`full_surface.spec.ts`),
ggen workbench, internal API, marketplace (`marketplace.spec.ts`), MCP-A2A,
next-read-ml, smoke, sparql-proxy, stripe-webhook, system-deep, wd-fa-cs2,
witness, and zcode-cli-fabric.

## Config self-boot (`playwright.config.cjs`)

`webServer.command` is the `BOOT` shell sequence
(`playwright.config.cjs:64-75`):

1. `node ./e2e/global-setup.cjs --catalog` — generates the REAL ggen-marketplace
   catalog JSON into `MARKETPLACE_CATALOG_PATH` and seeds next-read fixtures.
   Always exits 0; on failure the mount-time ingest surfaces a typed refusal in
   the UI (`playwright.config.cjs:23-34`).
2. `PHX_SERVER=true MIX_ENV=dev PATH="$HOME/.asdf/shims:$PATH" mix run -e
   'Application.put_env(:xaas, :marketplace_catalog_source, ...)' --no-halt` —
   boots the full Phoenix app (equivalent to `mix phx.server`). **MIX_ENV is
   pinned to `dev`** (W984fw): an inherited `MIX_ENV=test` served `xaas_test`
   with no sandbox checkout, so LiveView writes committed foreign rows
   (W650h23 root cause; `playwright.config.cjs:66-72`). Server stdout/stderr
   are redirected to `/tmp/xaas-e2e-server.log` so a lost pipe reader cannot
   SIGKILL the VM mid-suite (W299b/W310f; `playwright.config.cjs:52-57`).
3. Readiness probe: polls the leased port until HTTP 200 —
   `/internal-api/health` with `INTERNAL_API_TOKEN` (200 only when DB + every
   liveness check pass), `/` tokenless — up to 180 tries, 1 s apart; boot fails
   closed if the probe never returns 200 (`playwright.config.cjs:41-50,73`).
   W252 finding: Playwright's url probe passed while the app still answered 503
   during warm-up, poisoning first-wave tests.

webServer settings: `port: PW_PORT`, `reuseExistingServer: true`,
`timeout: 240_000` (`playwright.config.cjs:81-98`). `globalSetup` is
`e2e/global-setup.cjs` (runs AFTER the webServer starts; it re-generates the
catalog, sets `PW3_EXPECTED_PACK_COUNT`, and seeds W55 witness rows
(`e2e/seed-witness.exs`) and next-read fixtures (`e2e/seed-library.exs`) —
both under `MIX_ENV=dev` into `xaas_dev` (`e2e/README.md` "Boot pipeline"
step 3). Every seed step is idempotent and failure-tolerant.

## PW_PORT leasing (concurrent lanes)

The webServer port is derived from `PW_PORT` (default 4000) and is the single
source of truth for the webServer `port`, the readiness probe, and the default
`baseURL` (`playwright.config.cjs:5-19`). Concurrent lanes MUST lease distinct
`PW_PORT` values (e.g. 4000 and 4010) — the historical "kill all beams on
:4000" cleanup is retired because any concurrent kill is a cross-lane SIGKILL
channel (W310f; `playwright.config.cjs:59-63`). The Phoenix endpoint binds via
`PORT` (passed through in webServer env), so app bind port and probe/baseURL
stay on the same leased port — a mismatch would eaddrinuse or ready-gate on a
foreign server (`playwright.config.cjs:88-94`). `reuseExistingServer: true`
means a lane may reuse only a server booted with the same pinned-dev contract
(`e2e/README.md` "Ports and concurrent lanes").

## Database targeting (post-W984fw)

| Step | MIX_ENV | Database |
|---|---|---|
| webServer boot | `dev` (pinned) | `xaas_dev` |
| witness seed | `dev` (pinned) | `xaas_dev` |
| library seed | `dev` (e2e path) | `xaas_dev` |
| ExUnit suite | `test` | `xaas_test` (SQL sandbox) |

The Playwright pipeline cannot write `xaas_test` regardless of the inherited
environment; `grep -rn "MIX_ENV=test" e2e playwright.config.cjs` shows only
comment mentions (`e2e/README.md` "Database targeting"). The
`Xaas.DevSeeds.refute_non_dev_target!/0` env guard
(`lib/xaas/dev_seeds.ex`) remains as a belt-and-braces backstop; the e2e seed
path runs in `:dev` env and is always admitted (W983f/W984bs/W984fw).

## Token handling

`webServer.env` passes `INTERNAL_API_TOKEN` through when present
(`playwright.config.cjs:94-96`). Tokenless runs exercise the fail-closed specs:
auth-gated surfaces answer 503 by design, and the run is green only when the
tokenless-degraded contracts are asserted (`playwright.config.cjs:35-40`).

## Witnessed results (2026-10-08 receipts)

Witnessed in the 2026-10-08 e2e receipts (coordinator briefing; receipts under
`docs/sjira/v26.10.6/plans/`):

- smoke: **1/1 passed** on the pinned-dev boot.
- full sweep: **24/25 passed + 6/6 falsifier legs passed** (the single failure
  is the pre-existing full-surface spec, not a pinned-dev regression).

The full re-run under `MIX_ENV=test` (0 new committed rows in `xaas_test`)
remains OWED per `e2e/README.md` "Falsifier status".

## See Also

- `playwright.config.cjs`, `e2e/README.md`, `e2e/global-setup.cjs`
- `lib/xaas/dev_seeds.ex`
- `docs/claude/diataxis/how-to/graphlaw-wasm-seam.md` (related seam contract)
