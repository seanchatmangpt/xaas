// @ts-check
const { test, expect } = require("@playwright/test");

/**
 * Fleet-proxy coverage for the GGen workbench HTTP surface (X1 gap close).
 *
 * Routes (lib/xaas_web/router.ex:217-222, registered before the `/api`
 * forward catch-all so it cannot be shadowed):
 *
 *   GET  /api/workbench/ggen/health  -> GgenWorkbenchController.health/2
 *   POST /api/workbench/ggen         -> GgenWorkbenchController.run/2
 *
 * Both routes sit behind `:require_internal_api_token`
 * (XaasWeb.Plugs.RequireInternalApiToken). Its real, typed refusals:
 *
 *   401 {"error":"unauthorized","detail":"missing or invalid Bearer token"}
 *     when a token is presented but invalid / absent while the server's
 *     INTERNAL_API_TOKEN env var is set (lib/xaas_web/plugs/
 *     require_internal_api_token.ex:136-144)
 *   503 {"error":"internal_api_misconfigured", ...} when the server env var
 *     is unset (fail closed)
 *
 * Controller contract (lib/xaas_web/controllers/ggen_workbench_controller.ex):
 * every response advertises the canonical AsyncAPI 3.1 service description
 * through the `service-desc` Web Link relation
 * (</asyncapi.yaml>; rel="service-desc"; type="application/yaml"), and every
 * admission refusal is machine-readable typed standing, never a string:
 *
 *   422 {"standing":"REFUSED[<CODE>]","refused":true,"detail":...}
 *   503 REFUSED[WORKBENCH_NOT_CONFIGURED | WORKBENCH_TOKEN_MISSING] (env-gated)
 *   502 {"standing":"BLOCKED","blocked":true,...} on upstream transport failure
 *
 * Admission codes proven by Xaas.Workbench.GgenClient.validate_payload/1
 * (lib/xaas/workbench/ggen_client.ex): INVALID_REQUEST, INVALID_ARGS,
 * INVALID_ARG, ARGS_LIMIT, INVALID_FILES, INVALID_FILE_CONTENT, INVALID_PATH,
 * UNSAFE_PATH, FILE_LIMIT, INPUT_LIMIT, INVALID_BASE64, INVALID_TIMEOUT.
 */

const TOKEN = process.env.INTERNAL_API_TOKEN || "";
const AUTH_HEADERS = {
  Authorization: `Bearer ${TOKEN}`,
  "Content-Type": "application/json",
};

test.describe("ggen workbench surface (token-gated)", () => {
  for (const route of ["/api/workbench/ggen/health", "/api/workbench/ggen"]) {
    test(`typed auth refusal without token: ${route}`, async ({ request }) => {
      const noAuth = await request.get(route, { headers: { Accept: "application/json" } });
      expect([401, 503]).toContain(noAuth.status());
      const body = await noAuth.json();
      // Machine-readable typed refusal, never a string-scrape.
      if (noAuth.status() === 401) {
        expect(body.error).toBe("unauthorized");
        expect(typeof body.detail).toBe("string");
      } else {
        expect(body.error).toBe("internal_api_misconfigured");
      }
      // Same typed refusal for the POST route -- no token, no construction.
      const noAuthPost = await request.post(route, {
        headers: { Accept: "application/json", "Content-Type": "application/json" },
        data: { args: ["--version"] },
      });
      expect([401, 503]).toContain(noAuthPost.status());
      const postBody = await noAuthPost.json();
      expect(["unauthorized", "internal_api_misconfigured"]).toContain(postBody.error);
    });
  }

  test("health with token: typed JSON + AsyncAPI service-desc Link header", async ({ request }) => {
    const resp = await request.get("/api/workbench/ggen/health", { headers: AUTH_HEADERS });
    // Two real, env-dependent outcomes, both machine-readable:
    //   200: worker configured and reachable (GgenClient.health/0 {:ok, body})
    //   503: typed REFUSED[WORKBENCH_NOT_CONFIGURED | WORKBENCH_TOKEN_MISSING]
    // Either way the AsyncAPI contract advertisement is unconditional.
    expect(resp.headers()["link"]).toContain('rel="service-desc"');
    expect(resp.headers()["content-type"]).toContain("application/json");
    const body = await resp.json();
    expect(body).toBeInstanceOf(Object);
    if (resp.status() === 503) {
      expect(body.standing).toMatch(/^REFUSED\[WORKBENCH_(NOT_CONFIGURED|TOKEN_MISSING)\]$/);
      expect(body.refused).toBe(true);
    } else {
      expect(resp.ok()).toBeTruthy();
    }
  });

  test("run with token: local admission fence refuses oversized argv as typed 422 REFUSED[ARGS_LIMIT]", async ({ request }) => {
    // Deterministic local court: GgenClient admission runs on the control
    // plane BEFORE any upstream worker call (validate_args, > @max_args=64).
    const tooManyArgs = Array.from({ length: 65 }, (_, i) => `--flag-${i}`);
    const resp = await request.post("/api/workbench/ggen", {
      headers: AUTH_HEADERS,
      data: { args: tooManyArgs },
    });
    expect(resp.status()).toBe(422);
    const body = await resp.json();
    expect(body.standing).toBe("REFUSED[ARGS_LIMIT]");
    expect(body.refused).toBe(true);
    expect(typeof body.detail).toBe("string");
    expect(resp.headers()["link"]).toContain('rel="service-desc"');
  });

  test("run with token: unsafe traversal path refused as typed 422 REFUSED[UNSAFE_PATH]", async ({ request }) => {
    const resp = await request.post("/api/workbench/ggen", {
      headers: AUTH_HEADERS,
      data: {
        args: ["sync"],
        files: { "../escape.txt": "nope" },
      },
    });
    expect(resp.status()).toBe(422);
    const body = await resp.json();
    expect(body.standing).toBe("REFUSED[UNSAFE_PATH]");
    expect(body.refused).toBe(true);
  });

  test("run with token: non-integer timeout refused as typed 422 REFUSED[INVALID_TIMEOUT]", async ({ request }) => {
    const resp = await request.post("/api/workbench/ggen", {
      headers: AUTH_HEADERS,
      data: { args: ["--version"], timeout_ms: "forever" },
    });
    expect(resp.status()).toBe(422);
    const body = await resp.json();
    expect(body.standing).toBe("REFUSED[INVALID_TIMEOUT]");
    expect(body.refused).toBe(true);
  });
});
