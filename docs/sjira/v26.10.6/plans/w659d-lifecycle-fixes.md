# W659d — Lifecycle Contract Test Fixes (Art 15(5) / W540)

- Subject: /Users/sac/xaas @ feat/playwright-surface, build root `_build-laneW659d` (MIX_ENV=test)
- Scope: 2 lifecycle contract test fixes from W650b terminal-3 findings. NO lib edits.

## Contract ground truth (read, not edited)

`lib/xaas/semantics/vulnerability_lifecycle.ex` (W540):
- Forward-only, one step: `DETECTED→TRIAGED→RESPONDED→RESOLVED`.
- Non-next-edge transition → `{:error, :REFUSED_LIFECYCLE_SKIP}`.
- Legal-order edge without typed evidence → `{:error, :REFUSED_LIFECYCLE_EVIDENCE}`.
  - `triage/2` needs non-empty `:analysis`; `respond/2` needs non-empty `:receipt`;
    `resolve/2` needs `green: true` + non-empty `:run`.
- Structs immutable — a refused transition leaves the ticket unchanged; the
  RESPONDED happy path is reachable only via the legal evidence walk.

## Fix 1 — test/eu_ai_act/counterfactual_test.exs (Art 15(5) skip→respond)

At HEAD the test already asserted `{:error, :REFUSED_LIFECYCLE_SKIP}` for
`respond/2` from `:DETECTED` (the W650b `{expectation on {:ok, :RESPONDED}}`
state was not present at this subject); the finding's required shape is now
fully in place and strengthened:

- Typed refusal asserted (`:REFUSED_LIFECYCLE_SKIP`) + determinism (`e1 == e2`).
- Added the lifecycle-invariant (forward-only walk) assertion: the history's
  state ranks on the `VulnerabilityLifecycle.states()/0` lattice are
  non-decreasing (`walk == Enum.sort(walk)`) and the refused skip appears as
  no completed edge.

## Fix 2 — test/eu_ai_act/title_iii_test.exs `deepen_kind(:vuln_lifecycle)` (15.5.s3)

Previous deepening called `respond(ticket, %{})` from `:DETECTED` — a skip,
not an evidence gap. Rewritten to exercise both sides of the W540 contract:

- Happy path: `new → triage(%{analysis: ...}) → respond(%{receipt: ...})`
  asserts `{:ok, %VulnerabilityLifecycle{state: :TRIAGED}}` then
  `{:ok, %VulnerabilityLifecycle{state: :RESPONDED}}` with the forward
  history tail `[{:advance, :TRIAGED}, {:advance, :RESPONDED}]`.
- Evidence side: `respond/2` from the lawful `:TRIAGED` edge with `%{}`
  → `{:error, :REFUSED_LIFECYCLE_EVIDENCE}`.
- Skip side: `respond/2` from a fresh `:DETECTED` ticket →
  `{:error, :REFUSED_LIFECYCLE_SKIP}`.

### Coordinator seam-gap note (W659e)

The "post-skip legitimate transition" gap resolves on the test side, not lib:
W540 is forward-only with immutable structs — a refused skip does not poison
the ticket; the RESPONDED confirmation requires the legal evidence walk. The
rewritten deepening walks it legally and gets `{:ok, %{state: :RESPONDED}}`.
No lib change; nothing to coordinate.

## Verification (real tails, _build-laneW659d)

- Baseline (pre-edit, same subject): `Result: 26 passed, 391 excluded` (exit 0)
- Post-fix run 1: `Result: 26 passed, 391 excluded`
- Post-fix run 2: `Result: 26 passed, 391 excluded`
- Collateral: `mix test test/xaas/semantics/` → `Result: 241 passed, 1 skipped, 5 excluded`

## Standing

ALIVE on subject feat/playwright-surface (working tree, test-only diff in
`test/eu_ai_act/counterfactual_test.exs`, `test/eu_ai_act/title_iii_test.exs`).
Falsifier closed: both W650b terminal-3 lifecycle findings are green ×2 with
no collateral in the semantics dir.
