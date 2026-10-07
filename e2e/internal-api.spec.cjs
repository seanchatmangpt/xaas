// @ts-check
const { test, expect } = require("@playwright/test");

/**
 * Token-gated /internal-api coverage (wave-2 lane W3, X1 gap).
 *
 * Wire shapes asserted here are read from source, not string-scraped:
 *   - XaasWeb.Plugs.RequireInternalApiToken (lib/xaas_web/plugs/
 *     require_internal_api_token.ex): no/invalid Bearer token -> 401
 *     {"error":"unauthorized","detail":"missing or invalid Bearer token"};
 *     INTERNAL_API_TOKEN unset on the server -> fail-closed 503
 *     {"error":"internal_api_misconfigured", ...}.
 *   - XaasWeb.HealthController: 200 {"status":"ok"|"error","checks":{...}}
 *     (503 only on a real "error" check — "skipped" is not down, per the
 *     W836 court: under Oban testing:manual a fresh boot answers 200 with
 *     ultracode_tick skipped(:warming_up) inside the boot+7min grace;
 *     docs/sjira/v26.10.6/plans/w836-health-court.md).
 *   - XaasWeb.OcelSummaryController: 200 {"total_events":n,
 *     "by_activity":{...},"by_outcome":{...},"log_path": "..."}.
 *
 * The token comes from the environment (`INTERNAL_API_TOKEN`), the same
 * env the real dev server runs under (playwright.config.cjs reuses the
 * existing server). When that env var is absent this suite still runs and
 * asserts the fail-closed misconfigured floor (503, typed body) instead of
 * skipping -- never a false pass.
 */

const TOKEN = process.env.INTERNAL_API_TOKEN || "";

/** @param {string} token @returns {Record<string, string>} */
function authHeaders(token) {
  return token ? { Authorization: `Bearer ${token}` } : {};
}

test.describe("/internal-api token gate", () => {
  test("refuses /internal-api/health without a token (fail-closed, typed body)", async ({
    request,
  }) => {
    const res = await request.get("/internal-api/health", { headers: {} });
    const body = await res.json();

    if (process.env.INTERNAL_API_TOKEN) {
      // Server has the env token set -> real 401 unauthorized floor.
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

  test("refuses /internal-api/ocel_summary with an invalid token (401, typed body)", async ({
    request,
  }) => {
    const res = await request.get("/internal-api/ocel_summary", {
      headers: { Authorization: "Bearer definitely-not-a-real-token" },
    });

    // An invalid presented token is a 401 whenever the env token is set;
    // when it is unset the plug fails closed with 503. Both are typed.
    if (process.env.INTERNAL_API_TOKEN) {
      expect(res.status()).toBe(401);
      const body = await res.json();
      expect(body).toEqual({
        error: "unauthorized",
        detail: "missing or invalid Bearer token",
      });
    } else {
      expect(res.status()).toBe(503);
      const body = await res.json();
      expect(body).toEqual({
        error: "internal_api_misconfigured",
        detail: "INTERNAL_API_TOKEN is not set on the server",
      });
    }
  });

  test("serves real health data with the env token", async ({ request }) => {
    test.skip(!TOKEN, "INTERNAL_API_TOKEN not set in this environment");

    const res = await request.get("/internal-api/health", {
      headers: authHeaders(TOKEN),
    });
    expect(res.status()).toBe(200);

    const body = await res.json();
    // W836 pinned contract: aggregate stays 200/"ok" while ultracode_tick
    // is skipped(:warming_up) inside the boot+7min grace (fresh-boot e2e).
    expect(body.status).toBe("ok");
    expect(body.checks).toBeInstanceOf(Object);
    // Real checks, not stubs: repo + ontop + ultracode tick + 7 domains.
    expect(body.checks).toHaveProperty("repo");
    expect(body.checks.repo).toMatchObject({ status: "ok" });
    expect(body.checks).toHaveProperty("ontop");
    // ultracode_tick: "ok" (real ticks flowing) or typed warming_up skip —
    // never an "error" inside the fresh-boot grace window.
    expect(["ok", "skipped"]).toContain(body.checks.ultracode_tick.status);
    if (body.checks.ultracode_tick.status === "skipped") {
      expect(body.checks.ultracode_tick).toMatchObject({ reason: "warming_up" });
    }
    expect(body.checks).toHaveProperty("ash_domain:accounts");
    for (const check of Object.values(body.checks)) {
      expect(check).toHaveProperty("latency_ms");
    }
  });

  test("serves real OCEL summary data with the env token", async ({ request }) => {
    test.skip(!TOKEN, "INTERNAL_API_TOKEN not set in this environment");

    const res = await request.get("/internal-api/ocel_summary", {
      headers: authHeaders(TOKEN),
    });
    expect(res.status()).toBe(200);

    const body = await res.json();
    expect(typeof body.total_events).toBe("number");
    expect(body.total_events).toBeGreaterThanOrEqual(0);
    expect(body.by_activity).toBeInstanceOf(Object);
    expect(body.by_outcome).toBeInstanceOf(Object);
    expect(typeof body.log_path).toBe("string");
    expect(body.log_path.length).toBeGreaterThan(0);
    // Outcome vocabulary is the real emitter's: ok/error/unknown.
    for (const outcome of Object.keys(body.by_outcome)) {
      expect(["ok", "error", "unknown"]).toContain(outcome);
    }
  });
});
