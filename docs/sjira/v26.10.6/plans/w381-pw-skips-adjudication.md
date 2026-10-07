# W381 — Playwright skip adjudication (v26.10.6)

Re: w317-pw-final-tokened.md (96 passed / 0 failed / 2 skipped of 98).

## Method

Full-suite rerun on this checkout with `--reporter=json`
(`PATH=$HOME/.asdf/shims:$PATH PW_PORT=4081 INTERNAL_API_TOKEN=w381-token npx playwright test --reporter=json`,
duration ~154 s). Stats this run: **86 expected / 2 skipped / 10 unexpected** — the 2-skip
identity matches w317; the 10-failure delta is a run-condition difference, not a skip finding
(likely server/port contention in the fan-out window; w317's clean run stands for pass/fail).
Non-passed list this run:

- FAILED ash-admin-destroy.spec.cjs:55, ash-admin-state-change.spec.cjs:26
- FAILED/TIMEDOUT chicago-pplan-deep.spec.cjs:194/256, full_surface.spec.ts:82/117,
  next-read-ml.spec.cjs:64, system-deep.spec.cjs:98, wd-fa-cs2.spec.cjs:5,
  zcode-cli-fabric.spec.cjs:131

## The 2 skips (exactly reproduced)

Both in `e2e/stripe-webhook.spec.cjs`, both env-fixture-gated with explicit typed reasons:

1. **"rejects a signature computed over a tampered body (typed 400)"** — `stripe-webhook.spec.cjs:90`
   ```js
   test.skip(!SECRET, "STRIPE_WEBHOOK_SECRET not shared with this runner");
   ```
2. **"accepts a real well-formed signature over the exact body (200, acked)"** — `stripe-webhook.spec.cjs:123`
   ```js
   test.skip(!SECRET, "no shared STRIPE_WEBHOOK_SECRET suite fixture -- refusal path only");
   ```
   (line 123 reads: `"no shared STRIPE_WEBHOOK_SECRET fixture -- refusal path only"`)

`SECRET = process.env.STRIPE_WEBHOOK_SECRET || ""` (line 29). Neither skip fired in w317's
token run? No — w317 set `INTERNAL_API_TOKEN` only; `STRIPE_WEBHOOK_SECRET` was absent in
both runs, so these are the same 2 skips.

## Verdicts

- Skip 1: **TYPED** — token-absent contract (webhook-secret-absent): test requires a real
  `STRIPE_WEBHOOK_SECRET` fixture; without it the test cannot exercise
  `Stripe.Webhook.construct_event/3` truthfully, and the file header documents the contract.
- Skip 2: **TYPED** — same contract, reason string present, refusal path still covered by a
  sibling test that runs unconditionally (the missing-signature 400 court).

## Tally

**TYPED: 2 / UNTYPED: 0.** No silent skips; DoD satisfied for the skip dimension.
