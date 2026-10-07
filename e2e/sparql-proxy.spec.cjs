// @ts-check
const { test, expect } = require("@playwright/test");

/**
 * SPARQL proxy courts (wave-2 lane W12, X1 gap).
 *
 * Wire shapes are read from source, not string-scraped:
 *   - XaasWeb.OntopProxyPlug (lib/xaas_web/plugs/ontop_proxy_plug.ex):
 *     forwards to the real Ontop SPARQL endpoint; when Ontop is
 *     unreachable the proxy answers 502 {"error":"ontop_unreachable",
 *     "detail": inspect(reason)} -- a typed failure, never a silent pass.
 *   - Mounted at POST/GET /internal-api/sparql behind
 *     XaasWeb.Plugs.RequireInternalApiToken (lib/xaas_web/router.ex,
 *     scope "/internal-api" -> forward("/sparql", ...)): no/invalid token
 *     is refused before the proxy runs, exactly like every other
 *     /internal-api route.
 *
 * SPARQL results format is the standard W3C SPARQL 1.1 JSON results
 * serialization: { head: { vars: [...] }, results: { bindings: [...] } }.
 *
 * Token behavior mirrors e2e/internal-api.spec.cjs (wave-2 lane W3):
 * INTERNAL_API_TOKEN comes from this runner's env, the same env the dev
 * server runs under. When it is absent this suite still runs and asserts
 * the fail-closed floor instead of skipping.
 */

const ENDPOINT = "/internal-api/sparql";
const TOKEN = process.env.INTERNAL_API_TOKEN || "";

/** @param {string} token @returns {Record<string, string>} */
function authHeaders(token) {
  return token ? { Authorization: `Bearer ${token}` } : {};
}

test.describe("/internal-api/sparql token gate", () => {
  test("refuses the SPARQL proxy without a token (fail-closed, typed body)", async ({
    request,
  }) => {
    const res = await request.post(ENDPOINT, {
      headers: {},
      data: "SELECT * WHERE { ?s ?p ?o } LIMIT 1",
    });
    const body = await res.json();

    if (process.env.INTERNAL_API_TOKEN) {
      expect(res.status()).toBe(401);
      expect(body).toEqual({
        error: "unauthorized",
        detail: "missing or invalid Bearer token",
      });
    } else {
      // Server cannot have a token -> fail-closed misconfigured signal.
      expect(res.status()).toBe(503);
      expect(body).toEqual({
        error: "internal_api_misconfigured",
        detail: "INTERNAL_API_TOKEN is not set on the server",
      });
    }
  });

  test("refuses the SPARQL proxy with an invalid token (typed body)", async ({
    request,
  }) => {
    const res = await request.post(ENDPOINT, {
      headers: { Authorization: "Bearer definitely-not-a-real-token" },
      data: "SELECT * WHERE { ?s ?p ?o } LIMIT 1",
    });
    const body = await res.json();

    if (process.env.INTERNAL_API_TOKEN) {
      expect(res.status()).toBe(401);
      expect(body).toEqual({
        error: "unauthorized",
        detail: "missing or invalid Bearer token",
      });
    } else {
      expect(res.status()).toBe(503);
      expect(body).toEqual({
        error: "internal_api_misconfigured",
        detail: "INTERNAL_API_TOKEN is not set on the server",
      });
    }
  });
});

test.describe("/internal-api/sparql real query", () => {
  test("answers a real SPARQL query with machine-readable results", async ({
    request,
  }) => {
    test.skip(!TOKEN, "INTERNAL_API_TOKEN not set in this environment");

    const res = await request.post(ENDPOINT, {
      headers: {
        ...authHeaders(TOKEN),
        "content-type": "application/sparql-query",
      },
      data: "SELECT * WHERE { ?s ?p ?o } LIMIT 5",
    });

    // Two lawful outcomes only: real SPARQL JSON results, or the proxy's
    // typed 502 when the Ontop container is not running in this env.
    if (res.status() === 200) {
      const body = await res.json();
      expect(body).toHaveProperty("head.vars");
      expect(Array.isArray(body.head.vars)).toBe(true);
      expect(body).toHaveProperty("results.bindings");
      expect(Array.isArray(body.results.bindings)).toBe(true);
      expect(body.results.bindings.length).toBeLessThanOrEqual(5);
      for (const binding of body.results.bindings) {
        // W3C solution mapping: every binding value is { type, value }.
        for (const value of Object.values(binding)) {
          expect(value).toHaveProperty("type");
          expect(value).toHaveProperty("value");
        }
      }
    } else {
      expect(res.status()).toBe(502);
      const body = await res.json();
      expect(body).toHaveProperty("error", "ontop_unreachable");
      expect(typeof body.detail).toBe("string");
    }
  });
});
