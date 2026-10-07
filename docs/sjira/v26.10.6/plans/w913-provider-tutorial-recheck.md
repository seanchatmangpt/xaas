# W913 — Provider-Lifecycle Tutorial Recheck (post-W747/W860)

Lane: W913, xaas v26.10.6 campaign, branch `feat/playwright-surface` (HEAD a0723bf6).
Subject: `docs/claude/diataxis/tutorials/receipted-provider-lifecycle.md`
(last verified by W761; rechecked here against the newer W747 and W860 contracts).

## Task

W761 verified this tutorial, but W747 (idempotency/replay deepening of
`Xaas.Actuation.run/4`) and W860 (health-check per-check timeout) landed after
it. Recheck (a) the tutorial's retry/idempotency claims against W747's pinned
contract — in particular the `:executing` non-replayable tuple — and (b) any
health-check citations against W860's 2s timeout; correct in place if stale.

## Method

Read the full tutorial; read W747's and W860's receipts in full; cross-checked
the tutorial's envelope claims against the live module
(`lib/xaas/actuation.ex` — `:succeeded`/`:replayed` envelopes, `replay?`
field, `result_hash` on the receipt, `ontology_projection_hash` on the intent,
lines 55–68, 155, 446–450).

## Per-claim table

| # | Tutorial claim | Newer contract | Verdict |
|---|---|---|---|
| 1 | Step 6: same key + same consequence → `replay.status == :replayed`, `replay.replay? == true`, same receipt identity, no second mutation | W747 (a): same key twice → envelope `:replayed`, `replay?` true, same `receipt.id`/`intent.id`, 1 intent + 1 receipt row per key | CURRENT |
| 2 | Step 6: "No second lifecycle mutation should occur" | W747 (a2): replay carries original consequence state; receipt `result_hash`/`result` equal first run's — durable read, not re-execution | CURRENT |
| 3 | Step 4: `first.status == :succeeded`, `first.replay? == false`, sealed receipt with result snapshot + `result_hash` | W747 (b): fresh key → `:succeeded`, `replay?` false, real receipt; field names confirmed in `lib/xaas/actuation.ex` (lines 55–68, 401–412) | CURRENT |
| 4 | Step 4: ontology projection hash rides on the intent (`intent.ontology_projection_hash`), not the receipt body | `lib/xaas/actuation.ex:155` — `ontology_projection_hash: admission.projection_hash` on intent construction | CURRENT |
| 5 | Tutorial's implied retry semantics (any claims about interrupted/in-flight runs?) | W747 (d4): intent forced to `:executing` → `{:error, {:idempotency_not_replayable, key, :executing}}`; transactional path has no resume semantics | NO CONFLICT — the tutorial makes no claim about interrupted runs, so W747's `:executing` tuple does not contradict it; no correction required |
| 6 | Health-check behavior | W860: per-check 2000ms `Task.await` ceiling, typed `{:timeout, ceiling}` → 503 fail-closed | NOT APPLICABLE — the tutorial cites no health checks or endpoints; nothing to recheck |

## Corrections made

None. Every claim the tutorial actually makes is current against both newer
contracts; the two newer contracts cover behavior the tutorial does not speak
to (`:executing` non-replayable tuple; health-check timeout), so no stale text
exists to correct.

## Standing

VERIFIED — tutorial current against W747 and W860 as of HEAD a0723bf6 on
`feat/playwright-surface`. Read-only recheck; zero tree changes other than
this receipt. No lane build root created (documentation-only lane). Not
committed, per lane contract.
