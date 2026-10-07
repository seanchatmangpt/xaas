# W677 — gymact AIRo wiring pin (receipt)

Lane: W677, xaas v26.10.6 campaign.
Subject: `/Users/sac/gymact` @ branch `v26926/gymact-land-aloop-execution-kernel`,
HEAD `20b3fd7ecc7563803207a61d8e4bdb521b4771fe` (verified unchanged before and
after the run). No commit made; no branch switch.

## Ledger claim verified

`docs/cro/artifacts/airo-wiring-ledger.md` row w603 (gymact): CONSISTENT,
surface = `src/gymact/ontology/airo_risk_description.ttl` (5,353 B), court =
"rdflib 7.6.0 structure court, real parse", 4 passed.

Per-claim verification:

| claim | observed |
|---|---|
| TTL exists, ~5,353 B | `src/gymact/ontology/airo_risk_description.ttl` present; size asserted bounded 5,000–20,000 B (5,353 within) |
| rdflib 7.6.0 real parse | `.venv/bin/python -m pytest` runs `rdflib.Graph().parse(..., format="turtle")`; rdflib 7.6.0 confirmed importable in repo venv |
| structure (system/deployer/risks) | asserted: AISystem type, isDeployedBy → AIDeployer, 3 Risks, 3 RiskSources, mapping table, per-risk consequence/control/likelihood/severity |
| cited test files exist | `tests/test_production_surfaces.py`, `test_gymnasium_env.py`, `test_two_gym_gate.py`, `test_standing_enforcement.py` all exist; ran: 7 passed, 2 skipped (pre-existing LOCAL_EXTRA skips) |

Verdict: ledger row CONFIRMED CONSISTENT — no drift. The AIRo surface is real,
parses, and its citations are grounded.

## What was added

`/Users/sac/gymact/tests/test_airo_w677_pin.py` — 9 tests, deepening W603:
- size-bounded TTL presence
- exact refusal-atom → risk-concept table (3 RiskSource → Risk via
  `airo:isRiskSourceFor`, exactly one target each, no dangling sources,
  exactly 3 of each class)
- every Risk has Consequence / RiskControl / Likelihood / Severity
- RiskControl descriptions cite test files that must exist on disk
- Likelihood/Severity nodes must self-disclose "structured estimate … not a
  measurement" (no-overclaiming pin)
- deployer edge typed AIDeployer

All assertions are real rdflib graph queries / real filesystem checks. No
mocks, no stubs.

## Commands and exits

```
cd /Users/sac/gymact
.venv/bin/python -m pytest tests/test_airo_w677_pin.py tests/test_airo_risk_description.py -v
→ 13 passed in 1.36s (9 W677 + 4 W603 baseline)
.venv/bin/python -m pytest tests/test_production_surfaces.py tests/test_gymnasium_env.py \
    tests/test_two_gym_gate.py tests/test_standing_enforcement.py
→ 7 passed, 2 skipped in 18.44s
```

The 2 skips are pre-existing, disclosed: `LOCAL_EXTRA:gyms — optional 'gyms'
extra not installed` (`src/gymact/standing.py:136`), not touched by this lane.

Note: running `pytest` from bare `python3` fails on `conftest.py` importing
`gymact` (deps not installed system-wide); the repo's own `.venv` is the
standard env and was used. Full-suite run was not performed (out of lane
scope); unrelated pre-existing working-tree modifications exist on the
checkout (CHANGELOG.md, README.md, docs/reference.md, pyproject.toml,
src/gymact/__init__.py, src/gymact/gyms/ggen.py,
src/gymact/surfaces/fastapi.py) — none authored by this lane.

## Standing

- W677 AIRo pin: ALIVE on subject
  `20b3fd7e` (`v26926/gymact-land-aloop-execution-kernel`) — 9/9 passed,
  real rdflib parse, real file grounding.
- Ledger gymact row: standing upgraded from claimed to witnessed CONSISTENT.
- Falsifier for this pin: any of the 9 tests failing on a future head
  (e.g. a risk removed from the TTL, a cited file deleted, or estimate
  disclosure language removed) marks AIRo wiring drift.
