// @ts-check
const { test, expect } = require("@playwright/test");

/**
 * A2A v1 (ash_a2a Protocol.Plug) surface courts — wave-2 lane W10 (v26.10.6
 * convergence), per docs/sjira/v26.10.5/plans/r4-a2a.md §5.D.
 *
 * STATUS: BLOCKED (seam) — these courts target the FUTURE additive mount
 * `POST/GET /a2a/v1` (router-line proposal in the file-top comment of
 * lib/xaas_web/a2a/next_read_ash_agent.ex). The mount does not exist in
 * router.ex yet; unblocking is exactly one coordinator seam edit (the
 * forward line). The ash_a2a pin bump already landed (86214551, v26.10.4)
 * and the adapter module compiles clean at it.
 *
 * Contract source: /Users/sac/ash_a2a @ 07180bd3 (v26.10.5) —
 * lib/asha2a/protocol/plug.ex and docs/reference/a2a-endpoint-contract.md.
 * Auth model: single token-gate floor (pipe_through
 * [:api, :require_internal_api_token]); NO second AshA2A.Protocol.Plug.Auth
 * stack (analysis + recommendation in the adapter moduledoc). So: no token
 * -> the Phoenix pipeline 401s; valid token -> the plug runs bare.
 *
 * Wire notes (read from plug.ex, not guessed):
 *   - card path GET /a2a/v1/.well-known/agent-card.json; non-GET on that
 *     path -> 405 with Allow: GET (plug.ex:191-196).
 *   - POST /a2a/v1 = JSON-RPC 2.0 over HTTP 200 envelope. Malformed JSON ->
 *     parse error -32700. Unknown method -> -32601. Unsupported A2A-Version
 *     header -> -32009 (default supported versions ["0.3", "1.0"]).
 *   - message/send -> result.task (or result.message for bare-message
 *     replies, ash_a2a Protocol.Agent docs). message/stream -> SSE.
 *   - usage text command: "as:guest browse grade:3" -> {:reply, ...} ->
 *     task :completed with artifact.
 */

const TOKEN = process.env.INTERNAL_API_TOKEN || "";
const BASE = "/a2a/v1";

function authHeaders(extra = {}) {
  return TOKEN ? { Authorization: `Bearer ${TOKEN}`, ...extra } : { ...extra };
}

/**
 * @param {any} id
 * @param {string} method
 * @param {any} params
 */
function rpc(id, method, params) {
  return { jsonrpc: "2.0", id, method, params };
}

// W270 alignment: the v1.0 wire enum is ROLE_USER (AshA2A.Protocol.JSON
// @role_to_string); the bare "user" the spec used to send is invalid_role
// on the wire — W217 curl ground truth.
const BROWSE_MESSAGE = {
  messageId: "w10-msg-001",
  role: "ROLE_USER",
  parts: [{ kind: "text", text: "as:guest browse grade:3" }],
};

