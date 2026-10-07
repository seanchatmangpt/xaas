// @ts-check
const { test, expect } = require("@playwright/test");

/**
 * Execution-fabric authority court (wave-2 lane W3).
 *
 * Wire shape read from source (`lib/xaas_web/controllers/fabric_controller.ex`,
 * `actuate/2` -> `refused(conn, 403, "#{reason}:#{verb}")`, whose
 * `refused/3` helper emits {"standing":"REFUSED","reason":...} -- the SAME
 * typed refusal envelope every route in this controller uses):
 *   POST /internal-api/fabric/actuate is refused by authority ceiling in
 *   EVERY state -- HTTP 403 with the machine-readable body
 *   {"standing":"REFUSED","reason":"authority_ceiling:actuate"}.
 *
 * The spec asserts the parsed JSON body structurally (deep-equal on the
 * exact typed refusal object), never string-scraping. The route lives
 * behind the same `RequireInternalApiToken` gate as every /internal-api
 * route, so the token tests below also pin the gate's typed floors.
 */

const TOKEN = process.env.INTERNAL_API_TOKEN || "";

/** @param {string} token @returns {Record<string, string>} */
function authHeaders(token) {
  return token ? { Authorization: `Bearer ${token}` } : {};
}

test.describe("/internal-api/fabric authority ceiling", () => {
  test("actuate is 403 REFUSED(authority_ceiling:actuate) with the env token", async ({
    request,
  }) => {
    test.skip(!TOKEN, "INTERNAL_API_TOKEN not set in this environment");

    const res = await request.post("/internal-api/fabric/actuate", {
      headers: authHeaders(TOKEN),
      data: {},
    });
    expect(res.status()).toBe(403);

    // Machine-readable typed refusal, asserted structurally. W171: aligned
    // to the controller's real `refused/3` envelope ({"standing","reason"});
    // the earlier {"decision":"deny",...} expectation predated this
    // controller's actual wire shape (verified live: 403
    // {"reason":"authority_ceiling:actuate","standing":"REFUSED"}).
    const body = await res.json();
    expect(body).toEqual({
      standing: "REFUSED",
      reason: "authority_ceiling:actuate",
    });
  });

  test("actuate without a token is fail-closed (401/503, typed body)", async ({ request }) => {
    const res = await request.post("/internal-api/fabric/actuate", {
      headers: {},
      data: {},
    });

    if (process.env.INTERNAL_API_TOKEN) {
      expect(res.status()).toBe(401);
      expect(await res.json()).toEqual({
        error: "unauthorized",
        detail: "missing or invalid Bearer token",
      });
    } else {
      // Server env cannot have INTERNAL_API_TOKEN set -> fail-closed floor.
      expect(res.status()).toBe(503);
      expect(await res.json()).toEqual({
        error: "internal_api_misconfigured",
        detail: "INTERNAL_API_TOKEN is not set on the server",
      });
    }
  });

  test("fabric probe is reachable with the env token and reports the actuate refusal in capabilities", async ({
    request,
  }) => {
    test.skip(!TOKEN, "INTERNAL_API_TOKEN not set in this environment");

    // Cross-check from the probe surface: `refused` capabilities map the
    // authority ceiling (XaasWeb.FabricController.probe/2).
    const res = await request.get("/internal-api/fabric/probe", {
      headers: authHeaders(TOKEN),
    });
    expect(res.status()).toBe(200);

    const body = await res.json();
    expect(body.protocol).toBe("xaas-fabric/1");
    expect(body.refused).toBeInstanceOf(Object);
    expect(body.refused).toHaveProperty("actuate");
    expect(body.refused["actuate"]).toBe("authority_ceiling");
  });
});
