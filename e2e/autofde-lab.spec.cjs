// @ts-check
const { test, expect } = require("@playwright/test");

// autofde-lab StatusLive court (X3 gap close).
//
// Route authority: lib/xaas_web/router.ex —
//   if Application.compile_env(:xaas, :dev_routes) do
//     scope "/dev" do
//       live("/dashboards/autofde-lab", XaasWeb.AutofdeLab.StatusLive)
//
// The gate is a *compile-time* config flag (`Application.compile_env`),
// so it cannot be flipped from the test process or via env at request
// time. The spec therefore does not set anything: the Playwright
// webServer boots `mix phx.server` (MIX_ENV=dev, and
// config/dev.exs:106 sets `config :xaas, dev_routes: true`), so the
// route is compiled in on exactly the server this suite targets. If a
// future config flips dev_routes off, the route disappears and the
// `page.goto` below fails with the server's typed behavior: a 404 from
// Phoenix router (no matching route), not a disabled page.
//
// Read-only assertions on real server content only: no clicks that
// mutate, no data fabrication. The one interactive control on the page
// ("Refresh") is a read re-load of the same two real data sources
// (sibling autofde-lab docs/STATUS.md via Xaas.Autofde.StatusParser,
// and real Xaas.Platform.WebhookDelivery rows) — asserting its presence
// is enough; exercising it is not required to qualify rendering.

const AUTOFDE_LAB_ROUTE = "/dev/dashboards/autofde-lab";

test("autofde-lab dashboard renders real benchmark history panel", async ({
  page,
}) => {
  const response = await page.goto(AUTOFDE_LAB_ROUTE, {
    waitUntil: "domcontentloaded",
  });

  // dev server with dev_routes compiled in must serve it as a live page.
  // goto resolves null only on a download; either way it is not a 200 page.
  expect(response && response.status()).toBe(200);

  await expect(page).toHaveTitle(/.+/);
  await expect(
    page.getByRole("heading", { name: "autofde-lab benchmark history" }),
  ).toBeVisible();

  // The panel is either the real parsed STATUS.md passes or the typed
  // not-found banner — both are honest renders; an empty body is not.
  const passList = page.locator("ul li", { hasText: "Pass" });
  const notFoundBanner = page.getByText(
    /autofde-lab not found at .* -- checkout the sibling repo/,
  );
  await expect(passList.or(notFoundBanner).first()).toBeVisible();
});

test("autofde-lab dashboard renders real webhook deliveries panel", async ({
  page,
}) => {
  await page.goto(AUTOFDE_LAB_ROUTE, { waitUntil: "domcontentloaded" });

  await expect(
    page.getByRole("heading", { name: "xaas platform: recent webhook deliveries" }),
  ).toBeVisible();

  // Real table with the four real columns from StatusLive.render/1.
  for (const column of ["Event type", "Status", "Attempts", "Inserted at"]) {
    await expect(
      page.getByRole("columnheader", { name: column }),
    ).toBeVisible();
  }

  // Either real delivery rows or the typed empty state — never a blank table.
  const deliveryRows = page.locator("table tbody tr").filter({
    has: page.locator("td"),
  });
  const emptyState = page.getByText("No webhook deliveries yet.");
  // The typed empty state ("No webhook deliveries yet.") resolves to both
  // the row and its cell, so the .or() chain is ambiguous without pinning;
  // either branch's first match is the honest render.
  await expect(deliveryRows.first().or(emptyState).first()).toBeVisible();

  // Refresh control present (read-only re-load of the same data sources).
  await expect(page.getByRole("button", { name: "Refresh" })).toBeVisible();
});
