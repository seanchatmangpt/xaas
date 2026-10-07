// @ts-check
const { test, expect } = require("@playwright/test");

/**
 * W5 (X3) — interaction-depth courts over the three render-only browser
 * surfaces on a real running `mix phx.server`:
 *
 *   /chicago          -> XaasWeb.Chicago.DrillDownLive
 *                        (lib/xaas_web/live/chicago/drill_down_live.ex)
 *   /chicago/seller   -> XaasWeb.Chicago.SellerLive
 *                        (lib/xaas_web/live/chicago/seller_live.ex)
 *   /marketplace-pplan-> XaasWeb.MarketplacePplanExplorerLive
 *                        (lib/xaas_web/live/marketplace_pplan_explorer_live.ex)
 *
 * Seed requirement: NONE of these surfaces reads the database.
 *   - Both Chicago surfaces render only the committed projection artifacts
 *     under priv/chicago/ (chicago.machine.json, chicago.executive.json) via
 *     Xaas.Chicago / Xaas.Chicago.View; the assertions below are bound to the
 *     values in those committed artifacts.
 *   - /marketplace-pplan parses the committed ontology
 *     priv/gcp/marketplace_lifecycle.ttl at mount.
 *   The only falsifier caveat: if `mix chicago.render` regenerates the
 *   projection artifacts with different content, the Chicago-specific literal
 *   assertions must be regenerated with them.
 *
 * Conventions follow e2e/marketplace.spec.ts: real server, data-driven
 * content assertions bound to known real values, and driven interactions
 * (phx-click / phx-change) with asserted state change — not visibility-only.
 */

/** Wait until the LiveView has connected over the websocket — phx-click and
 * phx-change events fired before connection are silently dropped. */
/** @param {import("@playwright/test").Page} page */
async function waitLiveViewConnected(page) {
  await page.waitForLoadState("networkidle");
  await page.waitForFunction(
    () => {
      const root = document.querySelector("[data-phx-session]");
      return !!root && root.classList.contains("phx-connected");
    },
    null,
    { timeout: 15_000 },
  );
}

