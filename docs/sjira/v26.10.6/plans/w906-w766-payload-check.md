# W906 — W766 Next Read LiveView courts vs. W838 PubSub payload pins

Date: 2026-10-07
Lane: W906 (light verification, findings-only)
Subject: `/Users/sac/xaas` @ branch `feat/playwright-surface` (HEAD a0723bf6; no commit made)

## Task

W766's `test/xaas_web/next_read_live_deepening_test.exs` predates W838's
PubSub payload pins (`action.name == :borrow_copy` on Book topics / `:borrow`
on circulation topics). Check whether W766's file asserts payload facts that
W838's pins contradict.

## Grep evidence

```
$ grep -n "borrow\|:create\|action\.\|payload\|broadcast\|subscribe\|topic" \
    test/xaas_web/next_read_live_deepening_test.exs
8:  the same fixture inputs), and a real `XaasWeb.Endpoint.broadcast/3` driving
9:  the subscribed `handle_info/2` re-render. No mocks.
33:        |> Ash.Changeset.for_create(:create, %{
48:      |> Ash.Changeset.for_create(:create, %{
112:    test "(b) real PubSub inventory broadcast updates rendered availability", %{
129:      # Real inventory change, then a real broadcast on a topic the mounted
130:      # LiveView actually subscribes to ("library:books:events",
137:      XaasWeb.Endpoint.broadcast("library:books:events", "inventory_changed", %{
```

(194 lines total; the `for_create(:create, ...)` hits at lines 33/48 are
fixture book creation, not PubSub payload assertions.)

## Analysis

- Test (b) (lines 112–154) does **not** assert any PubSub payload facts. It
  manually calls `XaasWeb.Endpoint.broadcast/3` on `"library:books:events"`
  with a synthetic `"inventory_changed"` event purely to drive the mounted
  LiveView's `handle_info/2` reload, then asserts on the re-rendered HTML
  availability text. It never subscribes and inspects a message, never asserts
  `action.name`, never asserts an event name that library publishes.
- No assertion of `:borrow_copy`, `:return_copy`, `:borrow`, `:return`, or any
  `action.name` anywhere in the file.
- No contradiction with W838's pins (w838-pubsub-publish-court.md:18–19, 74–75).
  Note W838-G2 documents that `:borrow`/`:return` via Checkout do NOT fire
  `library:books:events` — but W766's broadcast is test-side synthetic, not a
  claim about library's publish behavior, so it is not contradicted by that
  gap either.

## Verdict

**COVERED-COMPATIBLE** — zero contradictions found.

## Standing

PARTIAL_ALIVE (verification receipt; findings-only, coordinator routes any
follow-up). Falsifier for this check: a line in
`next_read_live_deepening_test.exs` asserting a library-published event name
or `action.name` value inconsistent with W838's pins — none exists as of
HEAD a0723bf6.
