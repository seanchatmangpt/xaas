// @ts-check
// W688 — wire-level e2e courts for the synthetic-marking surface:
// XaasWeb.Plugs.SyntheticMarkingPlug (W533, EU AI Act Art. 50(2)).
//
// Contract source (read from the modules, not guessed):
//   lib/xaas_web/plugs/synthetic_marking_plug.ex — endpoint plug keyed on
//     POST + path_info ["a2a" | _] / ["mcp" | _]; registers before_send and
//     stamps `x-ai-generated: true` (header) plus a top-level
//     `ai_generated: true` JSON field where the body is a JSON object.
//   lib/xaas_web/endpoint.ex:99 — mounted BEFORE EuAiActAdmissionPlug, so
//     W521 refusal envelopes are marked too (before_send runs for halted
//     conns).
//   test/xaas_web/synthetic_marking_test.exs — the plug-level contract this
//     suite re-proves through the real running server over real HTTP.
//
// Auth: the /a2a and /mcp scopes sit behind :require_internal_api_token
// (same Bearer gate as /api). INTERNAL_API_TOKEN comes from the runner
// environment, passed through webServer.env by playwright.config.cjs —
// the established pattern (e2e/mcp-a2a.spec.cjs). No bypass invented.
const { test, expect } = require("@playwright/test");

const TOKEN = process.env.INTERNAL_API_TOKEN || "";

function authHeaders(extra = {}) {
  return TOKEN ? { Authorization: `Bearer ${TOKEN}`, ...extra } : { ...extra };
}

const JSON_HEADERS = {
  "Content-Type": "application/json",
  Accept: "application/json",
};

test.describe("synthetic marking (W533) over real HTTP", () => {
  test("(a) POST /a2a response carries x-ai-generated: true + ai_generated field", async ({
    request,
  }) => {
    const resp = await request.post("/a2a", {
      headers: authHeaders(JSON_HEADERS),
      data: {
        jsonrpc: "2.0",
        id: 1,
        method: "message/send",
        params: {
          message: {
            role: "user",
            parts: [{ kind: "text", text: "w688 marking probe" }],
          },
        },
      },
    });

    // Marking is unconditional on the AI surface, whatever the handler
    // answers (200 envelope, 4xx...). Assert the two markings.
    expect(resp.headers()["x-ai-generated"]).toBe("true");
    const body = await resp.json();
    expect(body["ai_generated"]).toBe(true);
  });

  test("(b1) W521 Art. 5 admission refusal envelope is marked", async ({
    request,
  }) => {
    // EuAiActAdmission refuses candidates whose techniques include
    // :manipulate_behavior (REFUSED_EUAIA_MANIPULATIVE); the refusal
    // envelope is JSON-RPC 2.0 over HTTP 200, code -32600, typed refusal
    // atom in error.data.refusal.
    const resp = await request.post("/a2a", {
      headers: authHeaders(JSON_HEADERS),
      data: {
        jsonrpc: "2.0",
        id: 2,
        method: "message/send",
        params: {
          techniques: ["manipulate_behavior"],
          purpose: "e2e marking court",
          note: "w688 refusal marking probe",
        },
      },
    });

    expect(resp.status()).toBe(200);
    expect(resp.headers()["x-ai-generated"]).toBe("true");
    const body = await resp.json();
    expect(body["error"]["code"]).toBe(-32600);
    expect(body["error"]["data"]["refusal"]).toMatch(/^REFUSED_EUAIA/);
    expect(body["ai_generated"]).toBe(true);
  });

  test("(b2) token-floor 401 refusal on POST /a2a is marked", async ({
    request,
  }) => {
    const resp = await request.post("/a2a", {
      headers: JSON_HEADERS, // deliberately no Authorization header
      data: { jsonrpc: "2.0", id: 3, method: "message/send" },
    });

    expect(resp.status()).toBe(401);
    expect(resp.headers()["x-ai-generated"]).toBe("true");
    const body = await resp.json();
    expect(body["ai_generated"]).toBe(true);
    expect(body["error"]).toBe("unauthorized");
  });

  test("(c1) non-AI path (POST under /internal-api) is unmarked", async ({
    request,
  }) => {
    // Token-floor refusal on /internal-api: 401 (or 503 when the server
    // itself is tokenless). Neither is an AI surface — no marking.
    // (No Accept header: the fail-closed 401 path 406s on Accept: application/json.)
    const resp = await request.post("/internal-api/health", {
      headers: { "Content-Type": "application/json" }, // no Authorization
      data: {},
    });

    expect([401, 503]).toContain(resp.status());
    expect(resp.headers()["x-ai-generated"]).toBeUndefined();
    const body = await resp.json();
    expect(body["ai_generated"]).toBeUndefined();
  });

  test("(c2) GET on /a2a (agent card path) is unmarked — marking is POST-keyed", async ({
    request,
  }) => {
    const resp = await request.get("/a2a/v1/.well-known/agent-card.json", {
      headers: authHeaders(),
    });

    expect(resp.status()).toBe(200);
    expect(resp.headers()["x-ai-generated"]).toBeUndefined();
  });
});
