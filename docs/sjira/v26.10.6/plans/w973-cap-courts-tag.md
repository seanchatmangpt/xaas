# W973 — Borrow-Cap / Slot-Release Court Tag Decision Receipt

- **Lane**: W973, xaas v26.10.10.6 campaign era (v26.10.6 campaign), canonical
  checkout `/Users/sac/xaas`, branch `feat/playwright-surface`. No commit
  (coordinator owns integration).
- **Subject**: tag-decision audit only — no code touched, no tags added.

## Tag decisions (honest, per-file)

### `test/xaas/conference/enrollment_journey_court_test.exs` — NOT TAGGED

The W925 slot-release court (cancel frees a session slot; re-register
succeeds) genuinely holds as behavior, but "the W893 capacity line" is a
typed-gap-register line (W893's `GAP(CancelDoesNotReleaseSlot)`), not a
corpus `line_id`. The EU AI Act corpus
(`docs/eu_ai_act/corpus.json`, W520 substrate) is the Act's text only:
grep for borrow/checkout/library/conference/capacity-as-domain returns no
domain line; the nearest lines (10.2 data governance, 15.1 accuracy) are
about AI training data and AI-system accuracy, not circulation or
conference capacity. No forced tag.

### `test/xaas/library/checkout_policy_deepening_test.exs` — NOT TAGGED

Same ground: W902's borrow cap (W796-G1) is real, mutation-rationale'd
behavior, but nothing in the corpus binds to a library circulation cap.
Art 10.2 data governance covers training/validation/testing data sets of
high-risk AI systems; a per-student checkout cap is not that. Precedent
(`persona_grant_deepening_test.exs`) shows the honest no-tag answer in
this exact directory: "No @moduletag :eu_ai_act — this is
caller-credential authorization, not Art. 5 bias/protection adjacent."
That file's moduledoc already records the decision ("No mocks. No
@moduletag :eu_ai_act."), so nothing to edit.

## Run results (real, ×2, `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW973`)

Run 1:
```
Finished in 1.0 seconds (0.00s async, 1.0s sync)
Result: 12/14 passed
Failed: 2 tests
```
Run 2 (identical):
```
Result: 12/14 passed
Failed: 2 tests
```

Isolated: `mix test test/xaas/conference/enrollment_journey_court_test.exs`
→ `Result: 1 passed`.

## The 2 failures: pre-existing, cross-lane, deterministic

Both failures are in checkout section (b) — assertions that a fulfilled
hold "mints no new Checkout row" — and are stale against another lane's
uncommitted in-flight change to
`lib/xaas/library/hold_request.ex` (`:fulfill` now mints the real
hand-off Checkout, closing W796-G3, change labeled W970b/W796-G3; the
`?? lib/xaas/hold_request.ex` diff was present in the shared tree this
session). W973 is extend-only on this file; reconciling another lane's
in-flight contract change is the owning lane's (or the coordinator's)
edit. Deterministic across both runs:

```
1) test no notification record is created by fulfillment (line 230) — assert open_checkouts_for(waiting.id) == [] fails; a :borrowed Checkout for the waiting reader now exists
2) tests return on an exhausted book hands the copy to the oldest hold (line 172) — same assert, same new hand-off row
```

Also observed during run-1 window: a transient compile break from yet
another concurrent lane (`?? lib/xaas/governance/checks/freeze_window_active.ex`,
mid-edit) — resolved itself; later runs compiled clean.

## Standing

- **Standing**: PARTIAL_ALIVE — tag decision evidenced against corpus
  greps + README contract this session; runs executed for real, ×2.
- **Falsifier**: a corpus `line_id` whose text binds library-circulation
  or conference-capacity behavior would flip either decision; or the two
  section-(b) failures passing unchanged after W796-G3's owning lane
  updates the stale assertions. Standing flips to ALIVE once the owning
  lane lands and both files run green ×2.