test.describe("A2A v1 surface (/a2a/v1)", () => {
  test("agent card: 200 with required v1 fields", async ({ request }) => {
    const res = await request.get(`${BASE}/.well-known/agent-card.json`, {
      headers: authHeaders(),
    });

    expect(res.status()).toBe(200);
    const card = await res.json();

    // Required members (AgentCard proto; v1.0 carries url per-interface).
    expect(card.name).toBeTruthy();
    expect(card.description).toBeTruthy();
    expect(card.version).toBeTruthy();
    expect(Array.isArray(card.skills) && card.skills.length > 0).toBe(true);
    for (const skill of card.skills) {
      expect(skill.id).toBeTruthy();
      expect(skill.name).toBeTruthy();
      expect(skill.description).toBeTruthy();
      expect(Array.isArray(skill.tags)).toBe(true);
    }
    expect(card.supportedInterfaces).toBeTruthy();
    expect(card.supportedInterfaces[0].url).toBeTruthy();
    expect(card.supportedInterfaces[0].protocolBinding).toBe("JSONRPC");
    expect(card.capabilities).toBeTruthy();
  });

  test("agent card path rejects wrong method (405, Allow: GET)", async ({
    request,
  }) => {
    const res = await request.post(`${BASE}/.well-known/agent-card.json`, {
      headers: authHeaders(),
      data: {},
    });
    expect(res.status()).toBe(405);
    expect(res.headers()["allow"]).toBe("GET");
  });

  test("refuses requests without a token (single auth floor)", async ({
    request,
  }) => {
    const res = await request.post(BASE, {
      headers: {}, // deliberately no Authorization header
      data: rpc(1, "message/send", { message: BROWSE_MESSAGE }),
    });

    // With the server running under INTERNAL_API_TOKEN: 401 from the
    // Phoenix pipeline. Without it: fail-closed 503 misconfigured —
    // never a false pass (same discipline as e2e/internal-api.spec.cjs).
    expect([401, 503]).toContain(res.status());
    if (res.status() === 503) {
      const body = await res.json();
      expect(body.error).toBe("internal_api_misconfigured");
    }
  });

  test("malformed JSON body -> JSON-RPC parse error -32700", async ({
    request,
  }) => {
    // Send the broken body as a raw Buffer: a bare string gets JSON-quoted
    // by the Playwright request harness (server then sees a valid JSON
    // string value -> -32600), which would test the harness, not the wire.
    const res = await request.post(BASE, {
      headers: authHeaders({ "Content-Type": "application/json" }),
      data: Buffer.from("{not json", "utf8"),
    });
    expect(res.status()).toBe(200); // JSON-RPC errors ride an HTTP 200 envelope
    const body = await res.json();
    expect(body.error.code).toBe(-32700);
  });

  test("unknown method -> -32601 method not found", async ({ request }) => {
    const res = await request.post(BASE, {
      headers: authHeaders({ "Content-Type": "application/json" }),
      data: rpc(2, "bogus/method", {}),
    });
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.error.code).toBe(-32601);
  });

  test("message/send happy path -> result.task (shared hex-agent dispatch)", async ({
    request,
  }) => {
    const res = await request.post(BASE, {
      headers: authHeaders({ "Content-Type": "application/json" }),
      data: rpc(3, "message/send", { message: BROWSE_MESSAGE }),
    });
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.error).toBeUndefined();
    expect(body.result).toBeTruthy();
    // "as:guest browse grade:3" resolves to a reply -> task completed with
    // an artifact. (If the shared dispatch ever returns a bare message
    // instead, the wire shape changes to result.message — that is a real
    // regression signal, not a spec bug.)
    // W270 alignment to W217 curl ground truth: the v1.0 wire state enum is
    // TASK_STATE_COMPLETED (AshA2A.Protocol.JSON state encoding), not
    // "completed" (the 0.3 spelling this spec previously asserted).
    expect(body.result.task).toBeTruthy();
    expect(body.result.task.id).toBeTruthy();

    // W313 alignment: per a2a v1.0, an async task lifecycle may legitimately
    // return a non-terminal in-band state (TASK_STATE_WORKING/SUBMITTED) with
    // terminal completion delivered via stream or tasks/get polling. Terminal
    // in-band (TASK_STATE_COMPLETED) is also correct for a reply-backed
    // dispatch. Accept both; if non-terminal, poll tasks/get until terminal.
    const TERMINAL = new Set(["TASK_STATE_COMPLETED", "TASK_STATE_FAILED", "TASK_STATE_CANCELED", "TASK_STATE_REJECTED"]);
    /** @type {any} */
    let task = body.result.task;
    let polls = 0;
    while (!TERMINAL.has(task.status?.state) && polls < 10) {
      polls += 1;
      await new Promise((r) => setTimeout(r, 300));
      const poll = await request.post(BASE, {
        headers: authHeaders({ "Content-Type": "application/json" }),
        data: rpc(30 + polls, "tasks/get", { id: task.id }),
      });
      expect(poll.status()).toBe(200);
      const pollBody = await poll.json();
      expect(pollBody.error).toBeUndefined();
      task = pollBody.result;
    }
    expect(TERMINAL.has(task.status?.state)).toBe(true);
    expect(task.status.state).toBe("TASK_STATE_COMPLETED");

    const artifactParts =
      task.artifacts?.[0]?.parts ?? task.artifact?.parts ?? [];
    expect(artifactParts.length).toBeGreaterThan(0);
  });

  test("message/stream SSE: task snapshot + artifact + terminal TASK_STATE_COMPLETED", async ({
    request,
  }) => {
    // W270 alignment to the closed seam: the /a2a/v1 mount now serves through
    // XaasWeb.A2A.V1TransportPlug (AshA2A.Transport.Plug, TQ-05 — it streams
    // EVERY reply, not just streaming agents). The real wire sequence is:
    // opening task snapshot frame, one ArtifactUpdate per artifact, terminal
    // StatusUpdate carrying the task's real state (TASK_STATE_COMPLETED for
    // the reply-backed hex-agent dispatch) — every frame a `data:` line on
    // text/event-stream. (The pre-seam refusal forms this test used to pin —
    // -32004 UNSUPPORTED_OPERATION, then -32603 {:not_streaming, task} — are
    // gone; both were re-pinned empirically during W270 before the W305 seam
    // landed.)
    const res = await request.post(BASE, {
      headers: authHeaders({ "Content-Type": "application/json" }),
      data: rpc(4, "message/stream", { message: BROWSE_MESSAGE }),
      timeout: 10_000,
    });

    expect(res.status()).toBe(200);
    const contentType = res.headers()["content-type"] || "";
    expect(contentType).toContain("text/event-stream");

    const bodyText = await res.text();
    expect(bodyText).toContain("data:");
    expect(bodyText).toContain("TASK_STATE_COMPLETED");

    // The reply content itself must ride the artifact frames.
    expect(bodyText).toContain("grade:3");
  });
});
