// @ts-check
import { test, expect } from "@playwright/test";

/**
 * PW3 — Playwright E2E over the marketplace catalog surface
 * (lib/xaas_web/live/marketplace_catalog_live.ex) on a real running
 * `mix phx.server`, seeded from the REAL generated ggen-marketplace catalog
 * (`python3 scripts/marketplace.py catalog` in /Users/sac/ggen-marketplace,
 * written to a temp file and configured via
 * `Application.put_env(:xaas, :marketplace_catalog_source, file)` before the
 * endpoint boots, so the LiveView's process-local mount-time ingest loads the
 * real packs).
 *
 * Courts:
 *   (a) the pack table renders over the ingested catalog;
 *   (b) searching "aaif" narrows to the matching real pack(s);
 *   (c) the rendered pack count equals the ingested catalog's pack count;
 *   (d) the pack detail fields (name / version / digest) render for a pack.
 */

/** Wait until the LiveView has connected over the websocket — phx-change
 * events fired before connection are silently dropped. */
async function waitLiveViewConnected(page: import("@playwright/test").Page) {
  await page.waitForLoadState("networkidle");
  await page.waitForFunction(
    () => {
      const root = document.querySelector<HTMLElement>("[data-phx-session]");
      return !!root && root.classList.contains("phx-connected");
    },
    null,
    { timeout: 15_000 },
  );
}

test.beforeEach(async ({ page }) => {
  await page.goto("/marketplace-catalog", { waitUntil: "domcontentloaded" });
});

test("(a) the pack table renders over the real ingested catalog", async ({
  page,
}) => {
  await expect(page.locator("h1")).toHaveText("Marketplace Catalog");

  const table = page.locator("#pack-table");
  await expect(table).toBeVisible();

  const rows = page.locator("#pack-table tbody tr[id^='pack-row-']");
  await expect(rows.first()).toBeVisible();

  // Header contract: Name / Version / Class / Readiness / Digest.
  const headers = (await page.locator("#pack-table thead th").allInnerTexts()).map(
    (t) => t.trim().toLowerCase(),
  );
  expect(headers).toEqual(["name", "version", "class", "readiness", "digest"]);

  // No typed ingest refusal row.
  await expect(page.locator("#ingest-refusal")).toHaveCount(0);
});

test("(b) searching \"aaif\" narrows to the matching real pack", async ({
  page,
}) => {
  await waitLiveViewConnected(page);

  const input = page.locator("#pack-search-form input[name='q']");
  const rows = page.locator("#pack-table tbody tr[id^='pack-row-']");
  const totalCount = await rows.count();
  expect(totalCount).toBeGreaterThan(0);

  await input.fill("aaif");

  await expect
    .poll(async () => await rows.count(), { timeout: 10_000 })
    .toBe(1);

  await expect(page.locator("#catalog-summary")).toContainText(
    'matching “aaif”',
  );

  // The single remaining row is the real AAIF pack.
  const name = (
    await page.locator("#pack-table [data-pack-name]").innerText()
  ).trim();
  expect(name).toBe("aaif-vanilla-pack");
});

test("(c) rendered pack count equals the ingested catalog pack count", async ({
  page,
}) => {
  const rows = page.locator("#pack-table tbody tr[id^='pack-row-']");
  await expect(rows.first()).toBeVisible();

  const rendered = await rows.count();
  expect(rendered).toBeGreaterThan(0);

  // The catalog summary is the LiveView's own count over the same read path.
  await expect(page.locator("#catalog-summary")).toHaveText(
    new RegExp(`^${rendered} packs? in the catalog$`),
  );

  // And that count matches the ingested source catalog exactly.
  const expected = Number(process.env.PW3_EXPECTED_PACK_COUNT ?? "0");
  expect(expected, "PW3_EXPECTED_PACK_COUNT must be set to the real count").toBeGreaterThan(0);
  expect(rendered).toBe(expected);
});

test("(d) pack detail fields (name / version / digest) render", async ({
  page,
}) => {
  await waitLiveViewConnected(page);

  // Detail navigation: click a pack name in the table to open the detail
  // surface; the catalog's detail surface for a pack is its full row, so the
  // journey is search -> read the detail fields of the hit.
  const input = page.locator("#pack-search-form input[name='q']");
  await input.fill("aaif");
  const rows = page.locator("#pack-table tbody tr[id^='pack-row-']");
  await expect.poll(async () => await rows.count(), { timeout: 10_000 }).toBe(1);

  const detail = rows.first();
  const name = (await detail.locator("[data-pack-name]").innerText()).trim();
  const version = (await detail.locator("td").nth(1).innerText()).trim();
  const digest = (await detail.locator("td").nth(4).innerText()).trim();

  expect(name).toBe("aaif-vanilla-pack");
  expect(version).toBe("0.3.0");
  expect(digest).toMatch(/^sha256:[0-9a-f]{16}/); // truncated to 16 hex chars + ellipsis by the LiveView
  await expect(page.locator("#catalog-summary")).toContainText("1 pack matching");
});
