// @ts-check
const { test, expect } = require("@playwright/test");

/**
 * End-to-end Playwright test suite for the Next Read recommendation interface.
 * Validates Petal Components (<.card>, <.badge>, <.button>, <.alert>) integrated
 * with Ash Framework Library domain and real Postgres seed data.
 */

test.describe("Next Read ML Recommendation Interface with Petal Components", () => {
  test("renders Petal Components (<.card>, <.badge>) with 6-factor ML recommendations", async ({ page }) => {
    await page.goto("/next-read", { waitUntil: "networkidle" });

    // Heading assertion
    await expect(page.locator("h1")).toHaveText("Next Read");

    // Petal Grid Container
    const grid = page.locator('[data-testid="recommendations-grid"]');
    await expect(grid).toBeVisible();

    // Verify Petal Cards are rendered
    const bookCards = page.locator('[data-testid="book-card"]');
    const count = await bookCards.count();
    expect(count).toBeGreaterThan(0);

    // Verify Petal Badges on the first card
    const firstCard = bookCards.first();
    const title = firstCard.locator('[data-testid="book-title"]');
    await expect(title).toBeVisible();

    // Petal Match Percentage Badge
    const matchPct = firstCard.locator('[data-testid="match-percentage"]');
    await expect(matchPct).toBeVisible();
    await expect(matchPct).toContainText("% Match");

    // Petal Button for checkout
    const checkoutBtn = firstCard.locator('[data-testid="checkout-button"]');
    await expect(checkoutBtn).toBeVisible();
    await expect(checkoutBtn).toHaveAttribute("phx-click", "checkout_book");
  });

  test("dynamically updates ML recommendations on student grade change via LiveView", async ({ page }) => {
    await page.goto("/next-read", { waitUntil: "networkidle" });

    const gradeSelect = page.locator("#grade");
    await expect(gradeSelect).toBeVisible();

    // Change grade to Grade 8
    await gradeSelect.selectOption("8");

    // Wait for LiveView patch update
    await page.waitForTimeout(500);

    const bookCards = page.locator('[data-testid="book-card"]');
    await expect(bookCards.first()).toBeVisible();

    // Confirm grade selector reflects selection
    await expect(gradeSelect).toHaveValue("8");
  });

  test("executes checkout action, renders Petal <.alert> flash, and updates button state", async ({ page }) => {
    await page.goto("/next-read", { waitUntil: "networkidle" });

    const checkoutButtons = page.locator('[data-testid="checkout-button"]');
    await expect(checkoutButtons.first()).toBeVisible();
    const initialCount = await checkoutButtons.count();
    expect(initialCount).toBeGreaterThan(0);

    const firstBtn = checkoutButtons.first();
    const buttonText = await firstBtn.innerText();
    expect(buttonText).toContain("Checkout");

    // Click Petal checkout button
    await firstBtn.click();

    // Wait for LiveView patch and Ash transaction completion
    await page.waitForTimeout(600);

    // Verify Petal Alert banner or updated state is displayed
    const flashAlert = page.locator('[data-testid="flash-info"], .alert, [role="alert"]');
    await expect(flashAlert.first()).toBeVisible();
    const alertText = await flashAlert.first().innerText();
    expect(alertText).toContain("Successfully checked out");
  });

  // NOTE: reader_live.ex (mount/4, XaasWeb.NextRead.ReaderLive) assigns
  // `:selected_genre` on mount (defaulting to "all"), but as of this session
  // there is no genre `<select>`/filter control rendered in the template and
  // no "change_genre"/"filter_genre" handle_event clause wired to it -- the
  // assign is currently unused by the view. Per this task's own instruction
  // ("if the UI supports a genre selector"), no genre-filter UI exists to
  // exercise yet, so no genre-filter test is added here. Genre *badges* are
  // rendered read-only per book (`.badge` per `rec.book.genres`) and are
  // covered indirectly by the rendering test above.

  test("shows disabled checkout state for a book with zero available copies", async ({ page }) => {
    await page.goto("/next-read", { waitUntil: "networkidle" });

    // Grade 8 recommendations include the real seeded zero-availability book
    // ("The Understudy's Secret", available_copies: 0 -- lib/xaas/dev_seeds.ex)
    // so switching to Grade 8 surfaces it deterministically without relying
    // on default sort order at Grade 3.
    const gradeSelect = page.locator("#grade");
    await expect(gradeSelect).toBeVisible();
    await gradeSelect.selectOption("8");
    await page.waitForTimeout(500);

    const bookCards = page.locator('[data-testid="book-card"]');
    await expect(bookCards.first()).toBeVisible();

    const zeroCopyCard = bookCards.filter({
      has: page.locator('[data-testid="checkout-button-disabled"]'),
    });
    await expect(zeroCopyCard.first()).toBeVisible();

    const disabledBtn = zeroCopyCard.first().locator('[data-testid="checkout-button-disabled"]');
    await expect(disabledBtn).toBeVisible();
    await expect(disabledBtn).toBeDisabled();

    const btnText = await disabledBtn.innerText();
    expect(btnText).toContain("Checked Out");
    expect(btnText).toContain("0 available");

    // The zero-copy card must not also render the active checkout button.
    const activeBtnInSameCard = zeroCopyCard.first().locator('[data-testid="checkout-button"]');
    await expect(activeBtnInSameCard).toHaveCount(0);
  });

  test("active checkout buttons remain enabled alongside a zero-availability book", async ({ page }) => {
    await page.goto("/next-read", { waitUntil: "networkidle" });

    const gradeSelect = page.locator("#grade");
    await gradeSelect.selectOption("8");
    await page.waitForTimeout(500);

    // Multi-book-availability scenario: at least one book with copies > 0
    // renders the enabled checkout button, and it is not disabled, even
    // while a zero-copy book on the same grid renders the disabled variant.
    const enabledButtons = page.locator('[data-testid="checkout-button"]');
    const disabledButtons = page.locator('[data-testid="checkout-button-disabled"]');

    await expect(disabledButtons.first()).toBeVisible();

    const enabledCount = await enabledButtons.count();
    expect(enabledCount).toBeGreaterThan(0);

    for (let i = 0; i < enabledCount; i++) {
      await expect(enabledButtons.nth(i)).toBeEnabled();
      const text = await enabledButtons.nth(i).innerText();
      expect(text).toContain("Checkout");
      expect(text).not.toContain("Checked Out");
    }
  });
});

