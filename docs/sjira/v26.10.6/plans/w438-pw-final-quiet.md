# W438 — PW Final Re-Witness (Fleet Quiet)

## Command

```bash
export INTERNAL_API_TOKEN=w438-token && PATH=$HOME/.asdf/shims:$PATH \
  PW_PORT=4099 INTERNAL_API_TOKEN=w438-token npx playwright test 2>&1 | tail -15
```

## Real tail

```
    Error Context: test-results/ash-admin-state-change-ash-0d437-eipt-row-and-see-it-persist/error-context.md

  2 failed
    e2e/ash-admin-destroy.spec.cjs:55:1 › ash_admin: destroy a real CapabilityLivenessReceipt row and see it genuinely gone
    e2e/ash-admin-state-change.spec.cjs:26:1 › ash_admin: create a real CapabilityLivenessReceipt row and see it persist
  2 skipped
  94 passed (1.8m)
```

Full count: **94 passed / 2 failed / 2 skipped (98 total via `--list`, 1.8m)**.

## Skip identity

`e2e/stripe-webhook.spec.cjs` run in isolation: 2 passed / 2 skipped — the two
skips are exactly the STRIPE_WEBHOOK_SECRET-pair (w381 adjudication), unchanged.
98 listed = 96 + 2 (w317 total), same surface size.

## Comparison vs baselines

- **w317** (authoritative green): 96 pass / 0 fail / 2 skip. Today: 94/2/2.
- **w391** (contention isolation): already classified the two ash-admin specs as
  a REAL deterministic regression, 3/3 runs + w381: "the ash_admin `:ingest`
  form flow completes without UI expect failure, Save submits, but the row never
  persists — the internal-api follow-up returns 200 with `data: []`
  (Expected length: 1, Received length: 0)". No UI form/validation error.
  Both failures share the create-via-admin-UI step for CapabilityLivenessReceipt.
- Today's two failures are byte-identical in identity and signature to w391's:
  same two specs, same `data: []` at `ash-admin-state-change.spec.cjs:83`.
  **Not a new failure — W394's admin-ingest policy fix has NOT landed** (the
  expected 96/0/2 or 98/0/2 did not materialize). OS-17 vault guard and W369
  conversions did not change the pass surface otherwise: every other spec green
  on first run, no flaky, no boot failure, server healthy on 4099.

## Verdict

**PARTIAL — browser rung NOT re-witnessed green at final tree.** The suite is
stable-reproducing at 94/2/2; the 2 failures are the same pre-existing
CapabilityLivenessReceipt admin-UI ingest regression w391 isolated, not new
drift. No new failures vs w317/w391 baselines. Remaining hop: W394's fix must
land (or the ash-admin ingest path be repaired) to restore 96/0/2.
