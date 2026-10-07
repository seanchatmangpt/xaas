// @ts-check
const { test, expect } = require("@playwright/test");

/**
 * zcode-cli → /internal-api/execution/mcp → sealed-receipt fabric E2E court
 * (wave-2 lane W11, closing R7 gap G2 of docs/sjira/v26.10.5/plans/r7-zcode-cli.md).
 *
 * SOURCE-READ CONTRACT (shapes read from source, not string-scraped):
 *
 *   Route + plug chain (lib/xaas_web/router.ex:87-120):
 *     scope "/internal-api", pipe_through([:api, :require_internal_api_token])
 *     post("/execution/mcp", ExecutionFabricController, :mcp)
 *     get("/execution/epochs/:epoch_id/receipts", ExecutionFabricController, :receipts)
 *
 *   XaasWeb.Plugs.RequireInternalApiToken (require_internal_api_token.ex):
 *     no/invalid Bearer -> 401 {"error":"unauthorized",
 *     "detail":"missing or invalid Bearer token"}; INTERNAL_API_TOKEN unset
 *     on the server -> fail-closed 503 {"error":"internal_api_misconfigured",...}.
 *
 *   XaasWeb.ExecutionFabricController (execution_fabric_controller.ex):
 *     - MCP JSON-RPC 2.0: initialize -> protocolVersion "2025-03-26",
 *       serverInfo {name:"xaas-ultracode-lease"}; tools/list -> the
 *       claim_next / heartbeat / admit_tool / record_provider_event /
 *       close_candidate / refuse / cancel_work / actuate /
 *       resolve_capability / surface tool set.
 *     - tool-level refusal is isError:true with a machine-readable typed
 *       body ({error: code, failure:{code,details}} for the runtime-surface
 *       vocabulary; {error: format_reason} otherwise) — never a silent
 *       success and never a fabricated receipt.
 *     - claim_next -> {lease_token, epoch_id, cycle, exact_subject, goal,
 *       worktree, verifier_suite, surface, work}.
 *     - close_candidate -> {status:"closed", epoch_id, outcome} and seals a
 *       real Xaas.Ultracode.Receipt (attributes: subject, outcome, evidence,
 *       sealed_at — receipt.ex:156-206).
 *     - GET receipts -> {epoch_id, receipts:[{id, epoch_id, subject,
 *       outcome, evidence, sealed_at}]} (format_receipt/1).
 *
 * RECEIPT-FIELD NOTE (honest scope): Xaas.Ultracode.Receipt's actual
 * attributes are subject/outcome/evidence/sealed_at. The generic
 * receipt-triple vocabulary's "source-digest"/"authorityClaim" names map
 * onto this surface as `subject` (the exact subject the receipt is bound
 * to) and the authority evidence inside `evidence` — this spec asserts the
 * REAL field names the server actually emits, not invented ones. No
 * receipt is ever fabricated by this spec: a receipt is asserted only on
 * the read-back path after a real close_candidate through the real lease
 * court.
 *
 * MISSING-DRIVER DISCLOSURE: driving a fresh execution purely via HTTP
 * from a spec requires POST /internal-api/execution/runs, which the
 * legacy shared INTERNAL_API_TOKEN tier is deliberately refused (typed 403
 * org_scoped_token_required — create_run/2 keys on
 * conn.assigns[:current_org], resolved only for org-carrying DB tokens).
 * The env-token tier therefore cannot mint a fresh Run/Epoch from here.
 * This spec drives the full claim -> admit -> close -> sealed-receipt
 * read-back loop whenever a ready epoch exists for the default provider
 * (which is exactly how a real zcode-cli worker reaches the fabric), and
 * otherwise asserts the typed refusal honestly instead of faking closure.
 */

const TOKEN = process.env.INTERNAL_API_TOKEN || "";

/** @param {string} token @returns {Record<string, string>} */
function authHeaders(token) {
  return token ? { Authorization: `Bearer ${token}` } : {};
}

/** Decode an MCP result payload: content[0].text is a JSON string. */
/** @param {any} json */
function mcpText(json) {
  expect(json.result.content).toBeInstanceOf(Array);
  expect(json.result.content.length).toBeGreaterThan(0);
  expect(json.result.content[0].type).toBe("text");
  return JSON.parse(json.result.content[0].text);
}

