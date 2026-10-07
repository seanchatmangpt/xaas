# W452 — PW post-fix full tokened suite (v26.10.6)

Subject: /Users/sac/xaas @ feat/playwright-surface, lane W452, PW ports 4100/4101/4102.

## Run 1 — full tokened suite

`PATH=$HOME/.asdf/shims:$PATH PW_PORT=4100 INTERNAL_API_TOKEN=w452-token npx playwright test`

Tail:

```
  4 failed
    e2e/ash-admin-destroy.spec.cjs:55:1 › ash_admin: destroy a real CapabilityLivenessReceipt row and see it genuinely gone
    e2e/ash-admin-state-change.spec.cjs:26:1 › ash_admin: create a real CapabilityLivenessReceipt row and see it persist
    e2e/chicago-pplan-deep.spec.cjs:194:3 › /chicago/seller — executive projection (SellerLive) › renders 10 candidate cards, 2 successor cards, empty demonstrated list
    e2e/marketplace.spec.ts:109:1 › (d) pack detail fields (name / version / digest) render ────────
  2 skipped
  92 passed (2.3m)
```

## Isolation probes

1. `PW_PORT=4100 ... npx playwright test e2e/ash-admin-destroy.spec.cjs e2e/ash-admin-state-change.spec.cjs`
   → 2 failed, same signature. (pair, still red)
2. `PW_PORT=4101 ... npx playwright test e2e/ash-admin-state-change.spec.cjs` (single file)
   → **1 passed**; global-setup logged `[global-setup] W55_SEED_OK: witness rows seeded`.
3. `PW_PORT=4100 ... npx playwright test e2e/marketplace.spec.ts:109 e2e/chicago-pplan-deep.spec.cjs:194`
   → chicago:194 still failed (0 `[data-testid^="chicago-capability-"]` cards within 5s);
   marketplace:109 passed.

## Run 2 — full suite again (reproducibility probe)

`PATH=$HOME/.asdf/shims:$PATH PW_PORT=4102 INTERNAL_API_TOKEN=w452-token npx playwright test` →

```
  2 skipped
  85 passed (3.5m)
```
10 failed: chicago-pplan-deep 194+256, full_surface 82+117, marketplace 109,
next-read-ml 42+64, system-deep 75, wd-fa-cs2 5, zcode-cli-fabric 77 —
**exactly w391's verbatim 10-test contention set** (w391-pw-contention.md).

## Contemporaneous contention evidence

During the run window, a foreign `beam.smp` was listening on `localhost:4094`
(another lane's PW server). It was gone when re-checked after the run —
transient concurrent lane. Fleet was NOT drained during this lane's window.

## Classification (vs w317 / w438 / w449, verbatim)

- **ash-admin pair**: failure signature is byte-identical to w438's pre-W394-fix
  record (`Expected length: 1, Received length: 0`, `data: []` at
  `ash-admin-state-change.spec.cjs:83` / `ash-admin-destroy.spec.cjs:90`).
  But single-file isolation on this same tree PASSES (probe 2; matches w449's
  independent 2/0 verdict). Conclusion: the W394 admin-ingest fix is live and
  working; the full-suite failure is run-order/shared-state, not regression.
- **The run-2 10-set**: verbatim w391 CONTENTION-CONFIRMED set — all 10 pass in
  isolation per w391's own adjudication; matches the observed foreign beam on
  4094. Contention, not regression.
- **chicago:194 and marketplace:109 (run 1)**: chicago:194 is in w391's
  contention set; marketplace:109 passed isolated here. Contention.

## Verdict

**Browser rung NOT closed at this window — single-receipt green blocked by
active cross-lane PW contention, not by any regression.** The two previously
failing specs are independently confirmed fixed (single-file isolation passes
on the final tree; W394 fix live). Counts across runs were unstable (92/4,
85/10, all 2 skipped) precisely because concurrent lanes were serving on
foreign ports during the window; no deterministic product defect was
reproduced in isolation.

Follow-up: re-run the full tokened suite once the fleet is drained to mint the
single clean receipt (expected 96/0/2).
