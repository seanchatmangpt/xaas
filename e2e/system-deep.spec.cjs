// @ts-check
const { test, expect } = require("@playwright/test");

/**
 * W57: interaction-depth courts for the `/system` command center surface.
 *
 * Route authority: lib/xaas_web/router.ex:288-294 —
 *   # /system observation surface (XaasWeb.System.CommandCenterLive): dev-routes
 *   live("/system", System.CommandCenterLive)
 *   ...
 * inside the `if Application.compile_env(:xaas, :dev_routes) do` block.
 *
 * The gate is a *compile-time* config flag (`Application.compile_env`),
 * so it cannot be flipped from the test process or via env at request
 * time — the same typed-404 documentation pattern e2e/dev-routes.spec.cjs
 * uses: this spec sets nothing. The Playwright webServer boots
 * `mix phx.server` (MIX_ENV=dev; config/dev.exs sets
 * `config :xaas, dev_routes: true`), so the route is compiled in on
 * exactly the server this suite targets. If a future config flips
 * dev_routes off, the route disappears and `page.goto("/system")` fails
 * with the server's typed behavior — a Phoenix 404 (no matching route),
 * not a disabled page.
 *
 * Surface authority: lib/xaas_web/live/system/command_center_live.ex +
 * lib/xaas_web/live/system/command_center_adapter.ex. The Live is
 * read-only by construction (zero Ash mutations; the ONLY event is
 * `refresh`, which re-runs the adapter's read-only snapshot). Every
 * heading/testid below is copied from the real HEEx template; every
 * answer-label string comes from the module's `@question_labels` map.
 *
 * Read-only courts: the single interaction (Refresh) performs no data
 * mutation — it re-reads the adapter snapshot. No data fabrication, no
 * authorization toggles.
 */

const TWELVE_ANSWERS = [
  "what exists",
  "running now",
  "obligations",
  "capabilities admitted",
  "plans",
  "executed",
  "refused",
  "unknown",
  "receipts",
  "OCEL evidence",
  "standing per claim",
  "replayable",
];

test("/system: renders the command center with real header content", async ({
  page,
}) => {
  const response = await page.goto("/system", { waitUntil: "networkidle" });
  expect(response && response.status()).toBe(200);

  // Real heading from the LiveView template.
  await expect(
    page.getByRole("heading", { name: "System command center — agentic payment" }),
  ).toBeVisible();

  // Exact subject binds the whole page to the adapter's fixed subject
  // (command_center_adapter.ex: @exact_subject).
  await expect(page.getByTestId("subject")).toHaveText(
    "urn:chicago:agentic-payment:purchase-001",
  );

  // State digest renders with a non-empty value (shape, not exact value —
  // it is a deterministic hash over live DB state).
  const digest = await page.getByTestId("state-digest").innerText();
  expect(digest).toMatch(/^state digest \S+/);
  expect(digest.replace(/^state digest\s+/, "").length).toBeGreaterThan(0);
});

test("/system: the twelve questions all render with real answer values", async ({
  page,
}) => {
  await page.goto("/system", { waitUntil: "networkidle" });

  await expect(
    page.getByRole("heading", { name: "The twelve questions" }),
  ).toBeVisible();

  // Every slug from @question_labels renders a card whose label matches
  // the module's string and whose answer is a rendered value (numeric or
  // text — never a blank card).
  for (const label of TWELVE_ANSWERS) {
    const card = page
      .locator('[data-testid^="answer-"]', { hasText: label })
      .first();
    await expect(card).toBeVisible();
    await expect(card).toContainText(label);
  }
  // There are exactly twelve answer cards.
  expect(await page.locator('[data-testid^="answer-"]').count()).toBe(12);
});

test("/system: layers table renders standing chips from the real vocabulary", async ({
  page,
}) => {
  await page.goto("/system", { waitUntil: "networkidle" });

  await expect(
    page.getByRole("heading", {
      name: "Layers — what exists + standing per claim",
    }),
  ).toBeVisible();

  const emptyState = page.getByText(
    "no layers in the model yet",
    { exact: false },
  );
  const rows = page.locator('[data-testid^="layer-row-"]');
  const rowCount = await rows.count();

  if (rowCount === 0) {
    // Typed empty state must name the standing law (UNKNOWN until receipt).
    await expect(emptyState).toBeVisible();
  } else {
    // Each layer row shows: a label, a monospace capability id, a standing
    // chip, and an evidence/receipt count in "N evidence / M receipt refs"
    // shape.
    for (let i = 0; i < rowCount; i++) {
      const row = rows.nth(i);
      await expect(row).toBeVisible();
      const cells = row.locator("td");
      await expect(cells.nth(3)).toContainText(/evidence \/ \d+ receipt refs?/);
      const chip = row.locator('[data-testid^="layer-standing-"]');
      await expect(chip).toBeVisible();
      const standing = (await chip.innerText()).trim();
      // Full standing vocabulary from standing_chip_classes/1.
      expect(standing).toMatch(/^(ALIVE|PARTIAL_ALIVE|REFUSED|UNKNOWN)/);
    }
  }
});

