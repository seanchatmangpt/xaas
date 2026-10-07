# W648b — Art. 4.1 AI-literacy + Art. 27.1.b/e/f FRIA fields (lane receipt)

Lane: W648b (EU-AI-Act wave). Subject: xaas @ feat/playwright-surface, 2026-10-06.
Build root: `_build-laneW648b`. ONE canonical checkout, no worktrees.

## What landed

Three ADD-only functions in `lib/xaas/semantics/oversight_governance.ex`
(mirroring `fria/0`'s structured-data idiom; no existing function altered):

1. **`ai_literacy/0`** (Art. 4.1) — structured measures register over REAL
   fleet enablement evidence:
   - `docs/cro/CRO-LOOP.md` — operator enablement (cadence/stages/exit gates)
   - `test/eu_ai_act/README.md` — the executable-regulation training doc
   - `docs/eu_ai_act/corpus-README.md` — corpus falsifier discipline
   - `docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md` — Art. 14 oversight rows
   Shape: `{:ok, %{measures: [%{name, evidence_path, basis}], audience:
   "operators/oversight personnel", source: [paths]}}`.

2. **`fria_schedule/0`** (Art. 27.1.b) — `{:ok, %{period: "per-wave",
   trigger: "corpus drift falsifier", evidence: [paths]}}`; cadence = the CRO
   loop cycle, re-verification = the corpus drift falsifier.

3. **`fria_oversight_description/0`** (Art. 27.1.e) — `{:ok,
   %{description: [...], controls: [paths]}}`; per-right FRIA structure +
   counterfactual (`lib/xaas/semantics/counterfactual.ex`) /
   attribution (`lib/xaas/semantics/admission_attribution.ex`) /
   automation-bias (`lib/xaas/semantics/automation_bias_countermeasure.ex`)
   surfaces.

Every cited path was `test -f` verified before citation and is re-verified by
the tests at run time.

## Flip table (4 OPEN_GAPs -> EVIDENCED)

| duty  | structured field                    | evidence path(s)                                          | test file |
|-------|-------------------------------------|-----------------------------------------------------------|-----------|
| 4.1   | `ai_literacy/0` `.measures`         | CRO-LOOP.md, test/eu_ai_act/README.md                     | title_i_test.exs (`EUAI-ACT 4.1`) |
| 27.1.b| `fria_schedule/0` `.period/.trigger`| CRO-LOOP.md, corpus-README.md                             | title_iii_test.exs (`EUAI-ACT 27.1.b`) |
| 27.1.e| `fria_oversight_description/0`      | counterfactual/attribution/bias-countermeasure surfaces   | title_iii_test.exs (`EUAI-ACT 27.1.e`) |
| 27.1.f| `fria/0` materialisation entries    | oversight_governance.ex, incident_report.ex, w537 receipt | title_iii_test.exs (`EUAI-ACT 27.1.f`) |

After the flips, Title I and Title III each have **zero** typed open gaps:
this lane flipped 4.1/27.1.b/e/f; sibling lane W649b concurrently flipped 8.1
in the same title_iii file (disjoint edits, both verified intact on disk).

## Files touched (contract lanes only)

- `lib/xaas/semantics/oversight_governance.ex` (ADD only)
- `test/xaas/semantics/oversight_governance_test.exs` (extend: 3 describes, 7 new tests)
- `test/eu_ai_act/title_i_test.exs` (4.1 flip: gap_ids, @gap_details, @evidence, @typed_calls)
- `test/eu_ai_act/title_iii_test.exs` (27.1.b/e/f flips: evidence_map, deepening_map, `deepen_kind(:fria_schedule)`)

## Honesty notes

- 27.1.f is evidenced as **typed inventory, not a closed channel**: the FRIA's
  materialisation entry for the authority channel stays honestly OPEN_GAP
  inside `fria/0`; the W538 `IncidentReport` seam is PREPARED_NOT_TRANSMITTED.
- 4.1 measures are operating documents personnel actually run on, not a
  prose training promise; the audience field says who they serve.

## Verification

Real runs under `_build-laneW648b` (see W648b report; commands in git history
of this receipt's lane): oversight_governance suite, title_i + title_iii both
directions (green gate with `--exclude eu_ai_act_open_gap`, honest census with
gaps included), strict compile.
