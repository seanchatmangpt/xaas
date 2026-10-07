// @ts-check
const { test, expect } = require("@playwright/test");
const crypto = require("node:crypto");

/**
 * Stripe webhook receiver courts (wave-2 lane W12, X1 gap).
 *
 * Wire shapes are read from source, not string-scraped:
 *   - XaasWeb.StripeWebhookController (lib/xaas_web/controllers/
 *     stripe_webhook_controller.ex): POST /webhooks/stripe. Authenticity is
 *     real HMAC-SHA256 verification of the raw body against the server-env
 *     STRIPE_WEBHOOK_SECRET via Stripe.Webhook.construct_event/3. Any
 *     missing/invalid Stripe-Signature header (or unset server secret) is
 *     real-rejected with 400 {"error":"invalid_signature","detail":"missing
 *     or invalid Stripe-Signature"} BEFORE any Ash action runs -- fail-closed.
 *   - lib/xaas_web/plugs/stripe_raw_body_reader.ex supplies conn.assigns
 *     :raw_body so the signature is computed over the exact bytes sent.
 *
 * Signature path: no test-fixture signing secret exists in e2e config
 * (test/test_helper.exs sets one only for the ExUnit suite, which is a
 * different process from this dev server). Per the lane brief the
 * well-formed-signature court runs ONLY when STRIPE_WEBHOOK_SECRET is set
 * in BOTH this runner's env and the server's (the runner computes a real
 * HMAC over the real body with node:crypto -- verification is never
 * bypassed). Otherwise only the typed-refusal courts run.
 */

const BASE = "/webhooks/stripe";
const SECRET = process.env.STRIPE_WEBHOOK_SECRET || "";

/** Real Stripe signature header: t=<unix ts>,v1=<hex hmac-sha256(secret, "#{ts}.#{payload}")>. */
/** @param {string} payload @param {string} secret @param {number} [timestamp] */
function stripeSignatureHeader(payload, secret, timestamp = Math.floor(Date.now() / 1000)) {
  const mac = crypto
    .createHmac("sha256", secret)
    .update(`${timestamp}.${payload}`)
    .digest("hex");
  return `t=${timestamp},v1=${mac}`;
}

test.describe("POST /webhooks/stripe", () => {
  test("rejects a request with NO Stripe-Signature header (fail-closed, typed 400)", async ({
    request,
  }) => {
    const res = await request.post(BASE, {
      headers: { "content-type": "application/json" },
      data: JSON.stringify({
        id: "evt_e2e_unsigned",
        type: "customer.subscription.updated",
        data: { object: { id: "sub_e2e" } },
      }),
    });

    expect(res.status()).toBe(400);
    const body = await res.json();
    expect(body).toEqual({
      error: "invalid_signature",
      detail: "missing or invalid Stripe-Signature",
    });
  });

  test("rejects a garbage Stripe-Signature header (typed 400, before any Ash action)", async ({
    request,
  }) => {
    const res = await request.post(BASE, {
      headers: {
        "content-type": "application/json",
        "stripe-signature": "t=1234567890,v1=deadbeef",
      },
      data: JSON.stringify({
        id: "evt_e2e_forged",
        type: "invoice.payment_failed",
        data: { object: { subscription: "sub_e2e" } },
      }),
    });

    // Same typed 400 whether the server secret is unset or simply wrong --
    // the with-chain collapses every failure into one refused shape.
    expect(res.status()).toBe(400);
    const body = await res.json();
    expect(body).toEqual({
      error: "invalid_signature",
      detail: "missing or invalid Stripe-Signature",
    });
  });

  test("rejects a signature computed over a tampered body (typed 400)", async ({
    request,
  }) => {
    test.skip(!SECRET, "STRIPE_WEBHOOK_SECRET not shared with this runner");

    const bodyBytes = JSON.stringify({
      id: "evt_e2e_tampered",
      type: "customer.subscription.updated",
      data: { object: { id: "sub_e2e", status: "active" } },
    });

    // Sign the honest payload, then send a different one: HMAC must not match.
    const signature = stripeSignatureHeader(
      JSON.stringify({ ...{ id: "evt_e2e_tampered" }, tampered: false }),
      SECRET
    );

    const res = await request.post(BASE, {
      headers: {
        "content-type": "application/json",
        "stripe-signature": signature,
      },
      data: bodyBytes,
    });

    expect(res.status()).toBe(400);
    const body = await res.json();
    expect(body).toEqual({
      error: "invalid_signature",
      detail: "missing or invalid Stripe-Signature",
    });
  });

  test("accepts a real well-formed signature over the exact body (200, acked)", async ({
    request,
  }) => {
    test.skip(!SECRET, "no shared STRIPE_WEBHOOK_SECRET fixture -- refusal path only");

    const event = {
      id: `evt_e2e_signed_${Date.now()}`,
      // A type outside @handled_events: the court stays on the auth surface
      // (real 200 {"received":true} ack) without mutating Billing state.
      type: "charge.succeeded",
      data: { object: { id: "ch_e2e" } },
    };
    const payload = JSON.stringify(event);

    const res = await request.post(BASE, {
      headers: {
        "content-type": "application/json",
        "stripe-signature": stripeSignatureHeader(payload, SECRET),
      },
      data: payload,
    });

    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body).toEqual({ received: true });
  });
});