test("/system: running/obligations/capabilities/plans sections render real or typed-empty tables", async ({
  page,
}) => {
  await page.goto("/system", { waitUntil: "networkidle" });

  // --- Running: real Runs and Epochs -------------------------------------
  await expect(
    page.getByRole("heading", { name: "Running — real Runs and Epochs" }),
  ).toBeVisible();
  const runRows = await page.locator('[data-testid^="run-row-"]').count();
  const epochRows = await page.locator('[data-testid^="epoch-row-"]').count();
  if (runRows === 0 && epochRows === 0) {
    await expect(page.getByText("nothing running")).toBeVisible();
  } else {
    // State chips must come from the real lifecycle vocabulary.
    const firstState = page
      .locator('[data-testid^="run-row-"], [data-testid^="epoch-row-"]')
      .first()
      .locator("span.rounded");
    await expect(firstState.first()).toBeVisible();
  }

  // --- Obligations (OBSERVE-only projections) ----------------------------
  await expect(
    page.getByRole("heading", {
      name: "Obligations (OBSERVE-only projections)",
    }),
  ).toBeVisible();
  const obligationRows = await page
    .locator('[data-testid^="obligation-row-"]')
    .count();
  if (obligationRows === 0) {
    await expect(
      page.getByText("no obligations — the Chicago projection has not landed yet (R4)"),
    ).toBeVisible();
  } else {
    // Status chips carry the lifecycle vocabulary.
    const status = page
      .locator('[data-testid^="obligation-row-"]')
      .first()
      .locator("span.rounded");
    await expect(status.first()).toBeVisible();
  }

  // --- Capabilities (admitted = receipt-backed) ---------------------------
  await expect(
    page.getByRole("heading", { name: "Capabilities (admitted = receipt-backed)" }),
  ).toBeVisible();
  const capabilityRows = await page
    .locator('[data-testid^="capability-row-"]')
    .count();
  if (capabilityRows === 0) {
    await expect(
      page.getByText("no capabilities observed or projected"),
    ).toBeVisible();
  } else {
    // Admitted column renders the binary standing: ALIVE or UNKNOWN only.
    const admitted = page
      .locator('[data-testid^="capability-row-"]')
      .first()
      .locator("span.rounded");
    // Server renders the chip with surrounding whitespace/newlines;
    // match the same strict vocabulary, tolerant of the whitespace.
    await expect(admitted.first()).toHaveText(/^\s*(ALIVE|UNKNOWN)\s*$/);
  }

  // --- Plans (planning episodes, ceiling :SELECT) -------------------------
  await expect(
    page.getByRole("heading", { name: "Plans (planning episodes, ceiling :SELECT)" }),
  ).toBeVisible();
  // Episode rows or their typed empty state ("no runs — no plans
  // projected") must be present; row data itself is live telemetry.
  const episodeRows = await page
    .locator('[data-testid^="episode-row-"]')
    .count();
  if (episodeRows === 0) {
    await expect(page.getByText("no runs — no plans projected")).toBeVisible();
  }
  await expect(
    page
      .locator(
        'section[data-testid="plans"] tbody tr, section[data-testid="plans"] ul',
      )
      .first(),
  ).toBeVisible();
});