test.describe("/chicago — layer drill-down (DrillDownLive)", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/chicago", { waitUntil: "domcontentloaded" });
    await waitLiveViewConnected(page);
  });

  test("renders the real subject and business outcome from the machine projection", async ({
    page,
  }) => {
    await expect(page.locator('[data-testid="chicago-root"]')).toBeVisible();

    // The exact subject literal from priv/chicago/chicago.machine.json.
    await expect(page.locator('[data-testid="subject"]')).toHaveText(
      "urn:chicago:agentic-payment:purchase-001",
    );

    // Business outcome folds the executive narrative headline and the
    // deliveryState.overallStanding ("UNKNOWN" — no receipt bound yet).
    const outcome = page.locator('[data-testid="business-outcome"]');
    await expect(outcome).toBeVisible();
    await expect(outcome).toContainText(
      "one exact Agentic Payments subject, projected across every ecosystem layer",
    );
    await expect(
      page.locator('[data-testid="business-outcome-standing"]'),
    ).toHaveText("standing: UNKNOWN");

    // No typed refusal banner: the committed artifacts load clean.
    await expect(page.locator('[data-testid="projection-blocked"]')).toHaveCount(0);
  });

  test("renders exactly the 10 contract layers with UNKNOWN/CANDIDATE standings", async ({
    page,
  }) => {
    const rows = page.locator('[data-testid^="layer-row-"]');
    await expect(rows).toHaveCount(10);

    // 10 == required count: the layer-count guard must NOT render, and no
    // layer renders as a typed absence row (all 10 are in the projection).
    await expect(page.locator('[data-testid="layer-count-guard"]')).toHaveCount(0);
    await expect(page.locator('[data-testid^="layer-absence-"]')).toHaveCount(0);

    // Spot-check three rows in contract order with their machine-projection
    // labels (the view renders layer["label"], not a hardcoded literal).
    await expect(page.locator('[data-testid="layer-select-sjira"]')).toHaveText(
      "Semantic Jira requirement graph",
    );
    await expect(page.locator('[data-testid="layer-select-pplan"]')).toHaveText(
      "ash_pplan and ferroplan planning",
    );
    await expect(page.locator('[data-testid="layer-select-marketplace"]')).toHaveText(
      "ggen-marketplace deterministic Chicago renderer",
    );

    // Standing law R8: every layer standing is the model value UNKNOWN with a
    // CANDIDATE lifecycle badge until a real receipt binds observed execution.
    for (const id of ["sjira", "pplan", "marketplace"]) {
      await expect(
        page.locator(`[data-testid="layer-standing-${id}"]`),
      ).toHaveText("UNKNOWN");
      await expect(
        page.locator(`[data-testid="layer-lifecycle-${id}"]`),
      ).toHaveText("CANDIDATE");
    }
  });

  test("selecting a layer opens its drill-down panel, then re-selecting swaps it", async ({
    page,
  }) => {
    // No panel before any selection.
    await expect(page.locator('[data-testid="layer-panel"]')).toHaveCount(0);

    // Drive the phx-click on the sjira row.
    await page.locator('[data-testid="layer-select-sjira"]').click();

    const panel = page.locator('[data-testid="layer-panel"]');
    await expect(panel).toBeVisible();
    await expect(page.locator('[data-testid="panel-title"]')).toHaveText(
      "Semantic Jira requirement graph",
    );
    await expect(page.locator('[data-testid="panel-id"]')).toHaveText("sjira");
    // what_happened folds the machine layer's capability/repository scope.
    await expect(page.locator('[data-testid="panel-what-happened"]')).toContainText(
      "capability sjira:goal-graph declared in scope seanchatmangpt/ggen_igniter",
    );
    await expect(page.locator('[data-testid="panel-standing"]')).toHaveText("UNKNOWN");
    await expect(page.locator('[data-testid="panel-lifecycle"]')).toHaveText("CANDIDATE");
    // No receiptRefs in the committed projection -> typed no-receipt note.
    await expect(page.locator('[data-testid="panel-no-receipt"]')).toContainText(
      "NO RECEIPT",
    );
    await expect(page.locator('[data-testid="panel-receipt"]')).toHaveCount(0);

    // Real state change: select a different layer; the panel swaps to it.
    await page.locator('[data-testid="layer-select-marketplace"]').click();
    await expect(page.locator('[data-testid="panel-title"]')).toHaveText(
      "ggen-marketplace deterministic Chicago renderer",
    );
    await expect(page.locator('[data-testid="panel-id"]')).toHaveText("marketplace");
    // The panel no longer shows the sjira content.
    await expect(page.locator('[data-testid="panel-what-happened"]')).not.toContainText(
      "sjira:goal-graph",
    );
  });
});

