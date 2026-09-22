// @ts-check
const { test, expect } = require("@playwright/test");

test.describe("WD Case Study 2 deterministic reference surface", () => {
  test("proves KNOWN, PARTIAL, UNKNOWN and MachineExperience replay without an LLM", async ({ page }) => {
    await page.goto("/case-studies/wd-fa", { waitUntil: "networkidle" });

    await expect(page.locator('[data-testid="wd-fa-root"]')).toBeVisible();
    await expect(page.locator('[data-testid="classification"]')).toHaveText("KNOWN");
    await expect(page.locator('[data-testid="admitted-mode"]')).toHaveText("MODE-A-FIRMWARE");
    await expect(page.locator('[data-testid="human-gate"]')).toHaveText("ENGINEER_DISPOSITION_REQUIRED");
    await expect(page.locator('[data-testid="authority"]')).toHaveText("SELECT_CONSTRUCT_ONLY");
    await expect(page.locator('[data-testid="stogaf-current"]')).toHaveText("ST-4 CONSTRAINED");
    await expect(page.locator('[data-testid="stogaf-target"]')).toHaveText("ST-6 AUTONOMIC");
    await expect(page.locator('[data-testid="stogaf-adm-phase"]')).toHaveText("G IMPLEMENTATION_GOVERNANCE → H ARCHITECTURE_CHANGE_MANAGEMENT");
    await expect(page.locator('[data-testid="stogaf-authority"]')).toHaveText("SELECT_CONSTRUCT_ONLY");
    await expect(page.locator('[data-testid="stogaf-requirements-count"]')).toHaveText("16");
    await expect(page.locator('[data-testid="stogaf-viewpoints-count"]')).toHaveText("5");
    await expect(page.locator('[data-testid="stogaf-workorders-count"]')).toHaveText("10");
    await expect(page.locator('[data-testid="stogaf-unclaimed-count"]')).toHaveText("3");
    await expect(page.locator('[data-testid="stogaf-requirements"]')).toContainText("R-16");
    await expect(page.locator('[data-testid="stogaf-viewpoints"]')).toContainText("FA Morning Brief");
    await expect(page.locator('[data-testid="stogaf-workgraph-boundary"]')).toContainText("SJ-011 → SJ-020");

    const architectureResponse = await page.request.get("/case-studies/wd-fa/stogaf.json");
    expect(architectureResponse.ok()).toBeTruthy();
    const architecture = await architectureResponse.json();
    expect(architecture.architecture.current_conformance).toBe("ST-4 CONSTRAINED");
    expect(architecture.architecture.target_conformance).toBe("ST-6 AUTONOMIC");
    expect(architecture.requirements).toHaveLength(16);
    expect(architecture.capabilities.some((capability) => capability.plane === "DO")).toBeFalsy();
    expect(architecture.excluded_production_do.plane).toBe("DO");

    await page.locator('[data-testid="scenario-partial_firmware"]').click();
    await expect(page.locator('[data-testid="classification"]')).toHaveText("PARTIAL");
    await expect(page.locator('[data-testid="admitted-mode"]')).toHaveText("NONE");
    await expect(page.locator('[data-testid="missing-evidence"]')).toContainText("timeout_waveform");

    await page.locator('[data-testid="scenario-novel_x"]').click();
    await expect(page.locator('[data-testid="classification"]')).toHaveText("UNKNOWN");
    await expect(page.locator('[data-testid="admitted-mode"]')).toHaveText("NONE");
    await expect(page.locator('[data-testid="next-action"]')).toHaveText("ESCALATE_NOVEL_INVESTIGATION");
    await expect(page.locator('[data-testid="hypothesis-list"]')).toContainText("MODE-X-CANDIDATE");

    await page.locator('[data-testid="admit-experience"]').click();
    await expect(page.locator('[data-testid="classification"]')).toHaveText("KNOWN");
    await expect(page.locator('[data-testid="admitted-mode"]')).toHaveText("MODE-X-NOVEL");
    await expect(page.locator('[data-testid="confidence-basis"]')).toHaveText("ADMITTED_MACHINE_EXPERIENCE");
    await expect(page.locator('[data-testid="prior-cases"]')).toContainText("MX-NOVEL-X-001");
  });
});
