// @ts-check
"use strict";

/**
 * e2e/global-setup.cjs — deterministic test-env plumbing (W100, v26.10.6).
 *
 * Two entry modes:
 *
 *   1. Playwright `globalSetup` hook (default): generates the real
 *      ggen-marketplace catalog JSON into a fixed temp path (the documented
 *      generator, see e2e/marketplace.spec.ts) and sets
 *      PW3_EXPECTED_PACK_COUNT for the test workers; seeds the two
 *      deterministic W55 witness receipt rows through the real Ash actions
 *      (:ingest + :record_verification). IDEMPOTENT and FAILURE-TOLERANT:
 *      every step logs its outcome and never aborts the run — a failed seed
 *      surfaces through each spec's honest degraded branch (typed empty
 *      state / PW3 count mismatch), not a setup crash.
 *
 *   2. CLI mode (`node e2e/global-setup.cjs --catalog`), used by the
 *      webServer boot command. Playwright starts the webServer BEFORE
 *      globalSetup (verified in the bundled runner: plugin setup tasks run
 *      ahead of global setup tasks), so the fresh-boot path must generate
 *      the catalog file — the only step the boot itself depends on — up
 *      front. Exits 0 even on generation failure: boot proceeds and the
 *      mount-time ingest surfaces a typed refusal in the UI instead of
 *      aborting the run.
 */

const { execSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const REPO_ROOT = path.resolve(__dirname, "..");
const MARKETPLACE_REPO = "/Users/sac/ggen-marketplace";

/** Shared constant — playwright.config.cjs requires this module for it. */
const MARKETPLACE_CATALOG_PATH = path.join(
  os.tmpdir(),
  "xaas-e2e-marketplace-catalog.json"
);

const WITNESS_SEED_PATH = path.join(__dirname, "seed-witness.exs");
const LIBRARY_SEED_PATH = path.join(__dirname, "seed-library.exs");

/** Run a shell step; return {ok, output} instead of throwing. */
function tryStep(/** @type {string} */ name, /** @type {string} */ command, /** @type {any} */ options = undefined) {
  try {
    const output = execSync(command, {
      cwd: REPO_ROOT,
      encoding: "utf8",
      timeout: 180_000,
      stdio: ["ignore", "pipe", "pipe"],
      ...options,
    });
    return { ok: true, output: String(output) };
  } catch (err) {
    const e = /** @type {any} */ (err);
    const message = String(e && e.message ? e.message : e).slice(0, 2000);
    console.warn(`[global-setup] ${name} FAILED (continuing): ${message}`);
    return { ok: false, output: message };
  }
}

/**
 * Generate the real ggen-marketplace catalog JSON to MARKETPLACE_CATALOG_PATH.
 * Returns the pack count, or null on failure (logged, never thrown).
 */
function generateMarketplaceCatalog() {
  const result = tryStep(
    "marketplace catalog generation",
    'python3 scripts/marketplace.py catalog',
    { cwd: MARKETPLACE_REPO }
  );
  if (!result.ok) return null;

  const raw = result.output;
  try {
    const catalog = JSON.parse(raw);
    const count = Array.isArray(catalog.packs) ? catalog.packs.length : 0;
    if (count <= 0) {
      console.warn(
        `[global-setup] catalog generated but contains ${count} packs (continuing)`
      );
      return null;
    }
    fs.writeFileSync(MARKETPLACE_CATALOG_PATH, raw);
    console.log(
      `[global-setup] marketplace catalog written: ${MARKETPLACE_CATALOG_PATH} (${count} packs)`
    );
    return count;
  } catch (err) {
    console.warn(
      `[global-setup] catalog output was not valid JSON (continuing): ${err}`
    );
    return null;
  }
}

/** Seed the two W55 witness rows via the committed e2e/seed-witness.exs. Returns true on the marker. */
function seedWitnessReceipts() {
  const result = tryStep(
    "witness seed (mix run e2e/seed-witness.exs)",
    'PATH="$HOME/.asdf/shims:$PATH" MIX_ENV=test mix run ' + WITNESS_SEED_PATH
  );
  const ok = result.ok && result.output.includes("W55_SEED_OK");
  if (ok) {
    console.log("[global-setup] W55_SEED_OK: witness rows seeded");
  } else {
    console.warn(
      "[global-setup] witness seed did not report W55_SEED_OK (continuing)"
    );
  }
  return ok;
}

/**
 * Seed the /next-read fixture chain (Xaas.DevSeeds.run/0) via the committed
 * e2e/seed-library.exs (W823). Failure-tolerant like every other step; a
 * failed seed surfaces as the next-read-ml empty-shelf failures, not a
 * setup crash. Runs in BOTH entry modes: the webServer boots before
 * globalSetup, so catalogOnly() (the boot path) must seed up front too.
 */
function seedLibraryBooks() {
  const result = tryStep(
    "library seed (mix run e2e/seed-library.exs)",
    'PATH="$HOME/.asdf/shims:$PATH" MIX_ENV=test mix run ' + LIBRARY_SEED_PATH
  );
  const ok = result.ok && result.output.includes("W823_SEED_OK");
  if (ok) {
    console.log("[global-setup] W823_SEED_OK: next-read library fixtures seeded");
  } else {
    console.warn(
      "[global-setup] library seed did not report W823_SEED_OK (continuing)"
    );
  }
  return ok;
}

/** Playwright globalSetup entry: always resolves, never throws. */
async function globalSetup() {
  const count = generateMarketplaceCatalog();
  if (count !== null) {
    process.env.PW3_EXPECTED_PACK_COUNT = String(count);
  }
  seedWitnessReceipts();
  seedLibraryBooks();
}

/** WebServer-boot helper mode: catalog file only; always exit 0. */
function catalogOnly() {
  generateMarketplaceCatalog();
  seedLibraryBooks();
  process.exit(0);
}

module.exports = {
  MARKETPLACE_CATALOG_PATH,
  generateMarketplaceCatalog,
  seedWitnessReceipts,
  seedLibraryBooks,
  default: globalSetup,
};

if (require.main === module) {
  if (process.argv.includes("--catalog")) {
    catalogOnly();
  } else {
    globalSetup().catch((err) => {
      console.warn(`[global-setup] setup failed (continuing): ${err}`);
      process.exit(0);
    });
  }
}
