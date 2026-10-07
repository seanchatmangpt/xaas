# W394 — ash_admin :ingest regression — DIAGNOSIS: W391 POLICY HYPOTHESIS REFUTED

Lane W394, v26.10.6 convergence campaign. Repo `/Users/sac/xaas` @ `feat/playwright-surface`.
Contract: write only `lib/xaas/operations/capability_liveness_receipt.ex` + this receipt.
Both e2e specs left UNTOUCHED, as required.

## Status: BLOCKED(spec-untouchable) — no lib fix is lawful or effective

## 1. Diagnosis (three independent refutations of the policy-flip hypothesis)

The suspected module's `:ingest` policy (`bypass action(:ingest)` admitting only
`Xaas.Checks.SystemActor, service: :oban_scheduler`) is NOT reached by the admin
UI create path:

1. **Admin form runs `authorize?: false`.** AshAdmin 1.3.2
   (`deps/ash_admin/lib/ash_admin/components/resource/form.ex:2823` and
   `:596`) passes `authorize?: socket.assigns[:authorizing]`; the
   `AshAdmin.ActorPlug.Plug` sets `authorizing: session_bool(session["actor_authorizing"], false)`
   (`deps/ash_admin/lib/ash_admin/actor_plug/plug.ex:24`). With no actor
   panel interaction the admin create runs with authorization off, so the
   row-6 `:ingest` bypass is never consulted. Empirical proof: the admin UI
   create **succeeds intermittently (5/5 with a settle wait) with a nil
   actor** — impossible if the SystemActor-only bypass were being enforced.
2. **No "Pause" toggle exists in ash_admin 1.3.2.** `grep -r "Pause"
   deps/ash_admin/lib` = zero hits; both specs' `getByText(/Pause/i)` click
   is a count-guarded no-op (probe: `PAUSE_COUNT 0`).
3. **Direct Ash create succeeds** against the same dev DB while the UI flow
   fails: `Ash.create` `:ingest` with `authorize?: false` from `mix run`
   persisted a row at 01:02:23 — including after the 01:00
   `CheckRegressions` cron — while browser-flow creates were failing.

## 2. Real cause: client-side LiveView hydration race (environmental)

The ash_admin "New" form navigation takes ~1–4 s to fully wire the form's
`phx-submit` handling; the specs click Save ~1 s after clicking New. Click
lands before the patch/hydration completes → submit silently lost (form
re-renders with values retained, no error, no row).

Measured (real server, current tree, dev DB):

| variant | result |
|---|---|
| spec-exact flow (no wait) | 1/5 persisted (LOOP_0..4 = 0,0,0,1,0) |
| + 3 s settle wait after New click | **5/5 persisted** |
| both real specs, warm server | 0/4 green (2 runs x 2 specs) |
| state-change spec, real run (race won) | 1 green (earlier run) |

This also explains the timeline: w317's 96/0 predates the DOM/app weight
growth (sidebar domains, extensions on this resource: AshOban + AshJsonApi +
AshGraphql increase `AshPhoenix.Form.Auto` mount cost) that widened the race
window. Not a policy change; `4562ce47` (2026-09-15) predates and is
unrelated (authorize?: false path).

## 3. Fix delivered

None in `lib/` — the policy is correct as-is; adding an admin-actor bypass
would be (a) ineffective (policy never consulted on this path) and (b) an
unadmitted widening of `:ingest` authority. The minimal correct fix is one
line in each spec (outside this lane's contract), e.g. after the New click:

```js
await page.waitForTimeout(3000); // or wait for LiveView form hydration
```

Demonstrated 5/5 with that single addition (probe replicating the spec's
exact steps). Alternatively upgrade/tune ash_admin or use
`expect(...).toBeVisible()` on a hydration signal. Reassign to a lane with
e2e-spec write authority, or amend the W394 contract.

## 4. Verification evidence (tails)

- `npx playwright test e2e/ash-admin-state-change.spec.cjs` (real run, race won):
  `1 passed (3.4m)`
- `npx playwright test e2e/ash-admin-destroy.spec.cjs e2e/ash-admin-state-change.spec.cjs`
  (two runs, warm server): `2 failed` each — destroy at line 90
  (`beforeBody.data` length 0), state-change same signature.
- Settle-probe (spec-exact steps + 3 s wait): `SETTLE_0..4 = 1,1,1,1,1`,
  `1 passed (53.7s)`.
- Direct create: `DIRECT_CREATE` ok, row persisted 2026-10-07T01:02:23Z.

## 5. Timeline finding

- `4562ce47` (2026-09-15): `:ingest` narrowed to SystemActor
  `:oban_scheduler` (uncommitted in tree since Oct 6 11:35) — **not** the
  regression cause (admin path is authorize?: false).
- w317's 96/0: pre-dates the ash_admin form-navigation slowdown; the
  failure mode is the hydration race documented above, not authorization.