test.describe("/chicago/seller — executive projection (SellerLive)", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/chicago/seller", { waitUntil: "domcontentloaded" });
    await waitLiveViewConnected(page);
  });

  test("renders the executive header, narrative and authority over the committed executive JSON", async ({
    page,
  }) => {
    await expect(page.locator('[data-testid="chicago-seller-root"]')).toBeVisible();

    // No typed BLOCKED banner: the executive artifact loads clean.
    await expect(page.locator('[data-testid="chicago-blocked"]')).toHaveCount(0);

    await expect(page.locator('[data-testid="chicago-header-subject"]')).toHaveText(
      "urn:chicago:agentic-payment:purchase-001",
    );
    await expect(page.locator('[data-testid="chicago-authority-claim"]')).toContainText(
      "authorityClaim: NONE",
    );
    await expect(
      page.locator('[data-testid="chicago-generator-identity"]'),
    ).not.toBeEmpty();

    // 4 committed source digests render with path + sha256.
    const digests = page.locator('[data-testid^="chicago-source-digest-"]');
    await expect(digests).toHaveCount(4);
    await expect(digests.first()).toContainText("sha256:");

    // Narrative sections are the committed projection prose, not placeholder.
    await expect(page.locator('[data-testid="chicago-headline"]')).toContainText(
      "XaaS v26.10.1 Chicago ecosystem demo",
    );
    await expect(
      page.locator('[data-testid="chicago-customer-problem"]'),
    ).toBeVisible();
    await expect(
      page.locator('[data-testid="chicago-desired-outcome"]'),
    ).toBeVisible();
    await expect(page.locator('[data-testid="chicago-semantic-path"]')).toBeVisible();
  });

  test("renders 10 candidate cards, 2 successor cards, empty demonstrated list", async ({
    page,
  }) => {
    const caps = page.locator('[data-testid^="chicago-capability-"]').filter({
      has: page.locator('[data-testid^="chicago-capability-state-"]'),
    });
    // 12 machine layers (10 required + wasm4pm/castle successors).
    await expect(caps).toHaveCount(12);

    // demonstrated: [] -> required-layer chips read "candidate"; the
    // wasm4pm/castle successors render the typed "successor" chip
    // (Xaas.Chicago.Layer @successor_ids, seller_live.ex
    // capability_state/2: role == "successor" -> "successor").
    for (const id of ["sjira", "pplan", "marketplace"]) {
      await expect(
        page.locator(`[data-testid="chicago-capability-state-${id}"]`),
      ).toHaveText("candidate");
    }
    for (const id of ["wasm4pm", "castle"]) {
      await expect(
        page.locator(`[data-testid="chicago-capability-state-${id}"]`),
      ).toHaveText("successor");
    }
    await expect(
      page.locator('[data-testid="chicago-capability-state-marketplace"]'),
    ).toHaveText("candidate");

    await expect(
      page.locator('[data-testid="chicago-demonstrated-empty"]'),
    ).toHaveText("nothing yet demonstrated on this subject");
    await expect(
      page.locator('li[data-testid^="chicago-demonstrated-"]'),
    ).toHaveCount(0);

    // Candidate-partial scenarios: 1 positive + 9 negative from the JSON.
    await expect(
      page.locator('[data-testid="chicago-scenarios-positive-count"]'),
    ).toHaveText("1");
    await expect(
      page.locator('[data-testid="chicago-scenarios-negative-count"]'),
    ).toHaveText("9");
    await expect(
      page.locator('[data-testid="chicago-scenario-CHI-CASE-001"]'),
    ).toBeVisible();
    await expect(
      page.locator('[data-testid="chicago-scenario-polarity-CHI-CASE-001"]'),
    ).toHaveText("positive");

    // Authority boundaries, evidence table and failure-recovery sections.
    await expect(
      page.locator('[data-testid^="chicago-authority-boundary-"]'),
    ).toHaveCount(5);
    // 12 evidence entries in priv/chicago/chicago.executive.json ("evidence" array);
    // the tr selector excludes per-cell testids (chicago-evidence-layer/standing/receipt-*)
    // which would otherwise inflate the count to 12x4 = 48.
    await expect(
      page.locator('tr[data-testid^="chicago-evidence-"]'),
    ).toHaveCount(12);
    // failureRecovery: [] in the committed projection -> zero recovery rows.
    await expect(page.locator('[data-testid^="chicago-recovery-"]')).toHaveCount(0);
  });

  test("delivery state renders the committed UNKNOWN delivery numbers", async ({
    page,
  }) => {
    await expect(
      page.locator('[data-testid="chicago-delivery-required-layers"]'),
    ).toHaveText("10");
    await expect(
      page.locator('[data-testid="chicago-delivery-demonstrated-layers"]'),
    ).toHaveText("0");
    await expect(
      page.locator('[data-testid="chicago-delivery-candidate-layers"]'),
    ).toHaveText("10");
    await expect(
      page.locator('[data-testid="chicago-delivery-successor-layers"]'),
    ).toHaveText("2");
    await expect(
      page.locator('[data-testid="chicago-delivery-overall-standing"]'),
    ).toHaveText("UNKNOWN");
  });

  // NOTE: this surface has no phx events (render-only projection). Its
  // interaction-depth gap is closed on /chicago and /marketplace-pplan; here
  // the court is depth-of-data, not depth-of-interaction.
});

