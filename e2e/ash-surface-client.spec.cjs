// @ts-check
const { test, expect } = require("@playwright/test");

/**
 * W56 lane court: the generated ash_surface projection is served at /ash_surface
 * (Plug.Static mount in lib/xaas_web/endpoint.ex:29-33, from priv/ash_surface;
 * regenerate with `mix xaas.ash_surface`).
 *
 * Served artifacts under court here:
 *   - /ash_surface/surface_contract.json  (machine-readable surface manifest)
 *   - /ash_surface/xaas_ash_surface_client.mjs  (generated JS client)
 *   - /ash_surface/ash_surface_runtime.mjs      (generated runtime)
 *
 * NOTE on digest parity: byte-parity between the SERVED surface_contract.json
 * and the COMMITTED priv/ash_surface/surface_contract.json is deliberately NOT
 * asserted here — a browser-context spec cannot read the repo working tree.
 * That parity is the job of W17's drift-guard test
 * (test/xaas/ash_surface_drift_guard_test.exs). This spec asserts only that the
 * served manifestDigest is a well-formed, non-empty 64-hex string.
 */

const BASE = "/ash_surface";
const HEX64 = /^[0-9a-f]{64}$/;

/**
 * Convert ESM source to script source for `new Function` parse-compiling.
 *
 * A bare line-filter that drops every line starting with `import`/`export` is
 * UNSOUND: it deletes `export const X = Object.freeze({` declaration headers
 * and orphans their multi-line bodies (`Unexpected token ':'` on the first
 * body line). Instead, unwrap the `export` keyword from declarations (the
 * declaration itself stays intact) and blank out single-line import
 * statements and bare `export { ... }` lists.
 *
 * @param {string} source ESM module text.
 * @returns {string} equivalent classic-script text (parse-equivalent).
 */
function toScript(source) {
  return source
    .replace(/^import\b[^\n]*$/gm, "")
    .replace(/\bexport(?=\s+(?:const|let|var|function|async|class)\b)/g, "")
    .replace(/^[ \t]*export\s*\{[^}]*\}\s*;?[ \t]*$/gm, (m) =>
      m.replace(/[^\n]/g, " "),
    );
}

const ARTIFACTS = [
  { path: "/surface_contract.json", kind: "json" },
  { path: "/xaas_ash_surface_client.mjs", kind: "js" },
  { path: "/ash_surface_runtime.mjs", kind: "js" },
];

test.describe("ash_surface served projection", () => {
  for (const { path, kind } of ARTIFACTS) {
    test(`serves ${path} with 200`, async ({ request }) => {
      const res = await request.get(`${BASE}${path}`);
      expect(res.ok(), `status ${res.status()} for ${BASE}${path}`).toBe(true);
      const body = await res.text();
      expect(body.trim().length).toBeGreaterThan(0);

      if (kind === "json") {
        const contentType = res.headers()["content-type"] || "";
        expect(contentType).toContain("application/json");
      } else {
        const contentType = res.headers()["content-type"] || "";
        expect(contentType).toMatch(/javascript|ecmascript/i);
      }
    });
  }

  test("surface_contract.json is machine-readable with generatorIdentity and manifestDigest", async ({
    request,
  }) => {
    const res = await request.get(`${BASE}/surface_contract.json`);
    expect(res.ok()).toBe(true);

    const contract = await res.json(); // throws (court fails) if not valid JSON

    expect(contract.generatorIdentity).toBeTruthy();
    expect(typeof contract.generatorIdentity).toBe("string");
    expect(contract.generatorIdentity.length).toBeGreaterThan(0);

    expect(contract.manifestDigest).toMatch(HEX64);

    // Machine-readable manifest shape (non-vacuous: a truncated projection
    // would lose these).
    expect(contract.ashManifestSchemaVersion).toBeTruthy();
    expect(contract.manifest).toBeTruthy();
    expect(Array.isArray(contract.manifest.entrypoints)).toBe(true);
  });

  test("generated runtime .mjs compiles as valid JavaScript in the browser", async ({
    page,
    request,
  }) => {
    test.setTimeout(30_000);
    const res = await request.get(`${BASE}/ash_surface_runtime.mjs`);
    expect(res.ok()).toBe(true);
    const source = await res.text();

    // `new Function` is a real parse/compile in the page's JS engine. It does
    // not execute module top-level code (the text is wrapped in a function
    // body), so import/export statements would be syntax errors — acceptable
    // here because we are courting parse validity, not module resolution. To
    // keep the compile check meaningful for ESM text, convert it to
    // parse-equivalent classic-script text first and compile the remainder.
    const moduleFreeSource = toScript(source);

    const compileOk = await page.evaluate((src) => {
      try {
        // eslint-disable-next-line no-new-func
        new Function(src);
        return true;
      } catch (e) {
        return `compile error: ${e && /** @type {any} */ (e).message}`;
      }
    }, moduleFreeSource);

    expect(compileOk, `runtime compile check: ${compileOk}`).toBe(true);
  });

  test("generated client .mjs compiles as valid JavaScript in the browser", async ({
    page,
    request,
  }) => {
    const res = await request.get(`${BASE}/xaas_ash_surface_client.mjs`);
    expect(res.ok()).toBe(true);
    const source = await res.text();

    const moduleFreeSource = toScript(source);

    const compileOk = await page.evaluate((src) => {
      try {
        // eslint-disable-next-line no-new-func
        new Function(src);
        return true;
      } catch (e) {
        return `compile error: ${e && /** @type {any} */ (e).message}`;
      }
    }, moduleFreeSource);

    expect(compileOk, `client compile check: ${compileOk}`).toBe(true);
  });
});
