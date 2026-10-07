// @ts-check
// Real Playwright courts for the /mcp and /a2a protocol surfaces.
const { test, expect } = require("@playwright/test");

/**
 * Fleet-proxy coverage for the MCP and A2A surfaces (X1 gap close, lane W4).
 *
 * Routes (lib/xaas_web/router.ex):
 *
 *   /mcp  scope (router.ex:175-184): pipeline [:api,
 *     :require_internal_api_token, :resolve_org_actor, :audit_mcp_tool_call],
 *     mounting AshAi.Mcp.Router with the three generated Library tools
 *     (XaasWeb.McpScope: list_books, books_by_grade_band,
 *     active_curations_for_grade; protocol_version_statement 2024-11-05).
 *     An MCP caller is NOT a separate trust tier -- same Bearer gate as
 *     /api. The :audit_mcp_tool_call pipeline writes one real
 *     Xaas.Operations.AuditLogEntry row per /mcp HTTP request.
 *
 *   /a2a scope (router.ex:195-210): pipeline [:api,
 *     :require_internal_api_token] forwarding to A2A.Plug with
 *     XaasWeb.A2A.NextReadUserAgent (catch-all) and, declared first,
 *     XaasWeb.A2A.ZoeEventPlug at /a2a/zoe-event. NOTE (source-read
 *     correction to the lane brief): the A2A agent-card fetch is NOT
 *     unauthenticated -- the whole /a2a scope sits behind the same
 *     :require_internal_api_token Bearer gate as /mcp, so the card is
 *     asserted WITH the real token, and the no-token case asserts the
 *     plug's typed 401 refusal instead.
 *
 * Typed auth refusals (lib/xaas_web/plugs/require_internal_api_token.ex):
 *   401 {"error":"unauthorized","detail":"missing or invalid Bearer token"}
 *   503 {"error":"internal_api_misconfigured", ...} if server env unset.
 *
 * Agent-card wire shape asserted from the real modules: card is built by
 * A2A.JSON.encode_agent_card/2 (deps/a2a/lib/a2a/json.ex:246-295) from
 * XaasWeb.A2A.NextReadUserAgent's `use A2A.Agent` card
 * (name "next-read-user", skills from the generated
 * XaasWeb.A2A.NextReadUserAgentSkills: browse / checkout / hddl-plan) with
 * `url` from the router's base_url option, camelCase optional fields, and
 * a default supportedInterfaces entry of
 * {url, protocolBinding "jsonrpc", protocolVersion "2.0"}.
 */

const TOKEN = process.env.INTERNAL_API_TOKEN || "";
const AUTH_HEADERS = {
  Authorization: `Bearer ${TOKEN}`,
  "Content-Type": "application/json",
  Accept: "application/json",
};

test.describe("mcp surface", () => {
  test("typed auth refusal without token on POST /mcp", async ({ request }) => {
    const resp = await request.post("/mcp", {
      headers: { Accept: "application/json", "Content-Type": "application/json" },
      data: {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/list",
      },
    });
    expect([401, 503]).toContain(resp.status());
    const body = await resp.json();
    if (resp.status() === 401) {
      expect(body.error).toBe("unauthorized");
      expect(typeof body.detail).toBe("string");
    } else {
      expect(body.error).toBe("internal_api_misconfigured");
    }
  });

  test("with token: POST /mcp passes the real Bearer gate (not a 401/503 auth refusal)", async ({ request }) => {
    // With the real token the request gets past :require_internal_api_token
    // and into the real MCP router; whatever the protocol layer decides
    // about method shape, the auth court is that the typed 401/503 auth
    // refusal body no longer appears.
    const resp = await request.post("/mcp", {
      headers: AUTH_HEADERS,
      data: {
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: "2024-11-05",
          capabilities: {},
          clientInfo: { name: "xaas-e2e-court", version: "0.0.1" },
        },
    },
    });
    expect(resp.status()).not.toBe(401);
    expect(resp.status()).not.toBe(503);
    const body = await resp.json();
    // JSON-RPC surface stays machine-readable: either a real result or a
    // typed JSON-RPC error object, never a bare string.
    expect(body).toBeInstanceOf(Object);
    expect(
      body.result !== undefined || (body.error !== undefined && typeof body.error === "object")
    ).toBe(true);
  });
});

test.describe("a2a surface", () => {
  test("typed auth refusal without token on the agent card endpoint", async ({ request }) => {
    const resp = await request.get("/a2a/.well-known/agent-card.json");
    expect([401, 503]).toContain(resp.status());
    const body = await resp.json();
    if (resp.status() === 401) {
      expect(body.error).toBe("unauthorized");
    } else {
      expect(body.error).toBe("internal_api_misconfigured");
    }
  });

  test("agent card with token: real A2A card fields from XaasWeb.A2A.NextReadUserAgent", async ({ request }) => {
    const resp = await request.get("/a2a/.well-known/agent-card.json", { headers: AUTH_HEADERS });
    expect(resp.status()).toBe(200);
    const card = await resp.json();
    // Required keys per A2A.JSON.encode_agent_card/2 + A2A.AgentCard
    expect(card.name).toBe("next-read-user");
    expect(typeof card.description).toBe("string");
    expect(card.version).toBe("0.1.0");
    expect(card.url).toContain("/a2a");
    expect(Array.isArray(card.skills)).toBe(true);
    expect(card.skills.length).toBeGreaterThanOrEqual(3);
    const skillIds = card.skills.map((/** @type {any} */ s) => s.id);
    for (const expected of ["browse", "checkout", "hddl-plan"]) {
      expect(skillIds).toContain(expected);
    }
    for (const skill of card.skills) {
      expect(typeof skill.name).toBe("string");
      expect(typeof skill.description).toBe("string");
      expect(Array.isArray(skill.tags)).toBe(true);
    }
    expect(card.defaultInputModes).toContain("text/plain");
    expect(card.defaultOutputModes).toContain("text/plain");
    expect(Array.isArray(card.supportedInterfaces)).toBe(true);
    expect(card.supportedInterfaces.length).toBeGreaterThan(0);
    const iface = card.supportedInterfaces[0];
    expect(iface.protocolBinding).toBe("jsonrpc");
    expect(iface.protocolVersion).toBe("2.0");
  });

  test("zoe-event agent card with token: zoe-event-simulation agent", async ({ request }) => {
    const resp = await request.get("/a2a/zoe-event/.well-known/agent-card.json", { headers: AUTH_HEADERS });
    expect(resp.status()).toBe(200);
    const card = await resp.json();
    expect(card.name).toBe("zoe-event-simulation");
    expect(Array.isArray(card.skills)).toBe(true);
    expect(card.skills.length).toBeGreaterThan(0);
  });
});
