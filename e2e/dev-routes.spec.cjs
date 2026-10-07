// @ts-check
const { test, expect } = require("@playwright/test");

/**
 * X1 gap close: dev-gated surface courts (`/dev/*` + `/admin`).
 *
 * Route authority: lib/xaas_web/router.ex:271-306 —
 *   if Application.compile_env(:xaas, :dev_routes) do
 *     scope "/dev" do
 *       pipe_through(:browser)
 *       live_dashboard("/dashboard", metrics: XaasWeb.Telemetry)
 *       forward("/mailbox", Plug.Swoosh.MailboxPreview)
 *       live("/dashboards/autofde-lab", XaasWeb.AutofdeLab.StatusLive)
 *     end
 *     ...
 *     scope "/admin" do
 *       pipe_through(:browser)
 *       ash_admin("/")
 *     end
 *   end
 *
 * The gate is a *compile-time* config flag (`Application.compile_env`),
 * so it cannot be flipped from the test process or via env at request
 * time — the same typed-404 documentation pattern e2e/autofde-lab.spec.cjs
 * uses: this spec sets nothing. The Playwright webServer boots
 * `mix phx.server` (MIX_ENV=dev; config/dev.exs:106 sets
 * `config :xaas, dev_routes: true`), so the routes are compiled in on
 * exactly the server this suite targets. If a future config flips
 * dev_routes off, these routes disappear and each `page.goto` below
 * fails with the server's typed behavior — a Phoenix 404 (no matching
 * route), not a disabled page.
 *
 * Read-only assertions on real server content only: no clicks that
 * mutate, no data fabrication, no authorization toggles.
 */

test("/dev/dashboard: Phoenix LiveDashboard renders its real home page", async ({
  page,
}) => {
  const response = await page.goto("/dev/dashboard", {
    waitUntil: "domcontentloaded",
  });
  expect(response && response.status()).toBe(200);

  // Real LiveDashboard chrome: the brand appears in the nav and the home
  // page renders its real "Dashboard" heading.
  // "Phoenix LiveDashboard" appears twice (h1 brand + footer credit);
  // the h1 is the render-under-test, so pin to the first (nav/h1) match.
  await expect(page.getByText("Phoenix LiveDashboard").first()).toBeVisible();
  // Strict-mode: "Dashboard" appears in multiple heading/text nodes
  // (nav brand, page h1, section headings). Pin to the page's real h1.
  await expect(
    page.getByRole("heading", { name: "Dashboard" }).first(),
  ).toBeVisible();

  // Real home-page sections from Phoenix.LiveDashboard.PageBuilder. W171
  // fresh-diagnosis: this LiveDashboard's home page renders the system
  // sections (Run queues / System information / System limits) and the
  // metric groups as headings named by metric family (Phoenix / Ecto /
  // Elixir), NOT literal "Request metrics"/"Ecto metrics" section titles —
  // the page was rendering all along; the old regex matched no real node.
  // Assert on real home headings (a blank/unmounted page is the failure).
  await expect(
    page.getByRole("heading", { name: "Run queues" }).first(),
  ).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "System information" }).first(),
  ).toBeVisible();
});

test("/admin: ash_admin mount renders under the dev server", async ({
  page,
}) => {
  const response = await page.goto("/admin", { waitUntil: "networkidle" });
  expect(response && response.status()).toBe(200);

  // Real ash_admin chrome (same assertions as the read-matrix spec's
  // first court): the sidebar lists real domains of this app.
  // A hidden collapsed-nav <span>Operations</span> exists in the ash_admin
  // chrome and is not visible at 1280x720; assert on a visible match only.
  await expect(
    page
      .getByText("Operations", { exact: true })
      .filter({ visible: true })
      .first(),
  ).toBeVisible();
  // W171 fresh-diagnosis: the plain /admin index renders domain buttons
  // only — resource names (CapabilityLivenessReceipt) appear after a
  // domain is expanded, so assert the expanded Operations resource list
  // via its real URL instead of expecting a resource name on the index.
  const opsPage = await page.goto(
    "/admin/?domain=Operations&resource=CapabilityLivenessReceipt",
    { waitUntil: "networkidle" },
  );
  expect(opsPage && opsPage.status()).toBe(200);
  await expect(
    page.getByText("CapabilityLivenessReceipt", { exact: true }).last(),
  ).toBeVisible();
});
