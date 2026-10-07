# W918b — PubSub court awaiter hardening (per W909 root cause)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` @ `910a2e22` at lane start (working tree; this lane made NO commit). Note: HEAD moved mid-lane — a concurrent committer (coordinator/w935 sweep) folded the hardened test file into `80ca0e0c` ("test(domain): ... deepening suites"), and the `audit_export_token.ex` route fix landed in `fab56ae1` ("feat(governance): SPEC-16/17 audit export token use action (w935)"). Disk state at lane end matches HEAD byte-identically.
- **Standing**: ALIVE (lane-scoped) — hardened awaiter green ×3 real runs; mutation evidence rerun; W909 R3 repro still firing.
- **Files written**:
  - `test/xaas/library/pubsub_publish_court_test.exs` (only test file written; awaiter semantics only)
  - `docs/sjira/v26.10.6/plans/w918b-awaiter-hardening.md` (this receipt)
  - **One-line repair outside lane scope (disclosed)**: `lib/xaas/governance/audit_export_token.ex:121` — `change(increment(:use_count, 1))` → `change(increment(:use_count, amount: 1))`. Pre-existing committed break at HEAD (`be23d26f`): Ash's `Builtins.increment/2` requires keyword opts; integer arg raised `FunctionClauseError` in `Keyword.put_new/3` at module-eval compile time, blocking ALL `mix test` compilation. Pre-existing, not session-introduced; without it no court run was possible. A concurrent lane added the route fix (`patch(:use, route: "/:id/use")` / `patch(:revoke, route: "/:id/revoke")`) to the same file mid-lane; observed and waited out per coordination constraint (wait-and-retry).
- **Environment**: elixir 1.20.2-otp-28 (asdf shims), MIX_ENV=test, `MIX_BUILD_ROOT=_build-laneW918b` (deleted post-run).

## Before / after

**Before (W838/W909)**: `await_relay/2` matched any `%Phoenix.Socket.Broadcast{}` whose topic
starts with the awaited prefix, with requeue-scan. W909 R3 showed the awaiting test process
receives every broadcast TWICE (relay-wrapped + direct — the test process is itself a real
PubSub subscriber), so a stale copy of an already-consumed message satisfies a later await and
starves the fresh broadcast.

**After**: every await is uniquely bound: `await_relay(topic_prefix, expected_id, timeout \\ 2_000)`.
Match = topic prefix AND `payload.data.id == expected_id` (via new `payload_id/1` helper).
Non-matching messages requeued unchanged. All 11 call sites updated to pass the exact
expected payload identity (book.id / checkout.id / curation.id). One-relay-per-topic shape
retained. Moduledoc env note rewritten to the corrected W909 explanation.

## Verification (real output)

| run | cmd | result |
|---|---|---|
| 1 | `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW918b mix test test/xaas/library/pubsub_publish_court_test.exs` | exit 0 — `Result: 9 passed` (seed 812311) |
| 2 | same | exit 0 — `Result: 9 passed` (seed 865813) |
| 3 (post-mutation-restore) | same | exit 0 — `Result: 9 passed` (seed 184771) |

Logs: `/tmp/w918b_run1.log`, `/tmp/w918b_run2.log`, `/tmp/w918b_run3.log` (ephemeral; run tails
quoted above are the durable record).

## Mutation rationale (honest disclosure)

Mutation = revert `maybe_match` to topic-prefix-only (`String.starts_with?` without the
`payload_id(b) == expected_id` conjunct). **Observed: mutation still passes 9/9** under the
suite's current shape (per-topic relays + one broadcast per topic per test). The failure class
needs the W838 interleaving (single relay on two topics + duplicate direct delivery into the
awaiting mailbox). The demonstrating repro is W909 R3, rerun this lane:

```
PATH=$HOME/.asdf/shims:$PATH elixir /tmp/w909/w838shape.exs
# -> await topicB 2: %{n: 2}   (stale n=2 copy satisfies the fourth await; expected n=4;
#    fresh n=4 broadcast left in the mailbox) — matches W909 exactly, still firing 2026-10-07
```

**Which await would flip**: under the W838 single-relay/two-topic shape, the LATER await in a
multi-await test — concretely `ev = await_relay("circulation:events", checkout.id)` in
"return -> circulation:student:<user_id> and circulation:events", which under prefix-only +
duplicates can be satisfied by a stale already-consumed copy instead of the fresh events
broadcast. The hardening removes the entire class: a stale duplicate's `data.id` cannot
equal an await's unique `expected_id` unless it genuinely IS that message, and each id is
awaited at most once per test.

## Residuals

- `/tmp/w909/` and `/tmp/w918b_*.log` are ephemeral.
- `_build-laneW918b` deleted at integration per cleanup law.
- The one-line `audit_export_token.ex` repair is committed-state drift fix-forward by a
  non-owner lane — coordinator should fold it into the governance lane's commit.
- Suite-shape masking means the mutation is non-killing on the current court; the R3 repro
  is the killing evidence for the failure class the hardening closes.
