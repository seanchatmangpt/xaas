# W603 — gymact AIRo risk description

Subject: /Users/sac/gymact @ HEAD (canonical checkout, no commit — coordinator owns git).
Vocabulary: AIRO 1.0, fetched 2026-10-06 from
`https://raw.githubusercontent.com/DelaramGlp/airo/main/airo.ttl` (974 lines;
prefix `airo:` → `https://w3id.org/airo#`).

## Files written

- `/Users/sac/gymact/src/gymact/ontology/airo_risk_description.ttl`
- `/Users/sac/gymact/tests/test_airo_risk_description.py`
- this receipt

## Mapping

- `gymact-system` = `airo:AISystem`; `airo:isDeployedBy` → operator (`airo:AIDeployer`).
- RiskSources (`airo:RiskSource`, `airo:isRiskSourceFor` → Risk), each grounded:
  - environment nondeterminism — `tests/test_gymnasium_env.py` (real reward
    emission asserted across step/reset).
  - reward hacking — `tests/test_gymnasium_env.py`, `tests/test_two_gym_gate.py`
    (reward emission/gating exercised — the tested hazard).
  - evaluator gaming — `tests/test_standing_enforcement.py`
    ("standing is a hard failure, not a quiet skip").
- Risks each carry `airo:hasConsequence` → `airo:Consequence` → `airo:hasImpact`
  → `airo:Impact`; `airo:hasLikelihood`/`airo:hasSeverity` → qualitative
  `airo:Likelihood`/`airo:Severity` individuals labeled "medium/high
  (qualitative, structured estimate — not a measurement)" — disclosed as
  structured estimates, not numeric guesses.
- RiskControls (`airo:RiskControl`) attached via `airo:hasRiskControl`:
  - `tests/test_production_surfaces.py` (production-surface test gate)
  - `tests/test_standing_enforcement.py` (standing skip discipline)

## Verification (real output)

`cd /Users/sac/gymact && uv run pytest tests/test_airo_risk_description.py -v`

```
collected 4 items
tests/test_airo_risk_description.py ....  [100%]
4 passed in 0.79s
```

- rdflib 7.6.0 present — parse/structure test executed for real (not skipped):
  AISystem/isDeployedBy/AIDeployer, ≥3 Risks each with
  Consequence→Impact + Likelihood + Severity, every RiskSource typed and
  `isRiskSourceFor`-linked, both RiskControls attached to risks.
- All 4 cited test files verified on disk before anything else (test #1).
- Property orientation checked against the fetched vocabulary
  (`isRiskSourceFor`: domain RiskSource, range Risk; deployment via
  `isDeployedBy`; controls via `hasRiskControl`).

Standing: ALIVE (observed execution on exact subject files; pytest exit 0).
Falsifier status: holds — deleting any cited test file or breaking TTL syntax
fails the suite.
