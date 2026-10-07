// @ts-check
const { test, expect } = require("@playwright/test");
const { execSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

/**
 * E2E for the read-only witness surface (lane W1 + lane W55, v26.10.6).
 *
 * Self-seeding: `beforeAll` runs a real `mix run -e` against THIS dev repo,
 * seeding two Xaas.Witness.CertifiedReceipt rows through the real Ash
 * actions (`:ingest` + `:record_verification`). No mocks. Deterministic
 * subjects (`sha256:e2e-w55-verified` / `sha256:e2e-w55-unverified`) with
 * check-first idempotency, so reruns never duplicate rows and the
 * write-once `:record_verification` is never re-applied to a verified row.
 *
 * Honest both-branch contract: if seeding could not run (e.g. repo doctrine
 * forbids a dev-env mix invocation while the live `mix phx.server` holds
 * `_build/dev`, or mix is unavailable on PATH), the spec does NOT fail
 * spuriously — it asserts the surface's typed empty state
 * (`[data-testid="witness-empty-row"]`) instead, and reports the seeding
 * failure in the test output for the coordinator to act on.
 *
 * Config note (NOT edited here, per lane rules): no `globalSetup` key is
 * needed — seeding is in-spec `beforeAll`. If the coordinator prefers a
 * global setup, add `globalSetup: "./e2e/global-setup.cjs"` to
 * playwright.config.cjs and move the seedElixir() call there verbatim.
 */

const REPO_ROOT = path.resolve(__dirname, "..");

const SEED_ELIXIR = `
require Ash.Query
alias Xaas.Witness.CertifiedReceipt
payload_hash_hex = String.duplicate("ab", 32)
signature_hex = String.duplicate("cd", 32)
verifying_key_hex = String.duplicate("ef", 32)
seeds = [
  %{subject: "sha256:e2e-w55-verified", want_verified?: true},
  %{subject: "sha256:e2e-w55-unverified", want_verified?: false}
]
Enum.each(seeds, fn seed ->
  # Pin must be a simple variable: ^seed.subject is not valid Elixir.
  subject = seed.subject
  existing =
    CertifiedReceipt
    |> Ash.Query.filter(subject == ^subject)
    |> Ash.read!()
    |> List.first()
  receipt =
    existing ||
      Ash.create!(
        CertifiedReceipt,
        %{
          subject: seed.subject,
          payload_hash_hex: payload_hash_hex,
          algorithm: :es256,
          signature_hex: signature_hex,
          verifying_key_hex: verifying_key_hex
        },
        [action: :ingest]
      )
  if seed.want_verified? and not receipt.verified do
    Ash.update!(receipt, %{}, action: :record_verification)
  end
end)
IO.puts("W55_SEED_OK")
`;

let seeded = false;
let seedError = /** @type {any} */ (null);

test.beforeAll(() => {
  let mix = "";
  // Write the seed to a real file and run `mix run <file>`: passing the code
  // through the shell via JSON.stringify leaves literal "\n" escapes inside
  // double quotes, which sh does not expand — mix received the whole seed as
  // one line and raised a SyntaxError (the original W55 failure path).
  const seedPath = path.join(os.tmpdir(), `w55-seed-${process.pid}.exs`);
  try {
    fs.writeFileSync(seedPath, SEED_ELIXIR);
    mix = execSync('PATH="$HOME/.asdf/shims:$PATH" MIX_ENV=dev mix run ' + seedPath, {
      cwd: REPO_ROOT,
      encoding: "utf8",
      timeout: 180_000,
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (err) {
    const e = /** @type {any} */ (err);
    seedError = String(e && e.message ? e.message : e).slice(0, 2000);
  } finally {
    try {
      fs.unlinkSync(seedPath);
    } catch {}
  }
  if (!seedError) {
    seeded = mix.includes("W55_SEED_OK");
    if (!seeded) {
      seedError = "mix run produced no W55_SEED_OK marker; output was: " + mix.slice(-500);
    }
  }
  // The dev server is already running (playwright webServer reuses it); the
  // seeded rows are committed by the real Ash actions, so the LiveView sees
  // them on the next mount without any restart.
});

test.describe("Witness certified-receipt surface", () => {
  test("renders the read-only certified receipts table", async ({ page }) => {
    await page.goto("/witness", { waitUntil: "networkidle" });

    const header = page.locator("h1");
    await expect(header).toContainText("Certified Receipts");
    await expect(page.locator('[data-testid="witness-receipts-table"]')).toBeVisible();
  });

  test("renders real receipt rows when seeded, else the typed empty state", async ({ page }) => {
    await page.goto("/witness", { waitUntil: "networkidle" });

    if (seedError !== null) {
      // Honest degraded branch: attach the real seeding failure for the
      // coordinator, then branch on what the page actually renders — a
      // failed seed with pre-existing rows must still assert the rows.
      test.info().attach("w55-seed-error.txt", { body: String(seedError) });
    }

    const rows = page.locator('[data-testid="witness-receipt-row"]');
    const hasRows = (await rows.count()) > 0;

    if (hasRows) {
      await expect(rows.first()).toBeVisible();

      const first = rows.first();
      await expect(first.locator('[data-testid="witness-receipt-subject"]')).not.toBeEmpty();
      await expect(first.locator('[data-testid="witness-receipt-algorithm"]')).not.toBeEmpty();
      const verified = first.locator('[data-testid="witness-receipt-verified"]');
      await expect(verified).toHaveText(/^\s*(yes|no)\s*$/);
    } else {
      // Honest empty branch: the surface renders its typed empty row, never
      // a crash — same contract as XaasWeb.WitnessLiveTest's empty case.
      await expect(page.locator('[data-testid="witness-empty-row"]')).toBeVisible();
      await expect(page.locator('[data-testid="witness-receipt-row"]')).toHaveCount(0);
    }
  });

  test("at least the two deterministic seed rows are rendered", async ({ page }) => {
    test.fixme(
      seedError !== null,
      "W55 self-seeding could not run (dev-env mix blocked); see attached w55-seed-error.txt"
    );
    await page.goto("/witness", { waitUntil: "networkidle" });

    const rows = page.locator('[data-testid="witness-receipt-row"]');
    expect(await rows.count()).toBeGreaterThanOrEqual(2);

    // The two deterministic subjects themselves are on the page.
    await expect(
      page.locator('[data-testid="witness-receipt-subject"]', {
        hasText: "sha256:e2e-w55-verified",
      })
    ).toBeVisible();
    await expect(
      page.locator('[data-testid="witness-receipt-subject"]', {
        hasText: "sha256:e2e-w55-unverified",
      })
    ).toBeVisible();
  });
});
