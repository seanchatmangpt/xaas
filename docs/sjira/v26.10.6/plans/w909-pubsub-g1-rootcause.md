# W909 — W838-G1 Root Cause (findings-only lane)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` (working tree @ investigation time; no commit per lane scope). Findings-only: zero production/test edits, no build root created.
- **Standing**: PARTIAL_ALIVE → closes W838-G1's UNKNOWN: root cause identified and reproduced. **Verdict: harness-shape limitation, not a Phoenix.PubSub defect.** No upstream finding warranted.
- **Environment**: elixir 1.20.2-otp-28 / OTP 28.5.0.2 (asdf pinned), phoenix_pubsub 2.3.0, `Phoenix.PubSub.PG2` adapter (:pg-backed), macOS, standalone `elixir` runs against `/Users/sac/xaas/_build/test/lib/*/ebin` code paths.

## What was run (repro matrix)

All scripts under `/tmp/w909/` (ephemeral, not in repo). Runs used the repo's compiled
test-env deps (`Code.prepend_path` over `_build/test/lib/*/ebin`), `Application.ensure_all_started(:phoenix_pubsub)`,
own `Phoenix.PubSub` server per run.

| # | Shape | Result |
|---|---|---|
| R1 | `repro.exs` — one `Task.start` subscribing t1+t2, raw receive loop; 3 broadcasts (t1,t2,t1); GenServer same shape; two per-topic Tasks | **All delivered** in every shape. GenServer/Task identical. |
| R2 | `variations.exs` — quick-fire 3 broadcasts (t1,t2,t1) before draining; subscribe→broadcast race probe (broadcast immediately after `subscribe` returns, cross-process) | **All delivered**; race probe clean. |
| R3 | `w838shape.exs` — **exact W838 harness code** (`relay/1` unselective relay + `await_relay/3` prefix-scan-with-requeue), one relay Task on two topics, parent **also directly subscribed to one topic** (W838's observed direct-delivery condition) | First three awaits correct; **fourth await returned a STALE DUPLICATE** (`await topicB 2: %{n: 2}`, expected n=4). Fresh broadcast left in the mailbox. |

Repro commands (replayable):

```
PATH=$HOME/.asdf/shims:$PATH elixir /tmp/w909/repro.exs       # R1: all green
PATH=$HOME/.asdf/shims:$PATH elixir /tmp/w909/variations.exs  # R2: all green
PATH=$XAA... # R3 exact command:
PATH=$HOME/.asdf/shims:$PATH elixir /tmp/w909/w838shape.exs   # R3: stale-duplicate reproduced
```

## Root cause (W838-G1)

The awaiting process in the W838 harness was **itself a real subscriber** (W838 already
observed raw `%Phoenix.Socket.Broadcast{}` landing in the test-process mailbox). Every
broadcast therefore arrives **twice** in the awaiting mailbox — once relay-wrapped from the
Task relay, once direct. `await_relay` matches *any* `%Phoenix.Socket.Broadcast{}` on the
topic prefix, so an early await consumes a direct copy that "belongs" to a later await;
the later await then returns the relay-wrapped duplicate of an already-consumed message,
and the genuinely fresh broadcast stays in the mailbox. Downstream, the assertion sees a
stale payload and the fresh message is never matched → the pattern reads as "fresh Task
subscribed to two topics goes deaf after its first broadcast."

**Minimal distinguishing factor**: not subscribe order, not broadcast order, not :pg
partition semantics, not Task-vs-GenServer, not receive-loop shape — but **duplicate
delivery into the awaiting mailbox combined with a non-unique (prefix, any-order) match in
the requeue-scan awaiter**. One relay subscribed to two topics merely concentrates the
interleaving so a stale cross-topic copy satisfies the wrong await deterministically;
per-topic relays separate the streams enough that W838's shape landed green.

## Part (c): upstream semantics check

- Phoenix.PubSub 2.3.0 PG2 adapter is :pg-backed; on a single node delivery is local
  registry dispatch, at-least-once per subscriber, VM-ordered per (sender, receiver) pair.
  Delivery to the broadcasting process is NOT suppressed — a process that both broadcasts
  and subscribes receives its own broadcasts. This is documented behavior, not a defect.
- No changelog/issue found for ":pg subscribers stop receiving on OTP 28"
  (web search; no exact match). No typed upstream finding.

## Verdict

Harness-shape limitation. Two concrete harness defects (both in
`test/xaas/library/pubsub_publish_court_test.exs`'s await semantics, left unedited per
lane scope):

1. `await_relay` accepts direct deliveries — this turns the awaiting process into an
   implicit subscriber and creates the duplicate stream.
2. Match is topic-prefix-only, no uniqueness/dedup key (e.g. payload nonce per await) —
   a stale duplicate satisfies an await, starving the fresh broadcast.

The W838 workaround (one relay per topic) is the verified-stable shape; R1/R2 confirm the
underlying PubSub delivers reliably in every process shape tested (fresh Task, GenServer,
one-process-many-topics, quick-fire, post-subscribe immediate broadcast).

## Falsifier / replay

Rerun R3: `PATH=$HOME/.asdf/shims:$PATH elixir /tmp/w909/w838shape.exs` — reproduces the
stale-duplicate mis-delivery (`await topicB 2: %{n: 2}` instead of n=4). Rerun R1/R2 —
all-delivered confirms no PubSub defect. If R1 ever shows a genuine missed broadcast, the
verdict flips to upstream finding.

## Notes / residuals

- Pre-existing blocker (not this lane's): working tree at investigation time does not
  compile under MIX_ENV=test — `lib/xaas/library/checkout.ex` (W902 batch-3 in-flight edit)
  fails with `misplaced operator ^user_id` at line 91 (`Ash.Query.filter` pin inside a
  generated changeset). All `mix run` verification therefore used standalone `elixir` with
  prepended dep paths; no production file touched.
- `/tmp/w909/` scripts are ephemeral; this receipt is the durable record (lane wrote only
  this file).