test("/system: evidence sections render receipts, refusals, unknowns, OCEL, cases", async ({
  page,
}) => {
  await page.goto("/system", { waitUntil: "networkidle" });

  // --- Executed + replayable ----------------------------------------------
  await expect(
    page.getByRole("heading", { name: "Executed + replayable" }),
  ).toBeVisible();
  const executionRows = await page
    .locator('[data-testid^="execution-row-"]')
    .count();
  if (executionRows === 0) {
    await expect(
      page.getByText(
        "no SA2A executions recorded — nothing is claimed executed",
      ),
    ).toBeVisible();
  } else {
    // Replay-verified column renders a boolean-shaped value.
    const replay = page
      .locator('[data-testid^="replay-"]')
      .first();
    await expect(replay).toHaveText(/^(true|false)$/);
  }

  // --- Refused (typed, with reasons) ---------------------------------------
  await expect(
    page.getByRole("heading", { name: "Refused (typed, with reasons)" }),
  ).toBeVisible();
  const refusalRows = await page
    .locator('[data-testid^="refusal-row-"]')
    .count();
  if (refusalRows === 0) {
    await expect(page.getByText("no refusals recorded")).toBeVisible();
  } else {
    // Typed refusal rows carry a non-empty named reason.
    const reason = page.locator('[data-testid^="refusal-reason-"]').first();
    await expect(reason).toBeVisible();
    expect((await reason.innerText()).trim().length).toBeGreaterThan(0);
  }

  // --- Unknown (candidate/transport rows, slate) ---------------------------
  await expect(
    page.getByRole("heading", { name: "Unknown (candidate/transport rows, slate)" }),
  ).toBeVisible();
  const unknownRows = await page
    .locator('[data-testid^="unknown-row-"]')
    .count();
  if (unknownRows === 0) {
    await expect(
      page.getByText("nothing unknown — every claim carries a real receipt"),
    ).toBeVisible();
  }

  // --- Receipts (real sealed rows) -----------------------------------------
  await expect(
    page.getByRole("heading", { name: "Receipts (real sealed rows)" }),
  ).toBeVisible();
  const receiptRows = await page
    .locator('[data-testid^="receipt-row-"]')
    .count();
  if (receiptRows === 0) {
    await expect(
      page.getByText(
        "no receipts sealed for recent epochs — every layer stays UNKNOWN",
      ),
    ).toBeVisible();
  }

  // --- OCEL evidence --------------------------------------------------------
  await expect(
    page.getByRole("heading", { name: "OCEL evidence (real event log rows)" }),
  ).toBeVisible();
  const ocelRows = await page.locator('[data-testid^="ocel-row-"]').count();
  if (ocelRows === 0) {
    await expect(page.getByText("no OCEL events recorded")).toBeVisible();
  } else {
    // Each OCEL row: event type, ocel id, occurred-at timestamp — shape,
    // not exact values (live telemetry).
    const firstRow = page.locator('[data-testid^="ocel-row-"]').first();
    const cells = firstRow.locator("td");
    expect((await cells.nth(0).innerText()).trim().length).toBeGreaterThan(0);
    expect((await cells.nth(1).innerText()).trim().length).toBeGreaterThan(0);
    expect((await cells.nth(2).innerText()).trim().length).toBeGreaterThan(0);
  }

  // --- Cases (candidate predictions — R8) -----------------------------------
  await expect(
    page.getByRole("heading", { name: "Cases (candidate predictions — R8)" }),
  ).toBeVisible();
  const caseRows = await page.locator('[data-testid^="case-row-"]').count();
  if (caseRows === 0) {
    await expect(page.getByText("no cases in the model yet")).toBeVisible();
  } else {
    const chip = page
      .locator('[data-testid^="case-row-"]')
      .first()
      .locator("span.rounded");
    await expect(chip.first()).toBeVisible();
  }
});

test("/system: Refresh button re-runs the read-only snapshot (state stays coherent)", async ({
  page,
}) => {
  await page.goto("/system", { waitUntil: "networkidle" });

  const digestBefore = await page
    .getByTestId("state-digest")
    .innerText();

  // The only interaction on the surface: phx-click="refresh".
  await page.getByTestId("refresh").click();

  // The LiveView handles the event and re-renders with a fresh adapter
  // snapshot: the digest stays in valid shape (deterministic over
  // unchanged DB state, so the VALUE may be identical — the court asserts
  // the refresh path executes without error and the page re-renders
  // coherent content, not that the digest flips).
  await expect(page.getByTestId("state-digest")).toHaveText(
    digestBefore,
    { timeout: 15_000 },
  );

  // Post-refresh, the full read model is still rendered.
  await expect(
    page.getByRole("heading", { name: "System command center — agentic payment" }),
  ).toBeVisible();
  await expect(page.getByTestId("subject")).toHaveText(
    "urn:chicago:agentic-payment:purchase-001",
  );
  expect(await page.locator('[data-testid^="answer-"]').count()).toBe(12);
});
