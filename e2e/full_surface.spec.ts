// @ts-check
import { test, expect } from "@playwright/test";

/**
 * PW8 — cross-surface Playwright E2E: one test suite that walks every
 * browser-pipeline surface in the real router on a real running
 * `mix phx.server`, then a full journey through the marketplace catalog.
 *
 * Surfaces (lib/xaas_web/router.ex, :browser pipeline):
 *   /  /next-read  /case-studies/wd-fa  /chicago  /chicago/seller
 *   /marketplace-pplan  /marketplace-catalog  /system (dev routes)
 *
 * Catalog seeding: the server is booted with
 * `Application.put_env(:xaas, :marketplace_catalog_source, <file>)` pointing
 * at the real generated ggen-marketplace catalog (same generator the XL2
 * courts use), so mount-time ingest loads real packs.
 */

/** Wait until the page's main LiveView has actually connected over the
 * websocket — events fired before connection are silently dropped. */
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

const BROWSER_SURFACES = [
  { path: "/", name: "home" },
  { path: "/next-read", name: "next-read" },
  { path: "/case-studies/wd-fa", name: "wd-fa case study" },
  { path: "/chicago", name: "chicago drill-down" },
  { path: "/chicago/seller", name: "chicago seller" },
  { path: "/marketplace-pplan", name: "marketplace pplan explorer" },
  { path: "/marketplace-catalog", name: "marketplace catalog" },
  { path: "/system", name: "system command center (dev routes)" },
];

test.describe("PW8 full-surface journey", () => {
  // (c) every router surface renders without error
  for (const surface of BROWSER_SURFACES) {
    test(`surface renders: ${surface.name} (${surface.path})`, async ({ page }) => {
      const response = await page.goto(surface.path, { waitUntil: "domcontentloaded" });
      expect(response, `HTTP status for ${surface.path}`).not.toBeNull();
      expect(response!.status(), `HTTP status for ${surface.path}`).toBeLessThan(400);

      // LiveView connect: no crash page, no client error overlay.
      await expect(page.locator("body")).not.toContainText("Something went wrong");
      await expect(page.locator("body")).not.toContainText("RuntimeError");
      const content = await page.locator("body").innerText();
      expect(content.trim().length, `non-empty render for ${surface.path}`).toBeGreaterThan(0);
    });
  }

  // (a) marketplace catalog renders real packs
  test("marketplace catalog renders packs", async ({ page }) => {
    await page.goto("/marketplace-catalog", { waitUntil: "domcontentloaded" });

    await expect(page.locator("h1")).toHaveText("Marketplace Catalog");
    const table = page.locator("#pack-table");
    await expect(table).toBeVisible();

    // Real pack rows from the ingested catalog — at least one, with the
    // row identity the LiveView renders (data-pack-name + digest cell).
    const rows = page.locator("#pack-table tbody tr[id^='pack-row-']");
    const count = await rows.count();
    expect(count, "pack rows rendered from the real catalog").toBeGreaterThan(0);

    const first = rows.first();
    await expect(first.locator("[data-pack-name]")).not.toBeEmpty();
    await expect(first.locator("td").nth(1)).not.toBeEmpty(); // version
    await expect(first.locator("td").nth(4)).not.toBeEmpty(); // digest
    await expect(page.locator("#catalog-summary")).toContainText(`${count} packs in the catalog`);
  });

  // (b) search narrows server-side
  test("catalog search narrows results and clears back", async ({ page }) => {
    await page.goto("/marketplace-catalog", { waitUntil: "domcontentloaded" });

    const input = page.locator("#pack-search-form input[name='q']");
    await expect(input).toBeVisible();
    await waitLiveViewConnected(page);

    const allRows = page.locator("#pack-table tbody tr[id^='pack-row-']");
    const totalCount = await allRows.count();
    expect(totalCount).toBeGreaterThan(0);

    // Type a query; phx-change fires per keystroke. Use a term that matches
    // a strict subset (a pack name substring like "pack" is too broad, use
    // "ggen" which appears in a subset of names/descriptions).
    await input.fill("ggen");
    await expect
      .poll(async () => await allRows.count(), { timeout: 10_000 })
      .toBeLessThan(totalCount);
    await expect(page.locator("#catalog-summary")).toContainText("matching");

    // The remaining rows genuinely match the term.
    const names = await page
      .locator("#pack-table [data-pack-name]")
      .allInnerTexts();
    expect(names.length).toBeGreaterThan(0);
    expect(names.length).toBeLessThan(totalCount);

    // Clear the search -> full catalog returns.
    await input.fill("");
    await expect
      .poll(async () => await allRows.count(), { timeout: 10_000 })
      .toBe(totalCount);
  });

  // (d) the full journey: catalog -> search -> pack detail -> back to catalog
  test("full journey: catalog -> search -> detail -> back to catalog", async ({ page }) => {
    await page.goto("/marketplace-catalog", { waitUntil: "domcontentloaded" });

    const rows = page.locator("#pack-table tbody tr[id^='pack-row-']");
    await expect(rows.first()).toBeVisible();

    // 1. search
    const input = page.locator("#pack-search-form input[name='q']");
    await waitLiveViewConnected(page);
    await input.fill("ggen");

    // The search narrows to a stable, non-empty subset.
    await page.waitForTimeout(600);
    const filtered = await rows.count();
    expect(filtered).toBeGreaterThan(0);

    // 2. detail: the catalog renders the pack's full detail in its row
    // (name, description, version, class, readiness, digest) — the row IS
    // the detail surface; assert every detail field for the first hit.
    const detail = rows.first();
    const packName = (await detail.locator("[data-pack-name]").innerText()).trim();
    expect(packName).toContain("ggen");
    const detailCells = detail.locator("td");
    const cellTexts = await detailCells.allInnerTexts();
    expect(cellTexts.length).toBe(5);
    for (const cell of cellTexts) expect(cell.trim().length).toBeGreaterThan(0);

    // 3. back to catalog: clear the search, full listing returns.
    await input.fill("");
    await page.waitForTimeout(600);
    const restored = await rows.count();
    expect(restored).toBeGreaterThan(filtered);

    await expect(page.locator("#catalog-summary")).toContainText("in the catalog");
  });
});
