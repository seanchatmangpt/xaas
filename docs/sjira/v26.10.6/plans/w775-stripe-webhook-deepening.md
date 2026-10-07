# W775 — Stripe webhook deepening (POST /webhooks/stripe)

**Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` HEAD `a0723bf6`, lane W775, no commit (per dispatch).
**Scope of writes**: `test/xaas_web/stripe_webhook_deepening_test.exs` (new, this receipt's only artifact) + this receipt.

## What was read (O)

- `lib/xaas_web/controllers/stripe_webhook_controller.ex` — un-tokened by design; authenticity
  = real `Stripe.Webhook.construct_event(raw_body, signature, secret)` against
  `STRIPE_WEBHOOK_SECRET` (read via `System.get_env/1` at request time); 400
  `%{error: "invalid_signature", detail: ...}` on any with-failure before any Ash action.
- `deps/stripity_stripe/lib/stripe/webhook.ex` (2.17.3) — the actual scheme verified in code:
  `v1 = hex(hmac_sha256(secret, "#{t}.#{payload}"))`, header `t=#{t},v1=#{v1}`;
  `check_timestamp/2` is **one-sided** (rejects iff `t < now - 300`; future t accepted);
  constant-time compare; missing `v1=` scheme -> error.
- `test/test_helper.exs:17` pins the real env secret `whsec_test_only_secret` — tests read the
  secret via `System.get_env/1`, same channel the controller reads, no config divergence.
- Existing `test/xaas_web/controllers/stripe_webhook_controller_test.exs` (happy paths, missing
  header, wrong secret, replay) — deepening file is additive, does not touch it.

## μ (diff)

One new file, 10 tests:

- (a) validly signed payload, secret from the real env channel -> 200 `%{"received" => true}`,
  row `:status == :past_due`, `current_period_end` unix round-trip exact.
- (b1) tampered payload byte after signing -> 400 exact body, row unchanged.
- (b2) flipped last signature char -> 400, row unchanged.
- (b3) signature from wrong secret -> 400, row unchanged.
- (b4) missing `Stripe-Signature` header -> 400 exact body, row unchanged.
- (b5) stale timestamp `now - 301` -> 400 (the scheme does check staleness, one-sided), row unchanged.
- (b6) boundary `t == now - 300` with valid HMAC -> 200 + row state (documents the one-sided check as coded).
- (c) unrecognized event type (`customer.discount.created`), valid signature -> **200 ack**
  (`%{"received" => true}`), no ActuationReceipt row — the real contract is 200-ack, not refusal.
- (d) replay of the same signed payload via a fresh conn -> 200 both times, exactly one
  `ActuationReceipt` for `stripe_event:<event.id>` (idempotency via `Xaas.Actuation.run/4`).
- (e) determinism: same payload+secret+timestamp signed twice -> byte-identical signatures;
  two identical valid posts -> identical 200 bodies.

## Verification (real commands, real tails)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW775 \
  mix test test/xaas_web/stripe_webhook_deepening_test.exs
..........
Finished in 1.3 seconds (0.00s async, 1.3s sync)

Result: 10 passed
```

Exit 0. Full-lane build from empty `_build-laneW775`; two earlier runs failed compile on my own
file (`#{}` interpolation inside `@moduledoc`) — fixed, disclosed; third run green.

## Standing

- New deepening tests: **ALIVE** on subject `a0723bf6` (observed execution, exit 0, 10/10).
- Pre-existing controller test file: untouched, ALIVE from prior waves (not rerun this lane).
- Signature verification: **never relaxed**; no production file modified.

## Typed gaps

- `GRAPHENE-BUILD-NOISE` (non-blocking): PromEx dashboard-upload warnings to Grafana
  (`nxdomain`) during test boot — environment, not code.
- `OBSERVED-LOG-TRACE` (non-blocking): one rescued/logged stack trace through
  `Stripe.Webhook.construct_event/4 -> maps.fold` printed during the (a) run; all assertions
  still passed (Converter noise on the minimal fixture). Not investigated further this lane.
- `CONCURRENT-LANE-RACE` (transient): first compile hit a mid-edit syntax error in
  `lib/xaas/platform/validations/route_secrets_requires_approver.ex` (another lane's uncommitted
  file); valid on re-read, resolved without action.
- Un-tested residue: multi-`v1=` header variant and garbage (non-`t=`/`v1=`) header format are
  covered only indirectly via b2/b4; no dedicated court. Timestamp-far-future acceptance is
  documented by the scheme read, asserted only at the past-side boundary (b6).

## Cleanup

`_build-laneW775` deletion attempt was permission-denied this session — **left in place for the
coordinator** to remove at integration (it is a lease, not an asset; ~full test build).