test.describe("/marketplace-pplan — ontology explorer (MarketplacePplanExplorerLive)", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/marketplace-pplan", { waitUntil: "domcontentloaded" });
    await waitLiveViewConnected(page);
  });

  test("renders the ontology summary from the parsed TTL graph", async ({ page }) => {
    await expect(page.locator("h1")).toHaveText("GCP Marketplace Lifecycle Explorer");

    // The summary line is the LiveView's own counts over the parsed graph:
    // 8 p-plan:Steps in the committed ontology.
    const summary = await page.locator("#ontology-summary").innerText();
    expect(summary).toMatch(/p-plan: .+ · \d+ variables · 8 steps · 8 agents · 4 organizations/);
  });

  test("stakeholder avatars render over the ontology people", async ({ page }) => {
    const grid = page.locator("#avatar-grid > div");
    await expect(grid).toHaveCount(8);

    // Known real people from priv/gcp/marketplace_lifecycle.ttl.
    await expect(page.locator("#avatar-grid").getByText("Elena Vance")).toBeVisible();
    await expect(
      page.locator("#avatar-grid").getByText("VP of Strategic Alliances & Cloud GTM"),
    ).toBeVisible();
    await expect(page.locator("#avatar-grid").getByText("Sarah Chen")).toBeVisible();
  });

  test("domain filter narrows avatars to the selected domain (phx-change)", async ({
    page,
  }) => {
    const grid = page.locator("#avatar-grid > div");
    await expect(grid).toHaveCount(8);

    // Drive the domain select to "Enterprise" (ApexGlobalLogistics members).
    await page.locator("#domain-filter").selectOption("Enterprise");
    await expect(grid).toHaveCount(3);
    await expect(page.locator("#avatar-grid").getByText("Sarah Chen")).toBeVisible();
    await expect(page.locator("#avatar-grid").getByText("Elena Vance")).toHaveCount(0);

    // Back to All restores the full stakeholder set.
    await page.locator("#domain-filter").selectOption("All");
    await expect(grid).toHaveCount(8);
  });

  test("workflow inspector selects a step and swaps the detail panel (phx-click)", async ({
    page,
  }) => {
    const buttons = page.locator("ol button");
    await expect(buttons).toHaveCount(8);

    // Default selection is step 1 (chain start: no predecessor).
    await expect(page.locator("#step-detail")).toContainText(
      "Step 1: Supplier Enrollment and Legal/Tax Verification",
    );
    await expect(page.locator("#step-detail")).toContainText("step 1 of 8");
    await expect(page.locator("#step-detail")).toContainText("— (chain start)");

    // Drive selection of step 8; the detail panel swaps to it.
    await buttons.nth(7).click();
    await expect(page.locator("#step-detail")).toContainText(
      "Step 8: Financial Clearinghouse Reconciliation and Disbursement",
    );
    await expect(page.locator("#step-detail")).toContainText("step 8 of 8");
    await expect(page.locator("#step-detail")).toContainText(
      "Step 7: Committed Spend Clearance and Invoicing",
    );
  });

  test("FinOps simulator recomputes KPIs when the pool slider changes (phx-change)", async ({
    page,
  }) => {
    const poolLabel = page.locator("#sim-form label").first();
    await expect(poolLabel).toContainText("Commit pool: $10,000,000");

    // Drive the range input; the LiveView recomputes and re-renders the label.
    await page.locator('#sim-form input[name="pool"]').fill("20000000");
    await expect(poolLabel).toContainText("Commit pool: $20,000,000");

    // The burn-down chart re-renders over the new series (SVG polylines).
    const chart = page.locator("svg[role='img'][aria-label*='burn-down']");
    await expect(chart).toBeVisible();
    await expect(chart.locator("polyline")).toHaveCount(2);
  });

  test("turtle viewer filters lines server-side (phx-change)", async ({ page }) => {
    const pre = page.locator("pre code");
    const full = await pre.innerText();
    expect(full).toContain("prov:Person");
    expect(full.split("\n").length).toBeGreaterThan(100);

    await page.locator('#turtle-filter-form input[name="q"]').fill("hasInputVar");

    await expect
      .poll(async () => (await pre.innerText()).split("\n").length, { timeout: 10_000 })
      .toBeLessThan(full.split("\n").length);

    const filtered = await pre.innerText();
    expect(filtered).toContain("hasInputVar");
    expect(filtered).not.toContain("prov:Person");
    // Every rendered line actually matches the query.
    for (const line of filtered.split("\n").filter(Boolean)) {
      expect(line.toLowerCase()).toContain("hasinputvar");
    }
  });
});
