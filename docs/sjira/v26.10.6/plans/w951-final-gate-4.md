# W951 — Final Gate 4 (post-commit-gate full run)

- subject: /Users/sac/xaas @ branch `feat/playwright-surface`, working tree (uncommitted);
  lane W951 own build root. Baseline commit context: fab56ae1 (W935 SPEC-16/17).
- date: 2026-10-07 (07:30–08:05 PDT)
- standing: **PARTIAL_ALIVE** — gates 1–2 fully green; gate 3 = 280/284 with 4
  failures, all ×2-classified **sibling-in-flight** (W968/W969/W970b/W969b lanes),
  zero regressions, zero flakes confirmed.

## Gate 1 — eu_ai_act (exclude open_gap)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW951 \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
```

- exit 0. **1352 passed, 1 excluded, 0 failures.**
- vs w946 baseline: W665's bare-atom flip did not move the pass/exclude counts in
  the closed-gap run (1352 passed / 1 excluded). Art.50 tests passed unchanged
  (title_iv_v_test.exs suite green).

## Gate 2 — census with open_gap

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW951 \
  mix test test/eu_ai_act --include eu_ai_act
```

- exit 0. **1352/1353 passed; 1 failure = the deliberate OPEN_GAP census test**:
  `EUAI-ACT 49.3 — OPEN_GAP: Art.49(3) deployer EU-database registration duty …
  no registration seam exists in this repo`
  (test/eu_ai_act/title_iv_v_test.exs:453, via `flunk("OPEN_GAP: …")`).
- Open-gap census = exactly 1 known open gap (Art.49(3) registration seam). The
  census failure is by-design (flunk), not a defect.

## Gate 3 — repair-heavy domains

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW951 \
  mix test test/xaas/governance/ test/xaas/billing/ test/xaas/library/ \
         test/xaas/conference/ test/xaas/operations/
```

- Run A (07:5x): 355/364 passed, 9 failed, 10 excluded — but sibling churn
  invalidated; failure identities not captured (tail truncation).
- Run B (retry): **BLOCKED at compile** — sibling-in-flight syntax error,
  `lib/xaas/operations/capability_liveness_regressions.ex:83 unexpected 'end'`
  (mid-edit, later resolved by owning lane).
- Run C (retry): **BLOCKED at compile** — sibling lane W969b's untracked
  `test/xaas/governance/freeze_window_active_gate_test.exs:181` calls undefined
  `_approved_override!/2` (defines `approved_override!/2`). Persists ≥15 min;
  NOT transient.
- Run D (routed around the sibling-broken file; governance dir run without
  `freeze_window_active_gate_test.exs`, all other files + billing/library/
  conference/operations in full): exit 0.
  **280/284 passed, 7 excluded, 4 failures.**

### Failure classification (×2)

| # | test | classification | evidence |
|---|------|----------------|----------|
| 1 | `no notification record is created by fulfillment -- PubSub broadcast only` (Xaas.Library.CheckoutPolicyDeepeningTest, checkout_policy_deepening_test.exs:230) | **sibling-in-flight** | Reproducible alone (11/13 when run solo) — not a flake. Root cause: sibling lane **W970b** worktree diff to `lib/xaas/library/hold_request.ex` (+22 lines) deliberately mints a real Checkout on `:fulfill` ("closing W796-G3"); the deepening test still asserts the OLD contract ("no new Checkout row"). Owning lane owes the test update. |
| 2 | `return on an exhausted book hands the copy to the oldest hold (re-decrementing inventory)` (same file:172) | **sibling-in-flight** | Same W970b change; same assertion `open_checkouts_for(waiting.id) == []` now violated by design. |
| 3 | `W968c: previous_status is written by :ingest on overwrite and not forgeable by callers` (Xaas.Operations.CapabilityLivenessDeepeningTest:201) | **sibling-in-flight** | `No such input previous_status for :ingest`; sibling lane's migrations (`20261007231000_add_previous_status_to_capability_liveness_receipts.exs`, `lib/xaas/operations/changes/set_previous_status.ex`) landed mid-run; DB sandbox lacked the column/accept at run time. Owned by W968/W969 operations lane. |
| 4 | `approving a real tier downgrade actually drops the subscription's tier and credits the real prorated Ledger amount` (Xaas.Billing.ApprovalTierDowngradeTest:87) | **sibling-in-flight** | `column "reverses_transfer_id" does not exist` (42703); sibling lane modified `lib/xaas/ledger/transfer.ex` (+`reverses_transfer_id` attr, identity) and authored migration `20261007230000_add_reverses_transfer_id_to_ledger_transfers.exs` (untracked, landed after run start). Schema-drift window, not a regression. |
| — | `freeze_window_active_gate_test.exs` compile break | **sibling-in-flight** (W969b, `_approved_override!` typo, untracked file) | Blocked governance dir compile; routed around, not classified as suite failure. Coordinator should bounce to W969b. |

- Flake check: failures 1–2 reproduced deterministically when the file is run
  alone → not flakes. Failures 3–4 are schema/code drift windows, deterministic
  given tree state → not flakes.
- Regression check: no failure traces to a committed head (fab56ae1 surface);
  all four trace to uncommitted sibling worktree edits with migrations/changes
  authored by their own lanes.

## Transport failures

- 2 sibling compile blocks (Run B, Run C) — waited-and-retried; Run C's blocker
  is persistent and was routed around by file exclusion, per blocker-branches-
  the-search-graph.
- Grafana/PromEx upload nxdomain + autofde-not-on-PATH warnings: pre-existing,
  environmental, non-blocking.

## Replay

Same commands above under the pinned asdf toolchain with a fresh
`MIX_BUILD_ROOT` (lane root `_build-laneW951` deleted at integration, per
cleanup law).

## Standing

- Gate 1: ALIVE (1352/1352 closed-gap green).
- Gate 2: ALIVE (census = exactly 1 by-design OPEN_GAP, Art.49(3)).
- Gate 3: PARTIAL_ALIVE — 4 sibling-in-flight failures on uncommitted tree;
  expected to clear when W970b updates checkout_policy_deepening_test.exs,
  W968/W969 applies the previous_status migration, and the ledger lane applies
  the reverses_transfer_id migration. Zero regressions introduced by
  fab56ae1/W925/W902/W928/W945b/W907 repairs observed on this gate.
