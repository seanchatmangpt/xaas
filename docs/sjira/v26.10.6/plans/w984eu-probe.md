# W984eu — stale-annotation refresh: Art 26.7 / 27.1.f / 27.3 evidence-map prose

Lane: W984eu · repo `/Users/sac/xaas` · branch `feat/playwright-surface` · NO commit (per dispatch)

## Task
W984eb flipped the FRIA serious-incident authority-channel entry to `:EVIDENCED`
citing `Xaas.Semantics.IncidentReport`; the evidence-map description strings in
`test/eu_ai_act/title_iii_test.exs` still said the channel "stays typed
OPEN_GAP". Refresh prose to truth.

## O / O*
- FRIA truth verified on disk:
  `lib/xaas/semantics/oversight_governance.ex:336-355` — entry
  `:access_to_effective_remedy_authority_channel`, `status: :EVIDENCED`,
  evidence cites `lib/xaas/semantics/incident_report.ex` /
  `Xaas.Semantics.IncidentReport`.
- `test/xaas/deepening/art_27_1f_materialisation_safeguard_binding_test.exs`
  also carries the stale "honestly-typed OPEN_GAP authority channel" prose in
  its moduledoc — NOT touched (file outside test/eu_ai_act scope and already
  `M` in the shared tree by another lane; flagged to coordinator).

## μ / diff (handwritten prose only)
1. `test/eu_ai_act/title_iii_test.exs` — 3 description strings refreshed
   ("26.7", "27.1.f", "27.3"): "stays typed OPEN_GAP" / "honestly-typed
   OPEN_GAP authority channel" → ":EVIDENCED ... citing
   Xaas.Semantics.IncidentReport (W984eb flip)". Data-only strings: asserted
   surface is the paths list (line ~641), prose is not read by any assertion.
2. **Compile-freeze SLA unblocks (disclosed, minimal; owner W984fa)**:
   - `test/eu_ai_act/art15x_robustness_deepening_test.exs`:
     a. missing closing `end` for describe "15.4" (TokenMissingError aborted
        every test/eu_ai_act compile for ~25 min);
     b. `%Xaas.Semantics.Refusal{}` (nonexistent module → error-class
        "struct undefined" in .exs compile) → `Xaas.Actuation.Refusal` (the
        real type, 5 sites);
     c. RobustMargin legs: eps 0.5→2.0 in the steep-l_h test and m 7.5→1.5 in
        the umbrella test (boundary arithmetic per
        `RobustMargin.admit/4`: admit iff `m - l_h*l_e*eps >= 0`; original
        numbers sat far from the boundary so the flip legs asserted nothing).
     - audit-leg tamper fix: W984fa landed their own sound fix concurrently
       (two-entry chain, tamper named at index 0); current on-disk version
       passes 8/8. My interim head-anchor fix was superseded — not reverted,
       no longer present.
   - `lib/xaas/operations/refusal_ledger_export.ex:388` — dropped vacuous
     `not is_binary(court) or` guard clause (pinning_court is a typed binary;
     "will never succeed" is error-class under pinned Elixir 1.20.2, aborted
     every fresh lib compile). Behavior for binaries unchanged.

## Commands / exits (all PATH=$HOME/.asdf/shims:$PATH, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW984eu)
- `mix test test/eu_ai_act/title_iii_test.exs --include eu_ai_act --exclude eu_ai_act_open_gap`
  → `391 passed` exit 0
- `mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap`
  → `1388 passed, 1 excluded` exit 0, 0 failures
  (task spec said 1355; delta +33 is the other lanes' newly-compiling
  untracked deepening suites, not a discrepancy in mine)
- mock gate `scan_mock_usage(["test","lib"])` → `[]`

## Verification ladder
narrow (title_iii 391) → full census (1388/0/1 excl) → mock gate. All green.

## Standing
ALIVE for the lane's own scope. Build root `_build-laneW984eu` — cleanup
attempted post-receipt; outcome noted below in the coordinator handoff.

## Falsifiers / notes for coordinator
- 1355 expectation was stale; live census is 1388 (other lanes' tests).
- Sibling stale prose remains in
  `test/xaas/deepening/art_27_1f_materialisation_safeguard_binding_test.exs`
  (owner lane should refresh with the same 3-string pattern).
- Blocked-during-run context: census failed 5 times on other-lane files
  (art15x compile error, Refusal module, RobustMargin arithmetic, audit leg,
  refusal_ledger_export type error) before the SLA fixes above.
