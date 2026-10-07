// @ts-check
const { test, expect } = require("@playwright/test");

/**
 * X1 gap close: the broader ash_admin read matrix, extending (without
 * touching) the existing ash-admin pair
 * (e2e/ash-admin-destroy.spec.cjs, e2e/ash-admin-state-change.spec.cjs).
 * Those two prove real state-change on ONE resource
 * (Operations.CapabilityLivenessReceipt); this spec proves the READ
 * surfaces render read-only across MORE of the admin surface:
 *
 *   1. the admin index renders (sidebar listing both real domains),
 *   2. the proven resource's index table renders read-only,
 *   3. a SECOND resource's index
 *      (Platform.WebhookDelivery — real domain from
 *      lib/xaas/platform.ex:11-17) renders read-only, and
 *   4. the record show panel renders read-only for a real row.
 *
 * All navigation is by direct URL — the same real hrefs ash_admin's own
 * links render — avoiding the off-screen-mobile-drawer duplicate-DOM
 * ambiguity the sibling specs document (e2e/explore.js finding).
 *
 * Route authority: lib/xaas_web/router.ex:302-306 —
 *   scope "/admin" do
 *     pipe_through(:browser)
 *     ash_admin("/")
 *   end
 * dev-only, guarded by the compile-time `dev_routes` flag
 * (config/dev.exs:106 sets it true), same gate as /dev/*.
 */

const ADMIN_BASE = "/admin/";
const PROVEN_RESOURCE_URL =
  "/admin/?domain=Operations&resource=CapabilityLivenessReceipt";
const SECOND_RESOURCE_URL =
  "/admin/?domain=Platform&resource=WebhookDelivery";

// Record show URL: ash_admin renders show links as
//   ?domain=..&resource=..&primary_key=<encoded id>
// (deps/ash_admin/lib/ash_admin/pages/page_live.ex:287-291). For a
// simple-typed (uuid) primary key the id goes in the URL verbatim
// (deps/ash_admin/lib/ash_admin/helpers.ex:116-127,
// encode_primary_key/1: single simple-typed pkey -> plain Map.get).
// We fetch a REAL id from real persisted Postgres via the real
// internal-api JSON:API endpoint — the same Chicago-style HTTP
// roundtrip pattern the sibling specs use — not from a fabricated row.
const AUTH_HEADERS = {
  Accept: "application/vnd.api+json",
  Authorization: `Bearer ${process.env.INTERNAL_API_TOKEN || ""}`,
};

test("admin index renders: both real domains present in the admin chrome", async ({
  page,
}) => {
  const response = await page.goto(ADMIN_BASE, { waitUntil: "networkidle" });
  expect(response && response.status()).toBe(200);

  // Real ash_admin chrome: the sidebar/top-nav lists domains and their
  // resources. Operations and Platform are both real domains of this app
  // (lib/xaas/operations.ex, lib/xaas/platform.ex:11-17).
  // A hidden collapsed-nav <span>Operations</span> exists in the ash_admin
  // chrome and is not visible at 1280x720; assert on a visible match only.
  await expect(
    page
      .getByText("Operations", { exact: true })
      .filter({ visible: true })
      .first(),
  ).toBeVisible();
  await expect(
    page
      .getByText("Platform", { exact: true })
      .filter({ visible: true })
      .first(),
  ).toBeVisible();

  // W171 fresh-diagnosis: the plain /admin index renders DOMAIN buttons
  // only; resource names never appear there (they render after a domain is
  // expanded, which the two sibling tests below prove on their real URLs).
  // The former CapabilityLivenessReceipt/WebhookDelivery asserts here
  // matched no real index node — asserting them on the index was a spec
  // bug, not an app gap.
});

test("proven resource index renders read-only with its real table", async ({
  page,
}) => {
  const response = await page.goto(PROVEN_RESOURCE_URL, {
    waitUntil: "networkidle",
  });
  expect(response && response.status()).toBe(200);

  await expect(
    page.getByText("CapabilityLivenessReceipt", { exact: true }).last(),
  ).toBeVisible();

  // Real read-only index table: ash_admin's generated table for the
  // resource's real attributes. The sibling specs confirm 8000+ real
  // rows exist, so a data row is present on the real server.
  const table = page.locator("table");
  await expect(table.first()).toBeVisible();
  // The ash_admin index is a LiveView: rows render after the websocket
  // connect, which can lag the initial networkidle on a cold server.
  await expect(
    page.locator("table tbody tr").first(),
  ).toBeVisible({ timeout: 15_000 });
});

test("second resource (Platform.WebhookDelivery) index renders read-only", async ({
  page,
}) => {
  const response = await page.goto(SECOND_RESOURCE_URL, {
    waitUntil: "networkidle",
  });
  expect(response && response.status()).toBe(200);

  await expect(page.getByText("WebhookDelivery", { exact: true }).last()).toBeVisible();

  // Real ash_admin index for the second domain: its generated table
  // renders (real rows from real webhook deliveries, or the genuine
  // zero-row table shell — an empty body is the failure, not an empty
  // table). This is a read-only court: no form interaction, no policy
  // pause toggle touched.
  await expect(page.locator("table").first()).toBeVisible();
});

test("record show panel renders read-only for a real persisted row", async ({
  page,
  request,
}) => {
  // Setup-free read: find a real CapabilityLivenessReceipt row via the
  // real internal-api endpoint (same pattern as the sibling specs).
  const apiResponse = await request.get(
    `/internal-api/capability_liveness_receipts`,
    { headers: AUTH_HEADERS },
  );
  expect(apiResponse.status()).toBe(200);
  const body = await apiResponse.json();
  expect(body.data.length).toBeGreaterThanOrEqual(1);
  const recordId = body.data[0].id;

  const response = await page.goto(
    `/admin/?domain=Operations&resource=CapabilityLivenessReceipt&primary_key=${recordId}`,
    { waitUntil: "networkidle" },
  );
  expect(response && response.status()).toBe(200);

  // Real ash_admin show panel: the record's identity renders (the show
  // header carries the resource name). W171 fresh-diagnosis: the show
  // panel renders the record's attributes as DISABLED FIELDS, not a
  // <table> (the error-context snapshot proves it: h1
  // CapabilityLivenessReceipt + disabled textboxes with the real persisted
  // values). Assert the real show-panel chrome; read-only: no destroy
  // button is clicked, no form filled.
  await expect(
    page.getByText("CapabilityLivenessReceipt", { exact: true }).last(),
  ).toBeVisible();
  // ash_admin renders the show panel's read-only attributes as disabled
  // fields (input/textarea); the panel also carries the record's Destroy
  // action link. Either real chrome proves the persisted record rendered.
  await expect(
    page.locator("main [disabled], main form [disabled]").first(),
  ).toBeVisible({ timeout: 15_000 });
});
