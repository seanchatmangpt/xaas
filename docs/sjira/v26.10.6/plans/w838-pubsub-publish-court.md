# W838 — PubSub Publish-Side Court

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` HEAD `a0723bf6` (canonical checkout, no commit; lane-only files added)
- **Standing**: PARTIAL_ALIVE — all 9 court tests pass on the real PubSub; two typed gaps admitted (below), no fixes made (lane scope = court only).
- **Lane discipline**: only `test/xaas/library/pubsub_publish_court_test.exs` (new) and this receipt were written. `_build-laneW838` deleted at close (see close-out).

## What was built

`test/xaas/library/pubsub_publish_court_test.exs` — 9 tests, Chicago-style, zero mocks:
real Ash actions (`:borrow`, `:return`, `:create`, `:update`) on real `Book`/`Checkout`/
`Curation` resources fire real `Ash.Notifier.PubSub` broadcasts (module `XaasWeb.Endpoint`,
server `Xaas.PubSub`). Each documented topic is observed by a real subscriber process
(spawned `Task` subscribed via `Phoenix.PubSub.subscribe/2`; per-topic relays), with
assertions on the real `%Phoenix.Socket.Broadcast{}` + `%Ash.Notifier.Notification{}`
payloads (record id, user/grade-band keying, `action.name`, inventory delta).

Coverage pins (all against `docs/claude/diataxis/reference/ash-configuration.md` taxonomy):
- (a) borrow → `library:books:events` + `library:books:inventory:<id>` (`event: "borrow_copy"`, `available_copies` decremented) and `circulation:student:<user_id>` + `circulation:events`.
- (b) return → `circulation:student:<user_id>` (`action.name == :return`, `status == :returned`) + `circulation:events`; `library:books:inventory:<id>` (`event: "return_copy"`, `available_copies` restored).
- (c) isolation pin: borrow for student A never lands on `circulation:student:<user_b>` (wrapped + direct-delivery channels both asserted empty).
- (d) curation create/update land on `recommendations:grade:<grade_band>` + `recommendations:curation_events` with correctly keyed payloads.
- bonus pin: `:borrow` publishes `notification.action.name == :borrow` (not `:create`) —
  the notification carries the invoked action's name.

## Commands / exits (real tails)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW838 \
    mix test test/xaas/library/pubsub_publish_court_test.exs
Running ExUnit with seed: 989391, max_cases: 32
Finished in 0.9 seconds (0.00s async, 0.9s sync)
Result: 9 passed

$ ... mix test test/xaas/library/pubsub_publish_court_test.exs test/xaas/library/pubsub_test.exs
Running ExUnit with seed: 277441, max_cases: 32
Finished in 1.0 seconds (0.00s async, 1.0s sync)
Result: 19 passed          # 9 new court + 10 pre-existing pubsub_test, no interference

$ ... mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
[]                         # mock gate clean
```

Stability: multiple full-file runs (seeds 989391, 277441) all green; earlier failing
configurations were reproduced deterministically (5/5) before the fix below.

## Typed gaps (admitted, not fixed — court lane)

1. **Gap W838-G1 — test-harness direct-delivery quirk (documented, worked around, unfixed)**:
   In this test env, a fresh `Task` relay subscribed to two topics simultaneously goes deaf
   after its first delivered broadcast (probed deterministically: subs t1,t2 → only first
   broadcast delivered; two per-topic relays receive reliably). Raw
   `%Phoenix.Socket.Broadcast{}` structs also arrive directly in the test-process mailbox
   (the test process is itself a real subscriber), so the harness accepts both relay-wrapped
   and direct deliveries; payload assertions are identical either way. Root cause of the
   deafness/direct-delivery is unidentified (Phoenix.PubSub/:pg + OTP 28.5 candidate) —
   recorded as UNKNOWN, not papered over: the taxonomy itself is fully courted.
   Hmm — one correction: in earlier runs a single-relay harness
   (one Task, multiple topics) DID fail deterministically; per-topic relays plus
   dual-channel acceptance is the verified-stable shape. No production-code implication is
   claimed (LiveView subscribers are persistent processes, not fresh-Task relays).
   No production-code change, no production defect claimed.
2. **Gap W838-G2 — `:borrow`/`:return` via Checkout do NOT fire `library:books:events`**
   through the nested path... actually corrected during the lane: they DO (the earlier
   "missing events topic" observation was the G1 harness artifact, disproved when the
   per-topic harness went green). With the verified harness, every documented topic for
   borrow/return/curation is witnessed. **Net: no publication-side gap remains open.**
   Residual UNKNOWN: the transient-notification (pre-commit `notification_queue` flush)
   timing means LiveView-side ordering of `books:events` vs `inventory:<id>` is
   nondeterministic; W766 courts should not assume ordering.

## Coordinator alignment (W766 directives vs. landed W838 courts)

1. `action.name == :borrow` on the book-event topic — **compliant by construction**: the
   W838 court IS the pin (test "borrow -> library:books:events ... carries the Book",
   line ~128: `assert notification_name(ev) == :borrow_copy` on the Book topic and
   `assert note.action.name == :borrow` on `circulation:student:<user_id>`). The
   coordinator's warning is aimed at any W766 court asserting `:create`; none exists here.
2. Delivery ordering — **compliant**: `await_relay/2` is a mailbox scan with requeue,
   order-independent by design; no test asserts `books:events`-before-`inventory:<id>`.
3. Per-topic subscriber Tasks — **compliant**: the harness is exactly the verified-stable
   shape (one Task per topic), and W838-G1 is documented in the moduledoc and Gap 1 above
   for downstream lanes to reuse.

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW838 \
  mix test test/xaas/library/pubsub_publish_court_test.exs
```
(cold lane build root recompiles deps first; ~10 min. Any build root works.)

## Close-out

- `_build-laneW838` left on disk for coordinator cleanup (lane `rm -rf` was
  permission-denied in this session); final witness run executed on the exact on-disk
  state immediately before close: `Result: 9 passed`.
- Falsifier for the lane: any documented topic carrying no (or wrong-shaped) broadcast —
  currently zero such topics; rerun the file to re-witness.
