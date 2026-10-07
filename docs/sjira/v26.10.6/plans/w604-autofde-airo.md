# W604 — autofde-lab AIRo risk description

Lane: W604 of the AIRo wiring wave. Repo: `/Users/sac/autofde-lab` (ONE canonical
checkout; nothing committed — writes left on disk for coordinator integration).

## Subject

- `ontology/airo_risk_description.ttl` — AIRo (https://w3id.org/airo) risk
  description of autofde-lab's beam-diagnosis automation system, hand-authored
  projection of real repo evidence (no code touched).
- `tests/ontology/test_airo_risk_description.py` — 6 pytest tests: parse,
  AISystem typing, risk/source/control structure, qualitative
  likelihood/severity/impact presence, and every `rdfs:seeAlso`-cited
  `file:` path must exist on disk.

## Mapping (AIRo vocabulary, fetched from DelaramGlp/airo@main airo.ttl)

- `airo:AISystem` → beam-diagnosis automation (non-LLM planner + sregym grader).
- `airo:Risk` ×2, `airo:RiskSource` ×2, `airo:RiskControl` ×3:
  - Risk `SilentUndercount` ← source `Source_EnvironmentBlockedClass`
    (STATUS.md pass 20 `BLOCKED:ENVIRONMENT`: 10/25 sampled problems
    structurally undeployable, 0-file Helm chart_path).
  - Risk `MisclassificationDrift` ← source `Source_GraderClassificationGap`
    (STATUS.md pass 19/20: rollout undo succeeded yet Diagnosis/Mitigation
    `.success=False`; 6.7% measured vs 38.9–78.5% published vs 75% hand-picked).
  - Controls: sregym-comparison evidence
    (`docs/2026-08-09-representative-sample-batch-results.tsv`,
    `tests/sota/test_decision_basis_sregym_chicago.py`), yield accounting
    (`tests/sregym_sota/test_result_summary.py`), planner courts
    (`tests/reasoning/test_planner_federation_chicago.py`,
    `tests/reasoning/test_dflss_planner_solve_chicago.py`).
  - AIRo properties used (all verified in airo.ttl): `hasRisk`,
    `hasRiskControl`, `hasRiskSource`-side via `isRiskSourceFor`,
    `mitigatesRiskConcept`, `hasConsequence`, `hasImpact`,
    `hasImpactOnStakeholder`, `hasSeverity`, `hasLikelihood`, `hasPurpose`,
    `hasModality`. `isDefinedByEvidence`/`modifies` do NOT exist in the
    vocabulary; evidence citations use `rdfs:seeAlso` with `file:` URIs.
- Qualitative literals: likelihood `possible`/`rare`, severity
  `moderate`/`major` — minted as local `airo:Severity`/`airo:Likelihood`
  individuals, labelled self-assessed.

## Commands / exits

- `python3 -m pytest tests/ontology/test_airo_risk_description.py -v`
  → **6 passed in 0.11s** (Python 3.14.3, pytest 9.0.3, rdflib 7.6.0).
- Path-existence check run before authoring: all 8 cited paths OK.
- One parse fix (raw newlines in literals → `"""..."""`), one fix (severity
  on the Impact individual) — both after real test failures.

## Standing

ALIVE on this checkout (tests pass, cited paths witnessed on disk). Not
committed per lane law — coordinator owns integration/commit.
