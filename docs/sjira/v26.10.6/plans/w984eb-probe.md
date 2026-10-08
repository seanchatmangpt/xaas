# W984eb — typed OPEN_GAP repair receipt

- Subject: xaas @ feat/playwright-surface (no commit; working-tree lane edits only)
- Lane: W984eb (shared canonical checkout, build root `_build-laneW984eb`)

## Gap chosen

`Xaas.Semantics.OversightGovernance.fria/0` right
`:access_to_effective_remedy_authority_channel` — status `:OPEN_GAP`,
basis "no incident surface" (lib/xaas/semantics/oversight_governance.ex,
Art. 26.5 / 3.49 family / Art 73 serious-incident reporting).

## Why implementable in-process

The blocking condition ("no incident-reporting seam exists") is stale:
`Xaas.Semantics.IncidentReport` (lib/xaas/semantics/incident_report.ex)
landed with a real Art 73(1) classification builder over typed refusal
evidence, a typed-honest delivery channel (`transmit/1` →
`:PREPARED_NOT_TRANSMITTED`, never a silent send), and a Chicago court
(test/xaas/semantics/incident_report_test.exs). The FRIA entry predates
it and was never flipped. No operator gate, no external system.

## Edits (3 files)

1. lib/xaas/semantics/oversight_governance.ex
   - FRIA entry flipped `:OPEN_GAP` → `:EVIDENCED`; evidence now cites
     lib/xaas/semantics/incident_report.ex
     (Xaas.Semantics.IncidentReport: Art 73(1) classification derivation
     + transmit/1 typed OPEN) and its Chicago court. Moduledoc Art 26.7
     paragraph updated (builder + FRIA entry EVIDENCED; the authority
     endpoint itself stays typed open).
2. test/xaas/semantics/oversight_governance_test.exs
   - The old "honest limitation ... typed OPEN_GAP" assertion converted
     to a covered Chicago assertion: FRIA entry `:EVIDENCED`, cites the
     real seam, plus real `IncidentReport.build/1` over a refused
     receipt (→ `:MALFUNCTION` classification) and real
     `IncidentReport.transmit/1` → `:PREPARED_NOT_TRANSMITTED`.
3. test/xaas/deepening/art_27_1f_materialisation_safeguard_binding_test.exs
   - Binding liveness assertion updated: instead of requiring an
     `:OPEN_GAP` FRIA entry (article "26.5"), it now requires the entry
     `:EVIDENCED` and citing lib/xaas/semantics/incident_report.ex.

## Real outputs (lane build root _build-laneW984eb)

- Touched files:
  `mix test test/xaas/semantics/oversight_governance_test.exs
   test/xaas/deepening/art_27_1f_materialisation_safeguard_binding_test.exs
   test/xaas/semantics/incident_report_test.exs`
  → Result: 30 passed, 3 excluded (exit 0).
- Full census:
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984eb
   mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap`
  → **Result: 1355 passed, 0 failed, 1 excluded** (exit 0). The 1 excluded
  is the intentional Art. 49(3) OPEN_GAP marker — untouched.
- Mock gate: `scan_mock_usage(["test", "lib"])` → `[]`.

## Baseline notes (pre-existing, not session-introduced)

- Pre-repair census (same command, before my edits): 1354/1355 passed,
  1 failed — `art10_2e_art26_4_dataset_purpose_deepening_test.exs`
  (fixture bias assertion). Transient: that file was mid-edit by lane
  W984ec; run standalone afterwards it passes (3 passed). Final census
  is green.
- The w543/w547 inventories and the tagged-gap modules' inventories are
  stale relative to the tree: only ONE `:eu_ai_act_open_gap` test
  remains suite-wide (49.3), so the repairable gap lived in the typed
  FRIA data, not in a tagged test. Title III evidence-map description
  strings in title_iii_test.exs (26.7 / 27.1.f / 27.3) still say the
  authority channel "stays typed OPEN_GAP"; they are annotation prose
  only (no assertion binds them) and were left untouched to keep the
  diff minimal — flagged here as stale-annotation debt.

## Cleanup

- No commit (per lane contract). Cleanup: `rm -rf _build-laneW984eb
  _build-laneW984eb-list` → REMOVED (both gone; not denied).
