# W984in — truth-pass: docs/cro/CRO-LOOP.md

Lane: W984in, checkout /Users/sac/xaas (canonical), branch feat/playwright-surface.
Scope: docs-only truth-pass of `docs/cro/CRO-LOOP.md` (CRO Loop spec tied to the
EU-AI-Act refusal-engine mandate). Sibling-modified file (appears in
`git status` modified list): disk state read first; edits are fix-forward path
correction + one dated verification section; no sibling edits reverted.
No commit, no build root.

## Before (excerpts)

- Line ~211: `Per \`artifacts/evidence-claims-index.md\`, the ship-list
  corrections…` — relative path broken; file is actually at
  `docs/cro/artifacts/evidence-claims-index.md` (confirmed via
  `find . -name evidence-claims-index.md` → single hit under docs/cro).
- No dated verification section existed; counts were not stated in the file.

## After

- Path fixed in place: `Per
  \`docs/cro/artifacts/evidence-claims-index.md\`, the ship-list corrections…`
- Appended `## Verified 2026-10-07 (lane W984in truth-pass)` block (W984gz
  convention: dated blockquote-style section, claims command-verified, no new
  commitments).

## Code-verified claims (commands + observed output)

- `for f in <10 cited artifact paths>; do test -f …` → all 10 EXIST (w322,
  eu-ai-act-nist-coverage-map, w236, w385, w320, w317, w390,
  docs/cro/ARTIFACT-MANIFEST.md, docs/cro/CYCLE-LOG.md,
  docs/sjira/v26.10.7/plans/w620-cro-entry.md). `test -f
  artifacts/evidence-claims-index.md` → MISSING (path corrected).
- `grep -rln "EuAiActAdmission|IncidentReport|OversightGovernance|RefusalLedgerExport|AiroRiskMapping" lib`
  → 11 files incl. `lib/xaas/semantics/eu_ai_act_admission.ex`,
  `incident_report.ex`, `oversight_governance.ex`,
  `lib/xaas/operations/refusal_ledger_export.ex`,
  `lib/xaas/semantics/airo_risk_mapping.ex`,
  `lib/xaas_web/plugs/eu_ai_act_admission_plug.ex`,
  `lib/xaas_web/plugs/synthetic_marking_plug.ex`,
  `lib/mix/tasks/xaas.export_refusal_ledger.ex`.
- `grep -c "def "` → eu_ai_act_admission.ex 12, incident_report.ex 5,
  airo_risk_mapping.ex 6, refusal_ledger_export.ex 9.
- `grep -n "fria\|ai_literacy" lib/xaas/semantics/oversight_governance.ex` →
  `ai_literacy/0` (def at line 154), `fria_schedule/0` (208),
  `fria_oversight_description/0` (226) present.
- GCP/VITO audit: `grep -rn "GCP|VITO" docs/cro/CRO-LOOP.md` → only stage
  design lines (S1 persona, S4 channel/exit gate, purpose paragraph). No
  implemented-GCP claim; no GCP SDK code in tree (no such lib/ hits).
- Counts: `tail` of `w859-typed-gap-register.md` → fresh awk tally on disk:
  **51 rows = 44 REPAIRED / 3 OPEN / 2 TYPED-OPEN / 2 OUT-OF-SCOPE
  (removed-by-operator)** (post-W984ff; as-of 2026-10-07).
  `docs/sjira/v26.10.6/plans/w984cj-coverage-map.md` sixth re-census addendum
  (W984fh, 2026-10-07) → **830 files — 718 COVERED (88.5%) / 93 UNCOVERED /
  19 NON-TESTABLE**; delta table shows uncovered 133 → 93 (−40), zero
  newly-uncovered.
- S3 numbers vs receipts: w317 → "passed: 96" (96+2 skipped = 98, matches
  `--list`); w385 → "CONFORMANT 26/26 (100%) at HEAD 07180bd3", "EXIT=0";
  w236 → 86 tests / 12 files / 0 failures / 62/62 refusal tokens claims
  intact.

## Fixes (fix-forward only)

1. `artifacts/evidence-claims-index.md` → `docs/cro/artifacts/evidence-claims-index.md`.
2. Added dated "Verified 2026-10-07" section with refreshed counts (w859
   44/3/2/2; coverage-map 93 uncovered) and as-of dates.

## Standing

ALIVE for the docs-only truth-pass: every cited artifact exists at its cited
path, every named refusal-engine seam is live code, GCP/VITO references are
documentation-only and correctly framed, counts refreshed to current receipts
with as-of dates. No commit, no build root, no new commitments.
