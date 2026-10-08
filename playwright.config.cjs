// @ts-check
const { defineConfig } = require("@playwright/test");
const { MARKETPLACE_CATALOG_PATH } = require("./e2e/global-setup.cjs");

// Concurrent-lane port lease (W279/W310: concurrent Playwright lanes all
// bound :4000 via SO_REUSEPORT and stole each other's servers). The web
// server port is now derived from PW_PORT (default 4000) and used
// consistently for the webServer `port`, the BOOT readiness probe, and
// the default `baseURL`. CONCURRENT LANES MUST SET DISTINCT PW_PORT
// VALUES, e.g.:
//   PW_PORT=4000 npx playwright test e2e/smoke.spec.cjs &
//   PW_PORT=4010 npx playwright test e2e/smoke.spec.cjs &
// If you point PLAYWRIGHT_BASE_URL at a lane's server, it must match that
// lane's PW_PORT. Playwright also treats `webServer.port` as its
// readiness probe when `url` is unset, so a mismatched port there would
// make a lane "ready-gate" on a foreign server — hence the single
// PW_PORT source of truth below.
const PW_PORT = parseInt(process.env.PW_PORT || "4000", 10);
const PW_BASE_URL = `http://localhost:${PW_PORT}`;

// Boot command (fresh-boot path only — Playwright starts the webServer
// BEFORE globalSetup, so the catalog file must exist before `mix run`
// evaluates). Sequence:
//   1. node e2e/global-setup.cjs --catalog
//        generates the REAL ggen-marketplace catalog JSON into
//        MARKETPLACE_CATALOG_PATH (generator documented in
//        e2e/marketplace.spec.ts). Always exits 0; on failure the boot
//        continues and the mount-time ingest surfaces a typed refusal in
//        the UI.
//   2. mix run -e 'Application.put_env(...)' --no-halt
//        boots the full Phoenix app (same effect as `mix phx.server`) with
//        :marketplace_catalog_source set IN THE SERVER VM before any
//        LiveView mounts, so the mount-time ingest loads the real packs.
//        `mix run` starts the app itself; `--no-halt` keeps it serving.
//
// Token handling: webServer.env passes INTERNAL_API_TOKEN through from the
// runner's environment when present. Tokenless runs still exercise the
// fail-closed specs (auth-gated surfaces answer 503 by design) — the
// run is green only when the tokenless-degraded contracts are asserted,
// which is exactly what the affected specs encode.
// Boot-readiness gate (W252 run-3 finding: playwright's url probe passed
// while the app still answered 503 during warm-up, poisoning first-wave
// tests). After `mix run` is up, poll a REAL health probe until it returns
// 200 before handing the server to the suite:
//   - with INTERNAL_API_TOKEN: /internal-api/health (token-authenticated),
//     which is 200 only when DB + every liveness check pass;
//   - tokenless: `/` (always-200-when-up rendered page), because
//     /internal-api/health fail-closes to 503 without a token.
// The mix process stays in the foreground via `wait`, so playwright still
// sees a long-lived webServer command and tree-kills it on exit.
//
// Server stdout+stderr are redirected to a real file inside the BOOT
// (W299b/W310f: the mix VM terminates the whole runtime when it writes to a
// closed :standard_error — fd 2 closure in the launching session produced a
// byte-identical erl_crash.dump). Redirecting to /tmp/xaas-e2e-server.log
// binds fd 1/2 to a file, never a session/harness pipe, so losing the
// playwright pipe reader can never kill the server mid-suite.
//
// Port convention (W310f): the historical "kill all beams on :4000" cleanup
// is RETIRED — any concurrent kill of :4000 is a cross-lane SIGKILL channel.
// Concurrent lanes MUST lease distinct PW_PORT values instead of killing:
//   PW_PORT=4000 npx playwright test ... &
//   PW_PORT=4010 npx playwright test ... &
const BOOT = [
  'node ./e2e/global-setup.cjs --catalog',
  // W984fw: MIX_ENV is PINNED to dev here. An inherited MIX_ENV=test boots
  // the server against xaas_test with NO sandbox checkout, so any LiveView
  // write (e.g. next-read-ml pin click -> reader_live toggle_pin ->
  // Xaas.Actuation.run authority "liveview_librarian"/"toggle_pin")
  // COMMITTED foreign rows into xaas_test (W650h23 root cause). Dev DB is
  // fully seeded; the sandbox stays out of the picture.
  'PHX_SERVER=true MIX_ENV=dev PATH="$HOME/.asdf/shims:$PATH" mix run -e \'Application.put_env(:xaas, :marketplace_catalog_source, System.get_env("PW_MARKETPLACE_CATALOG"))\' --no-halt > /tmp/xaas-e2e-server.log 2>&1 & SRV=$!',
  `PROBE_URL=http://localhost:${PW_PORT}\${INTERNAL_API_TOKEN:+/internal-api/health}; OK=""; for i in $(seq 1 180); do CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 \${INTERNAL_API_TOKEN:+-H "Authorization: Bearer $INTERNAL_API_TOKEN"} "$PROBE_URL"); if [ "$CODE" = "200" ]; then OK=1; break; fi; sleep 1; done; [ -n "$OK" ] || { echo "e2e readiness probe never returned 200 (last=$CODE)" >&2; kill $SRV 2>/dev/null; exit 1; }`,
  'wait $SRV',
].join(" && ");

module.exports = defineConfig({
  testDir: "./e2e",
  timeout: 30_000,
  globalSetup: "./e2e/global-setup.cjs",
  webServer: {
    command: BOOT,
    port: PW_PORT,
    reuseExistingServer: true,
    timeout: 240_000,
    env: {
      PW_MARKETPLACE_CATALOG: MARKETPLACE_CATALOG_PATH,
      // The Phoenix endpoint itself binds via config/runtime.exs
      // `System.get_env("PORT") || "4000"` — PW_PORT alone would leave the
      // app on :4000 and the probe/tests on PW_PORT (eaddrinuse). Keep the
      // app's bind port and the probe/baseURL on the same leased port.
      PW_PORT: String(PW_PORT),
      PORT: String(PW_PORT),
      ...(process.env.INTERNAL_API_TOKEN
        ? { INTERNAL_API_TOKEN: process.env.INTERNAL_API_TOKEN }
        : {}),
    },
  },
  use: {
    // Real, already-running dev server (mix phx.server), not a mock.
    baseURL: process.env.PLAYWRIGHT_BASE_URL || PW_BASE_URL,
  },
});
