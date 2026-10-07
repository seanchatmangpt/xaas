# W725 — Webhook surface deepening (receipt)

- Subject: /Users/sac/xaas @ feat/playwright-surface, HEAD a0723bf6 (canonical checkout, no worktree)
- Lane: W725, v26.10.6 campaign
- Date: 2026-10-07
- Scope: test-only + this receipt. No lib/ changes, no commit (per lane brief).

## O (observations read, not assumed)

- `lib/xaas/platform/changes/deliver_webhook.ex` — real dispatch: `Req.post`,
  header `x-webhook-signature`, value `"sha256=" <> Base.encode16(:crypto.mac(:hmac, :sha256, secret, raw_json_body), case: :lower)`
  over the exact raw JSON bytes sent; 2xx → `:delivered`, non-2xx/transport error →
  `:failed`; both bump `attempt_count` + `last_attempted_at`; hard ceiling 5 attempts
  (`@max_delivery_attempts`, no HTTP call at ceiling).
- `lib/xaas/platform/webhook.ex` — `secret` is AshCloak-encrypted at rest (`Xaas.Vault`),
  loaded with `authorize?: false` at dispatch.
- `lib/xaas/platform/webhook_delivery.ex` — retry is the ash_oban `"*/5 * * * *"` cron
  `:retry_failed_deliveries` (real scheduling, no backoff intervals); `:deliver` is
  SystemActor-gated via `Xaas.Checks.SystemActor` bypass.

## μ (diff)

- NEW `test/xaas/platform/webhook_deepening_test.exs` — 4 tests, Chicago-style:
  real Bandit receiver (`VerifyingPlug`, W674 idiom: `Bandit.start_link(port: 0)`,
  `ThousandIsland.listener_info/1`) + real sandboxed Postgres + real Ash `:deliver`
  actions, `authorize?: false` (same idiom as existing `deliver_webhook_test.exs`).
- No files modified, no mocks. The receiver is a real HTTP collaborator.

## Verification (real output)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW725 \
    mix test test/xaas/platform/webhook_deepening_test.exs
Finished in 1.7 seconds (1.7s async, 0.00s sync)
Result: 4 passed
```

exit=0. Iterate history (all real runs): run2 0/4 (test-agent state bug: `Agent.update`
dropped the `:statuses` queue — KeyError), run3 2/4 (status-queue ordering; jsonb key
re-ordering vs fresh `Jason.encode!`), run4 3/4 (`Ash.reload!` NotFound under sandbox
without shared mode), run5 4/4.

## Contracts asserted (a)–(d)

- (a) Exact header name/value: `x-webhook-signature` = `"sha256=" <> lowercase-hex
  HMAC-SHA256` over the exact raw bytes received; receiver-side recompute matches
  (`Plug.Crypto.secure_compare`). Delivered row `:delivered`, attempt_count 1.
- (b) Mutation checks: one-byte body tamper → verify fails; flipped signature char →
  fails; wrong receiver secret → fails. Signature is non-vacuous.
- (c) Transitions: 200 → `:delivered` (attempt 1), 500 → `:failed` (attempt 2);
  both set `last_attempted_at`; at the 5-attempt ceiling no HTTP call is made
  (receiver request count unchanged).
- (d) Determinism: two real dispatches of the same delivery row → byte-identical
  bodies on the wire, identical signatures; body equals `Jason.encode!` of the
  row's reloaded payload (jsonb key re-ordering disclosed: the contract asserted is
  stability of the signed bytes per delivery row, not stability vs a fresh encode).

## Standing

- Tests: ALIVE on the exact subject (4/4 passed, real Bandit HTTP + real Postgres).
- Test file itself: uncommitted working-tree artifact on feat/playwright-surface.

## Typed gaps (honest)

- GAP(retry-backoff): real per-attempt backoff intervals are NOT designed — retry is
  a fixed 5-minute ash_oban cron; the delivery row carries only `attempt_count` and
  `last_attempted_at` (no `next_attempt_at`). Asserted what exists (cron-triggered
  count/status bookkeeping + 5-attempt ceiling); the cron worker itself was not
  executed in this lane (would need Oban testing mode); the 2xx/non-2xx transition
  contract is asserted directly on `:deliver`.
- GAP(per-attempt-forensics): no `WebhookDeliveryAttempt` child table (platform-console
  keeps an immutable per-attempt trail); delivery rows are mutable summaries.
- GAP(replay): no replay/redeliver endpoint for dead-lettered deliveries.
- GAP(ceiling-drift): `@max_delivery_attempts 5` is duplicated in
  `DeliverWebhook` and `WebhookDelivery` (two literals, drift risk); not consolidated
  in this test-only lane.

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW725 \
  mix test test/xaas/platform/webhook_deepening_test.exs
# (exact command above under "Verification"; delete _build-laneW725 after)
```
