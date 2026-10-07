# W460 — admin e2e specs: settle-wait for the New-form hydration race

Lane W460, v26.10.6 convergence campaign. Repo `/Users/sac/xaas` @ `feat/playwright-surface`.
Contract: write only `e2e/ash-admin-destroy.spec.cjs`, `e2e/ash-admin-state-change.spec.cjs`,
and this receipt. No `lib/` edits (W394 proved the policy correct as-is).

## Status: ALIVE — 6/6 (2 passed × 3 consecutive runs)

## Diff (identical in both specs, after the New click)

```js
await page.waitForURL(/action_type=create/, { timeout: 15000 });
await page.locator("[data-phx-main].phx-connected").waitFor({ state: "attached" });
await page.getByRole("button", { name: /^(Save|Create|Submit)$/i }).last()
  .waitFor({ state: "visible" });
await page.waitForTimeout(500);
```

## Escalation ladder (each step driven by a real failed run)

1. **3s `waitForTimeout` (W394's demonstrated shape): 2/3** — run 1 lost the
   destroy spec's create (`beforeBody` length 0). A blind 3s sleep is under
   the race window under pair-contention.
2. **`[data-phx-main].phx-connected` + Save visible: 1/3** — worse. Root
   cause: the LiveView is *already* `phx-connected` on the table page before
   the New navigation; the probe passed instantly and gated nothing.
3. **`waitForURL(/action_type=create/)` first, then connected + Save +
   500ms: 3/3.** The URL gate is the load-bearing signal: ash_admin's New
   trigger is a `.link navigate` to
   `?...&action_type=create&action=<name>&table=...`
   (`deps/ash_admin/lib/ash_admin/components/page_header.ex:167`), so
   waiting for the URL means the create-form LiveView mount has actually
   begun; the `phx-connected` probe (same shape as
   `e2e/next-read-ml.spec.cjs:19`) then covers socket wiring and the
   Save-visible wait covers form render.

## Verification tails (real, contract command)

```
=== RUN 1 ===  2 passed (21.3s)
=== RUN 2 ===  2 passed (22.6s)
=== RUN 3 ===  2 passed (26.4s)
```

(`PW_PORT=4101 INTERNAL_API_TOKEN=w460-token`, pinned asdf toolchain.)

Additional single-spec runs during diagnosis: destroy alone passed
(`1 passed (26.1s)`); pair failures were pair-order-dependent, consistent
with W391's server-contention picture.

## Lineage

w391 (PW contention) → w394 (refuted the policy hypothesis; admin form runs
`authorize?: false`; real cause is the New-form phx-submit hydration race,
1/5 persisted without wait, 5/5 with settle) → w438 (quiet PW final) →
**w460: this closes the last PW regression.** The full-suite clean receipt
belongs to a post-fix rerun lane, not this one.

## Falsifier status

Closed: the create was silently lost only when Save was clicked before the
create-form navigation + hydration; with the URL-gated settle both specs
pass 3/3 consecutive pair runs. Residual risk (blind-sleep-only variants)
was itself refuted by runs in step 1–2 above — do not regress to a bare
`waitForTimeout` fix.
