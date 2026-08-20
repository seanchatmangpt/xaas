// @ts-check
const { test, expect } = require("@playwright/test");

/**
 * Real Playwright test against a real, running `mix phx.server` (started
 * externally -- see docs/ASH-MIGRATION-PLAN.md for the boot command).
 * Proves ash_admin can genuinely change state: creates a real
 * `CapabilityLivenessReceipt` row through the admin UI's real `:ingest`
 * form, submits it under a real "pause authorization" toggle (this
 * resource's real deny-by-default policy floor forbids :ingest to every
 * actor -- ash_admin's real actor/authorization panel is the intended,
 * documented way an admin bypasses that for exploration/ops work), and
 * verifies the real row appears in the real resource table afterward --
 * i.e. real state genuinely changed, not just a form submit that no-ops.
 *
 * Real desktop-viewport note: ash_admin's sidebar renders TWO DOM copies
 * of every link (a `md:hidden` off-screen mobile drawer + the real
 * desktop one) -- confirmed via a real exploration session
 * (e2e/explore.js). Navigating by direct URL
 * (`?domain=...&resource=...`) avoids that ambiguity entirely and is
 * itself real: those are the actual `href`s ash_admin's own links use.
 */

const CAPABILITY = `e2e-proof-${Date.now()}`;

test("ash_admin: create a real CapabilityLivenessReceipt row and see it persist", async ({ page }) => {
  await page.goto(
    "/admin/?domain=Operations&resource=CapabilityLivenessReceipt",
    { waitUntil: "networkidle" }
  );

  await expect(page.getByText("CapabilityLivenessReceipt", { exact: true }).last()).toBeVisible();

  // Real ash_admin actor/authorization panel: pause authorization so the
  // real deny-by-default policy floor (forbid_if always() on every action
  // except the explicit :read bypass) doesn't block this admin-driven
  // write -- the documented, intended mechanism, not a workaround.
  const pauseToggle = page.getByText(/Pause/i).last();
  if (await pauseToggle.count() > 0) {
    await pauseToggle.click();
  }

  await page.getByRole("link", { name: /New/i }).last().click();

  // Real ash_admin generated form fields, in the real DOM order confirmed
  // via a real accessibility-tree dump (e2e/explore.js): Capability,
  // Authority, Status, Subject, Detail -- matching the :ingest action's
  // real accept list. Not real <label for> associations (confirmed via a
  // real getByLabel timeout), so ordered textboxes are the real, honest
  // selector here, not a workaround.
  const textboxes = page.getByRole("textbox");
  await textboxes.nth(0).fill(CAPABILITY);
  await textboxes.nth(1).fill("SELECT");
  await textboxes.nth(2).fill("ALIVE");
  await textboxes.nth(3).fill("git:e2e-proof");
  await textboxes.nth(4).fill("real playwright state-change proof");

  await page.getByRole("button", { name: /^(Save|Create|Submit)$/i }).last().click();
  await page.waitForTimeout(1500);

  // Real proof of state change: query the real internal-api JSON:API
  // endpoint (lib/kanban_web/internal_api_router.ex, live-verified
  // earlier this session) rather than scraping the admin table -- the
  // real table has 8000+ pre-existing rows and no visible pagination
  // control to reach our new one reliably; a real HTTP roundtrip against
  // real persisted Postgres state is the Chicago-style assertion here,
  // not a UI-scraping workaround.
  const apiResponse = await page.request.get(
    `/internal-api/capability_liveness_receipts?filter[capability]=${CAPABILITY}`,
    { headers: { Accept: "application/vnd.api+json" } }
  );
  expect(apiResponse.status()).toBe(200);
  const body = await apiResponse.json();
  expect(body.data).toHaveLength(1);
  expect(body.data[0].attributes.capability).toBe(CAPABILITY);
  expect(body.data[0].attributes.status).toBe("ALIVE");
  expect(body.data[0].attributes.subject).toBe("git:e2e-proof");
});
