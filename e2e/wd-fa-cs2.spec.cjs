// @ts-check
const { test, expect } = require("@playwright/test");

test.describe("WD Case Study 2 deterministic reference surface", () => {
  test("proves KNOWN, PARTIAL, UNKNOWN and MachineExperience replay without an LLM", async ({ page }) => {
    await page.goto("/case-studies/wd-fa", { waitUntil: "networkidle" });

    await expect(page.locator('[data-testid="wd-fa-root"]')).toBeVisible();
    await expect(page.locator('[data-testid="brief-needs-judgment"]')).toHaveText("1");
    await expect(page.locator('[data-testid="brief-missing-evidence"]')).toHaveText("1");
    await expect(page.locator('[data-testid="brief-prior-art-ready"]')).toHaveText("1");
    await expect(page.locator('[data-testid="brief-authority-rule"]')).toContainText("consequential disposition remains with the engineer");
    await expect(page.locator('[data-testid="evaluation-controls"]')).toHaveText("7/7 controls passed");
    await expect(page.locator('[data-testid="evaluation-ceiling"]')).toContainText("REPO_LOCAL_FIXTURE");
    await expect(page.locator('[data-testid="production-mttr"]')).toContainText("UNMEASURED");
    await expect(page.locator('[data-testid="delta-before"]')).toContainText("UNKNOWN");
    await expect(page.locator('[data-testid="delta-after"]')).toContainText("KNOWN");
    await expect(page.locator('[data-testid="delta-retired"]')).toContainText("YES");
    await expect(page.locator('[data-testid="delta-time"]')).toContainText("UNMEASURED");
    await expect(page.locator('[data-testid="classification"]')).toHaveText("KNOWN");
    await expect(page.locator('[data-testid="admitted-mode"]')).toHaveText("MODE-A-FIRMWARE");
    await expect(page.locator('[data-testid="source-timeout_waveform"]')).toContainText("fixture://wd/");
    await expect(page.locator('[data-testid="ingestion-modalities"]')).toContainText("structured");
    await expect(page.locator('[data-testid="ingestion-modalities"]')).toContainText("text");
    await expect(page.locator('[data-testid="ingestion-modalities"]')).toContainText("plot");
    await expect(page.locator('[data-testid="work-standing"]')).toHaveText("READY_FOR_ENGINEER_DISPOSITION");
    await expect(page.locator('[data-testid="work-authority"]')).toHaveText("SELECT_CONSTRUCT_ONLY");
    await expect(page.locator('[data-testid="case-capabilities"]')).toContainText("test_applicability");
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
    await expect(page.locator('[data-testid="autonomic-next"]')).toContainText("SJ-011");
    await expect(page.locator('[data-testid="autonomic-intelligence"]')).toContainText("NONE");

    const architectureResponse = await page.request.get("/case-studies/wd-fa/stogaf.json");
    expect(architectureResponse.ok()).toBeTruthy();
    const architecture = await architectureResponse.json();
    expect(architecture.architecture.current_conformance).toBe("ST-4 CONSTRAINED");
    expect(architecture.morning_brief.needs_judgment).toBe(1);
    expect(architecture.morning_brief.missing_evidence).toBe(1);
    expect(architecture.morning_brief.prior_art_ready).toBe(1);
    expect(architecture.ingestion_fixture.artifacts).toHaveLength(3);
    expect(architecture.offline_evaluation.controls_passed).toBe(7);
    expect(architecture.offline_evaluation.production_metrics.mttr).toBe("UNMEASURED");
    expect(architecture.ingestion_fixture.artifacts.map((artifact) => artifact.modality).sort()).toEqual(["plot", "structured", "text"]);
    expect(architecture.architecture.target_conformance).toBe("ST-6 AUTONOMIC");
    expect(architecture.requirements).toHaveLength(16);
    expect(architecture.capabilities.some((capability) => capability.plane === "DO")).toBeFalsy();
    expect(architecture.excluded_production_do.plane).toBe("DO");
    expect(architecture.autonomic_planner.next.id).toBe("SJ-011");
    expect(architecture.autonomic_planner.next.runtime_intelligence).toBe("NONE");
    expect(architecture.demo_work.partial_firmware.standing).toBe("BLOCKED_ON_EVIDENCE");
    expect(architecture.demo_capabilities.novel_x.some((capability) => capability.plane === "DO")).toBeFalsy();

    await page.locator('[data-testid="scenario-partial_firmware"]').click();
    await expect(page.locator('[data-testid="classification"]')).toHaveText("PARTIAL");
    await expect(page.locator('[data-testid="admitted-mode"]')).toHaveText("NONE");
    await expect(page.locator('[data-testid="missing-evidence"]')).toContainText("timeout_waveform");
    await expect(page.locator('[data-testid="work-standing"]')).toHaveText("BLOCKED_ON_EVIDENCE");
    await expect(page.locator('[data-testid="work-obligation"]')).toContainText("timeout_waveform");

    await page.locator('[data-testid="scenario-novel_x"]').click();
    await expect(page.locator('[data-testid="classification"]')).toHaveText("UNKNOWN");
    await expect(page.locator('[data-testid="admitted-mode"]')).toHaveText("NONE");
    await expect(page.locator('[data-testid="next-action"]')).toHaveText("ESCALATE_NOVEL_INVESTIGATION");
    await expect(page.locator('[data-testid="hypothesis-list"]')).toContainText("MODE-X-CANDIDATE");
    await expect(page.locator('[data-testid="work-standing"]')).toHaveText("NOVEL_INVESTIGATION_REQUIRED");

    await page.locator('[data-testid="admit-experience"]').click();
    await expect(page.locator('[data-testid="classification"]')).toHaveText("KNOWN");
    await expect(page.locator('[data-testid="admitted-mode"]')).toHaveText("MODE-X-NOVEL");
    await expect(page.locator('[data-testid="confidence-basis"]')).toHaveText("ADMITTED_MACHINE_EXPERIENCE");
    await expect(page.locator('[data-testid="prior-cases"]')).toContainText("MX-NOVEL-X-001");
    await expect(page.locator('[data-testid="verification-receipt"]')).toBeVisible();
    await expect(page.locator('[data-testid="receipt-digest"]')).toContainText("sha256:");
    await expect(page.locator('[data-testid="receipt-verifier"]')).toContainText("independent-observer");
    await expect(page.locator('[data-testid="receipt-scope"]')).toContainText("REPO_LOCAL_FIXTURE");
    await expect(page.locator('[data-testid="experience-id"]')).toContainText("MX-NOVEL-X-001");
    await expect(page.locator('[data-testid="standard-change"]')).toContainText("CS2-V1 → CS2-V2");
    await expect(page.locator('[data-testid="architecture-change-phase"]')).toHaveText("H ARCHITECTURE_CHANGE_MANAGEMENT");
    await expect(page.locator('[data-testid="brief-needs-judgment"]')).toHaveText("0");
    await expect(page.locator('[data-testid="brief-prior-art-ready"]')).toHaveText("2");
  });
});
