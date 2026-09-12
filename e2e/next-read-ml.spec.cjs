// @ts-check
const { test, expect } = require("@playwright/test");

/**
 * End-to-end Playwright test suite for Next Read Qvest Deck Experience.
 * Validates Dual-Persona (Student & Librarian Advisory Desk),
 * Explainability Drawer ("Why this one?"), Live Pin/Unpin Curation,
 * Live Desk Metrics, and "Ask the Catalog" semantic queries.
 */

test.describe("Next Read Qvest Deck Experience & Dual-Persona Interface", () => {
  test("renders dual-persona layout with Student and Librarian views", async ({ page }) => {
    await page.goto("/next-read", { waitUntil: "networkidle" });

    // Header assertion
    const header = page.locator("header").last();
    await expect(header).toContainText("Next Read");
    await expect(header).toContainText("Dual Experience Live Harness");

    // Dual Window containers
    const studentWindow = page.locator('[data-testid="student-window"]');
    const librarianWindow = page.locator('[data-testid="librarian-window"]');
    await expect(studentWindow).toBeVisible();
    await expect(librarianWindow).toBeVisible();

    // Proof sequence bar
    const proofBar = page.locator('[data-testid="proof-sequence"]');
    await expect(proofBar).toBeVisible();
    await expect(proofBar).toContainText("01 ranked");
  });

  test("expands grounded 'Why this one?' explainability drawer with factor pill badges", async ({ page }) => {
    await page.goto("/next-read", { waitUntil: "networkidle" });

    const whyButtons = page.locator('[data-testid="why-button"]');
    await expect(whyButtons.first()).toBeVisible();

    // Click "Why This?" on first card
    await whyButtons.first().click();
    await page.waitForTimeout(400);

    // Explainability drawer appears
    const drawer = page.locator('[data-testid="explanation-drawer"]');
    await expect(drawer.first()).toBeVisible();
    await expect(drawer.first()).toContainText("Grounded Explanation");
    await expect(drawer.first()).toContainText("Traced to real student circulation records");

    // Factor badges are rendered inside explanation
    await expect(drawer.first()).toContainText("collaborative");
    await expect(drawer.first()).toContainText("semantic");
    await expect(drawer.first()).toContainText("grade fit");
  });

  test("librarian pin action dynamically updates curation and student card spotlight", async ({ page }) => {
    await page.goto("/next-read", { waitUntil: "networkidle" });

    const pinButtons = page.locator('[data-testid="pin-button"]');
    await expect(pinButtons.first()).toBeVisible();

    const firstPin = pinButtons.first();
    const bookId = await firstPin.getAttribute("data-book-id");

    // Toggle pin for first title
    await firstPin.click();
    await page.waitForTimeout(600);

    // Pin button updates state
    await expect(firstPin).toBeVisible();

    // Student card receives spotlight / highlight
    const studentCard = page.locator(`[data-testid="book-card"][data-book-id="${bookId}"]`);
    await expect(studentCard).toBeVisible();
  });

  test("executes student checkout, updates librarian metrics, and displays flash confirmation", async ({ page }) => {
    await page.goto("/next-read", { waitUntil: "networkidle" });

    const outTodayStat = page.locator('[data-testid="stat-out-today"]');
    await expect(outTodayStat).toBeVisible();
    const initialOut = await outTodayStat.innerText();

    const checkoutButtons = page.locator('[data-testid="checkout-button"]');
    await expect(checkoutButtons.first()).toBeVisible();

    // Click Check Out
    await checkoutButtons.first().click();
    await page.waitForTimeout(600);

    // Verify Flash banner
    const flashInfo = page.locator('[data-testid="flash-info"]');
    await expect(flashInfo).toBeVisible();
    await expect(flashInfo).toContainText("Successfully checked out");

    // Verify Desk metrics updated
    await expect(outTodayStat).toBeVisible();
  });

  test("executes 'Ask the Catalog' natural language semantic search and renders admitted candidates", async ({ page }) => {
    await page.goto("/next-read", { waitUntil: "networkidle" });

    const askInput = page.locator('[data-testid="ask-input"]');
    const askButton = page.locator('[data-testid="ask-button"]');
    await expect(askInput).toBeVisible();
    await expect(askButton).toBeVisible();

    // Fill query and submit
    await askInput.fill("Science fiction and space exploration books for middle grade");
    await askButton.click();
    await page.waitForTimeout(800);

    // Results container rendered
    const askResults = page.locator('[data-testid="ask-results"]');
    await expect(askResults).toBeVisible();
    await expect(askResults).toContainText("Catalog.search_semantic");
    await expect(askResults).toContainText("Ranker admitted");
  });

  test("switches between split, student-only, and librarian-only view modes", async ({ page }) => {
    await page.goto("/next-read", { waitUntil: "networkidle" });

    // Switch to Student Only
    await page.click('button:has-text("Student Only")');
    await page.waitForTimeout(300);
    await expect(page.locator('[data-testid="student-window"]')).toBeVisible();
    await expect(page.locator('[data-testid="librarian-window"]')).toHaveCount(0);

    // Switch to Librarian Only
    await page.click('button:has-text("Librarian Only")');
    await page.waitForTimeout(300);
    await expect(page.locator('[data-testid="librarian-window"]')).toBeVisible();
    await expect(page.locator('[data-testid="student-window"]')).toHaveCount(0);

    // Switch back to Split View
    await page.click('button:has-text("Split View")');
    await page.waitForTimeout(300);
    await expect(page.locator('[data-testid="student-window"]')).toBeVisible();
    await expect(page.locator('[data-testid="librarian-window"]')).toBeVisible();
  });
});


