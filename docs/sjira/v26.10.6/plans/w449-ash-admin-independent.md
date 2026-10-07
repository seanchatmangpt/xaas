# W449 — Independent verification of W394's CapabilityLivenessReceipt :ingest fix

- Repo: /Users/sac/xaas @ feat/playwright-surface (one canonical checkout, no commit made)
- Date: 2026-10-06, lane W449 (independent verifier; W394 lane quiet)

## Diff under test (uncommitted, lib/xaas/operations/capability_liveness_receipt.ex)

W394's change replaces the `authorize?: false` ingest exception with a scoped
Ash bypass:

```elixir
bypass action(:ingest) do
  authorize_if({Xaas.Checks.SystemActor, service: :oban_scheduler})
end
```

Only the `:oban_scheduler` system authority may run `:ingest`; deny floor
still applies to every other actor. `:destroy` remains forbidden to all.
Comment block updated to match (doc-only, same hunk region).

## Falsifier run (real, this lane)

```
PW_PORT=4096 INTERNAL_API_TOKEN=w449-token npx playwright test \
  e2e/ash-admin-destroy.spec.cjs e2e/ash-admin-state-change.spec.cjs
```

Tail:

```
[global-setup] W55_SEED_OK: witness rows seeded

Running 2 tests using 2 workers

  ✓  1 e2e/ash-admin-state-change.spec.cjs:26:1 › ash_admin: create a real CapabilityLivenessReceipt row and see it persist (3.2s)
  ✓  2 e2e/ash-admin-destroy.spec.cjs:55:1 › ash_admin: destroy a real CapabilityLivenessReceipt row and see it genuinely gone (6.3s)

  2 passed (1.1m)
```

## Verdict

**FIX-VERIFIED** — 2/0 green. W394's on-disk fix resolves the deterministic
regression at ash-admin-destroy.spec.cjs:55 and ash-admin-state-change.spec.cjs:26.
Independent receipt filed; lane W449 made no other writes.

## Coordinator addendum (2026-10-06, post-w394)

This receipt's FIX-VERIFIED verdict is superseded: w394's final diagnosis
refutes the policy hypothesis — AshAdmin forms run `authorize?: false`
(`deps/ash_admin/.../form.ex:2823`, `actor_plug/plug.ex:24`), so the
on-disk :ingest bypass was not the cause of the observed 2/0; the run won
the LiveView hydration race (w394: 1/5 raw, 5/5 with settle wait, warm
0/4 across 2 runs — flaky). The real fix is the spec settle-wait (w460,
in flight). Keep this receipt as the independent 2/0 datapoint; do not
cite it as fix evidence.
