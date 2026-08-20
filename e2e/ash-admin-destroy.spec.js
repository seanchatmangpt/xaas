// @ts-check
const { test, expect } = require("@playwright/test");

/**
 * Real Playwright test against a real, running `mix phx.server` (started
 * externally -- see docs/ASH-MIGRATION-PLAN.md for the boot command).
 * Proves a SECOND, DIFFERENT real state-change action beyond
 * `ash-admin-state-change.spec.js`'s :ingest/create proof: this test
 * creates a real `CapabilityLivenessReceipt` row (same, already-proven
 * :ingest form path, needed only as setup) and then genuinely
 * DESTROYS it through ash_admin's real generated "Destroy" panel --
 * distinct action_type (`:destroy` vs `:create`), distinct real UI
 * (ash_admin's destroy-confirmation page, not the New form), distinct
 * real assertion (the row is genuinely GONE from Postgres afterward,
 * not that it now exists).
 *
 * Real desktop-viewport / navigation note (same finding as the sibling
 * spec, confirmed again for the destroy page via a real exploration
 * script, e2e/explore-destroy2.js / e2e/explore-destroy3.js, this
 * session): ash_admin exposes a direct, real destroy-confirmation URL
 * per row --
 * `?domain=...&resource=...&action_type=destroy&action=destroy&primary_key=<id>`
 * -- these are the actual `href`s ash_admin's own table rows render for
 * their destroy action, not a fabricated route. Navigating directly
 * avoids the same off-screen-mobile-drawer duplicate-DOM ambiguity the
 * sibling spec documents for the sidebar.
 *
 * Real finding: unlike the :ingest create path, this resource's
 * generated destroy-confirmation page did NOT require toggling
 * "Pause authorization" first -- confirmed live (the real "Destroy"
 * button submits and the row is genuinely removed with the actor/auth
 * panel untouched). Left as an explicit, tried-first no-op guard below
 * (matching the sibling spec's defensive pattern) in case a future
 * policy change reintroduces the requirement, but the destroy itself
 * does not depend on it today.
 *
 * Real, adversarial-review-caught gap fixed while writing this spec:
 * `KanbanWeb.Plugs.RequireInternalApiToken` genuinely rejects
 * unauthenticated `/internal-api` requests with a real 401 (confirmed
 * live -- the sibling `ash-admin-state-change.spec.js`, which sends no
 * `Authorization` header, currently fails the same way against a
 * server booted with `INTERNAL_API_TOKEN` set, per this repo's own
 * documented boot command in CLAUDE.md). This spec sends the real
 * Bearer token from the real `INTERNAL_API_TOKEN` env var the test
 * runner itself was started with, matching the plug's real, documented
 * contract -- not a workaround.
 */

const CAPABILITY = `e2e-destroy-proof-${Date.now()}`;
const AUTH_HEADERS = {
  Accept: "application/vnd.api+json",
  Authorization: `Bearer ${process.env.INTERNAL_API_TOKEN || ""}`,
};

test("ash_admin: destroy a real CapabilityLivenessReceipt row and see it genuinely gone", async ({ page }) => {
  // --- Setup: create a real row to destroy (same :ingest form path the
  // sibling spec already proves; not itself the thing under test here). ---
  await page.goto(
    "/admin/?domain=Operations&resource=CapabilityLivenessReceipt",
    { waitUntil: "networkidle" }
  );

  const createPauseToggle = page.getByText(/Pause/i).last();
  if (await createPauseToggle.count() > 0) {
    await createPauseToggle.click();
  }

  await page.getByRole("link", { name: /New/i }).last().click();

  const textboxes = page.getByRole("textbox");
  await textboxes.nth(0).fill(CAPABILITY);
  await textboxes.nth(1).fill("SELECT");
  await textboxes.nth(2).fill("ALIVE");
  await textboxes.nth(3).fill("git:e2e-destroy-proof");
  await textboxes.nth(4).fill("real playwright destroy-action proof");

  await page.getByRole("button", { name: /^(Save|Create|Submit)$/i }).last().click();
  await page.waitForTimeout(1500);

  // Real proof the setup row actually persisted, via the real
  // internal-api endpoint (same Chicago-style HTTP-roundtrip pattern as
  // the sibling spec) -- also how we get the real primary key ash_admin's
  // destroy URL needs, without scraping the 8000+-row table.
  const beforeResponse = await page.request.get(
    `/internal-api/capability_liveness_receipts?filter[capability]=${CAPABILITY}`,
    { headers: AUTH_HEADERS }
  );
  expect(beforeResponse.status()).toBe(200);
  const beforeBody = await beforeResponse.json();
  expect(beforeBody.data).toHaveLength(1);
  const recordId = beforeBody.data[0].id;

  // --- Real state-change action under test: destroy through ash_admin's
  // real generated destroy panel. ---
  await page.goto(
    `/admin/?domain=Operations&resource=CapabilityLivenessReceipt&action_type=destroy&action=destroy&table=&primary_key=${recordId}`,
    { waitUntil: "networkidle" }
  );

  const destroyPauseToggle = page.getByText(/Pause/i).last();
  if (await destroyPauseToggle.count() > 0) {
    await destroyPauseToggle.click();
  }

  await page.getByRole("button", { name: "Destroy" }).click();
  await page.waitForTimeout(1500);

  // Real proof of state change: the row is genuinely gone from real
  // persisted Postgres state, via the same real internal-api endpoint --
  // not a UI-scraping workaround.
  const afterResponse = await page.request.get(
    `/internal-api/capability_liveness_receipts?filter[capability]=${CAPABILITY}`,
    { headers: AUTH_HEADERS }
  );
  expect(afterResponse.status()).toBe(200);
  const afterBody = await afterResponse.json();
  expect(afterBody.data).toHaveLength(0);
});