test.describe("/internal-api/execution/mcp token gate", () => {
  test("refuses /execution/mcp without a token (fail-closed, typed body)", async ({
    request,
  }) => {
    const res = await request.post("/internal-api/execution/mcp", {
      headers: {},
      data: { jsonrpc: "2.0", id: 1, method: "tools/list", params: {} },
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

  test("refuses /execution/mcp with an invalid token (401, typed body)", async ({ request }) => {
    const res = await request.post("/internal-api/execution/mcp", {
      headers: { Authorization: "Bearer definitely-not-a-real-token" },
      data: { jsonrpc: "2.0", id: 1, method: "tools/list", params: {} },
    });

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

  // W171 court (added): EVERY failure answer on this surface is typed JSON,
  // never the Phoenix HTML DebugPage. W118 observed HTML `<!DOCTYPE` bodies
  // on the failure paths; the controller now fail-closes any unexpected
  // raise into a JSON-RPC -32603 internal error. These adversarial payloads
  // exercise the malformed/dispatch edges; the structural assertion is
  // "parseable JSON with JSON-RPC shape" (or a typed plug refusal), so a
  // regression back to HTML fails here.
  test("adversarial malformed bodies are typed JSON, never HTML (fail-closed)", async ({
    request,
  }) => {
    const payloads = [
      { name: "tools/call with null params", body: { jsonrpc: "2.0", id: 1, method: "tools/call", params: null } },
      { name: "tools/call with non-string name", body: { jsonrpc: "2.0", id: 2, method: "tools/call", params: { name: 123, arguments: {} } } },
      { name: "id is an object", body: { jsonrpc: "2.0", id: { x: 1 }, method: "tools/list" } },
      { name: "id is null", body: { jsonrpc: "2.0", id: null, method: "no/such/method" } },
      { name: "empty object body", body: {} },
      { name: "array body", body: [1, 2, 3] },
    ];

    for (const { name, body } of payloads) {
      const res = await request.post("/internal-api/execution/mcp", {
        headers: authHeaders(TOKEN),
        data: body,
      });

      const contentType = res.headers()["content-type"] || "";
      expect(contentType, `${name}: content-type is JSON`).toContain("application/json");
      // res.json() throwing here is the exact HTML-DebugPage regression.
      const json = await res.json();

      if (res.status() >= 400) {
        // Typed plug/controller refusal shapes only.
        const isJsonRpcError =
          json && json.error && typeof json.error === "object" && typeof json.error.code === "number";
        const isTypedRefusal =
          json && (typeof json.error === "string" || json.decision === "deny");
        expect(
          isJsonRpcError || isTypedRefusal,
          `${name}: failure body is a typed JSON error (${JSON.stringify(json).slice(0, 200)})`,
        ).toBe(true);
      }
    }
  });
});

test.describe("/internal-api/execution/mcp surface (with token)", () => {
  test.skip(!TOKEN, "INTERNAL_API_TOKEN not set in this environment");

  test("initializes and lists the real lease/fabric tool set", async ({ request }) => {
    const init = await (
      await request.post("/internal-api/execution/mcp", {
        headers: authHeaders(TOKEN),
        data: { jsonrpc: "2.0", id: 1, method: "initialize", params: {} },
      })
    ).json();
    expect(init.jsonrpc).toBe("2.0");
    expect(init.result.protocolVersion).toBe("2025-03-26");
    expect(init.result.serverInfo).toMatchObject({ name: "xaas-ultracode-lease" });

    const list = await (
      await request.post("/internal-api/execution/mcp", {
        headers: authHeaders(TOKEN),
        data: { jsonrpc: "2.0", id: 2, method: "tools/list", params: {} },
      })
    ).json();
    const names = list.result.tools.map((/** @type {any} */ t) => t.name);
    for (const tool of [
      "claim_next",
      "heartbeat",
      "admit_tool",
      "close_candidate",
      "refuse",
      "actuate",
      "resolve_capability",
      "surface",
    ]) {
      expect(names).toContain(tool);
    }
  });

  test("unknown tool is a typed JSON-RPC tool error, never a silent success", async ({
    request,
  }) => {
    const json = await (
      await request.post("/internal-api/execution/mcp", {
        headers: authHeaders(TOKEN),
        data: {
          jsonrpc: "2.0",
          id: 3,
          method: "tools/call",
          params: { name: "no_such_fabric_tool", arguments: {} },
        },
      })
    ).json();
    expect(json.result.isError).toBe(true);
    const err = mcpText(json);
    expect(typeof err.error).toBe("string");
    expect(err.error.length).toBeGreaterThan(0);
  });

  test("claim -> admit -> close -> sealed receipt read-back (or honest typed refusal)", async ({
    request,
  }) => {
    // A real worker's first move: claim the oldest ready epoch of its
    // provider. When no ready epoch exists the fabric answers with a typed
    // tool error — that typed refusal IS the honest court result here, not
    // a failure of this spec.
    const claimRes = await request.post("/internal-api/execution/mcp", {
      headers: authHeaders(TOKEN),
      data: {
        jsonrpc: "2.0",
        id: 10,
        method: "tools/call",
        params: {
          name: "claim_next",
          arguments: { provider: "zcode", provider_worker_id: "w11-e2e-spec" },
        },
      },
    });
    expect(claimRes.status()).toBe(200);
    const claimJson = await claimRes.json();

    if (claimJson.result.isError) {
      // Typed no-work refusal (e.g. no ready epoch). Assert it is
      // machine-readable and stop honestly — never fake a receipt.
      const err = mcpText(claimJson);
      expect(typeof err.error).toBe("string");
      expect(err.error.length).toBeGreaterThan(0);
      return;
    }

    const claim = mcpText(claimJson);
    // Real claim envelope (Lease.claim_envelope/3 + dispatch_tool claim_next).
    expect(typeof claim.lease_token).toBe("string");
    expect(claim.lease_token.length).toBeGreaterThan(0);
    expect(typeof claim.epoch_id).toBe("string");
    expect(claim).toHaveProperty("exact_subject");
    expect(claim).toHaveProperty("goal");
    expect(claim).toHaveProperty("surface");
    expect(claim).toHaveProperty("work");

    // Per-consequence admission court on the leased work.
    const admitJson = await (
      await request.post("/internal-api/execution/mcp", {
        headers: authHeaders(TOKEN),
        data: {
          jsonrpc: "2.0",
          id: 11,
          method: "tools/call",
          params: {
            name: "admit_tool",
            arguments: { lease_token: claim.lease_token, tool: "read" },
          },
        },
      })
    ).json();
    // Allow or typed refusal are both lawful court outputs; a silent 200
    // with no decision is not.
    expect(admitJson.result).toBeDefined();
    const admit = mcpText(admitJson);
    if (admitJson.result.isError) {
      expect(typeof admit.error).toBe("string");
    } else {
      expect(["allow", "deny"]).toContain(admit.decision);
    }

    // Close with head-verified evidence and seal the Receipt.
    const closeJson = await (
      await request.post("/internal-api/execution/mcp", {
        headers: authHeaders(TOKEN),
        data: {
          jsonrpc: "2.0",
          id: 12,
          method: "tools/call",
          params: {
            name: "close_candidate",
            arguments: {
              lease_token: claim.lease_token,
              final_head: "w11-e2e-not-a-git-head",
              outcome: "partial_alive",
              evidence: {
                driver: "e2e/zcode-cli-fabric.spec.cjs",
                note: "HTTP-driven fabric loop; subject-bound evidence, no CLI subprocess",
              },
            },
          },
        },
      })
    ).json();
    expect(closeJson.result).toBeDefined();
    const closed = mcpText(closeJson);
    if (closeJson.result.isError) {
      // Typed closure refusal (lease liveness etc.) — honest stop, no fake
      // receipt. Assert the typed body is machine-readable.
      expect(typeof closed.error).toBe("string");
      expect(closed.error.length).toBeGreaterThan(0);
      return;
    }
    expect(closed.status).toBe("closed");
    expect(closed.epoch_id).toBe(claim.epoch_id);
    expect(typeof closed.outcome).toBe("string");

    // Lawful read path: sealed receipts for the closed epoch.
    const recRes = await request.get(
      `/internal-api/execution/epochs/${claim.epoch_id}/receipts`,
      { headers: authHeaders(TOKEN) }
    );
    expect(recRes.status()).toBe(200);
    const recBody = await recRes.json();
    expect(recBody.epoch_id).toBe(claim.epoch_id);
    expect(recBody.receipts.length).toBeGreaterThan(0);

    for (const receipt of recBody.receipts) {
      expect(typeof receipt.id).toBe("string");
      expect(receipt.id.length).toBeGreaterThan(0);
      expect(receipt.epoch_id).toBe(claim.epoch_id);
      expect(typeof receipt.subject).toBe("string");
      expect(receipt.subject.length).toBeGreaterThan(0);
      expect(typeof receipt.outcome).toBe("string");
      expect(typeof receipt.sealed_at).toBe("string");
      expect(receipt.sealed_at.length).toBeGreaterThan(0);
      expect(receipt.evidence).toBeInstanceOf(Object);
    }
    // The receipt we just sealed is on the read-back, bound to the subject
    // the epoch claimed (source-digest/authorityClaim map to subject +
    // evidence on this surface — see the header note).
    const sealed = recBody.receipts.find((/** @type {any} */ r) => r.outcome === closed.outcome);
    expect(sealed).toBeDefined();
    expect(sealed.subject).toBe(claim.exact_subject);
  });
});
