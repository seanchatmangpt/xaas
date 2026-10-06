// @ts-check
const { test, expect } = require("@playwright/test");

// Smoke court: the real Phoenix app serves a rendered page at /.
test("root page renders", async ({ page }) => {
  await page.goto("/", { waitUntil: "domcontentloaded" });
  await expect(page).toHaveTitle(/.+/);
  await expect(page.locator("body")).not.toBeEmpty();
});
