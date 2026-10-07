# W678 — autofde-lab AIRo wiring pin (receipt)

- Lane: W678, xaas v26.10.6 campaign
- Subject: `/Users/sac/autofde-lab` — branch `feat/doctrine-lab`, HEAD `2a3d064e30df4da2bf465a2fbaaefe6e84da0325`
- No commit, no branch switch. Only new files written:
  - `tests/ontology/test_w678_airo_pin.py` (the pin test, 6 tests)
  - this receipt
- Pre-existing dirty state (other lanes, untouched): `docs/jira/v26.9.17/benchmarks/concurrency-stress-findings.md` (M), `vendor/gyms/enterprisebench` + `vendor/gyms/sregym` (m), untracked `ontology/airo_risk_description.ttl`, `tests/ontology/test_airo_risk_description.py` (the w604 court, another lane's work).

## Ledger row verified (airo-wiring-ledger.md line 28, row w604)

| Claim | Verdict | Evidence |
|---|---|---|
| `ontology/airo_risk_description.ttl` exists at 8,071 B | CONFIRMED | `stat`: exactly 8071 B (mtime Oct 6 22:00) |
| real rdflib parse, no mocks | CONFIRMED | rdflib 7.6.0 parse of the real TTL; `(system, rdf:type, airo:AISystem)` present |
| "8/8 cited paths on disk" | **DRIFT (count off by one)** | Graph has **7** distinct `file:` seeAlso citations (9 triples; STATUS.md and batch-results .tsv cited twice each). All 7 exist on disk — substance holds, the literal "8" is wrong. |
| pytest court passes | CONFIRMED | `pytest tests/ontology/test_airo_risk_description.py` → `6 passed in 0.10s`, exit 0. Note: with `-q` the summary line is suppressed in this repo's pytest output (dots only) — first pin run tripped on that; rerun without `-q` shows the summary. |

## Commands / exits (real output)

```
python3 -m pytest tests/ontology/test_w678_airo_pin.py -v --no-header -p no:cacheprovider
  → 6 passed in 0.65s, exit 0
python3 -m pytest tests/ontology/test_airo_risk_description.py --no-header -p no:cacheprovider
  → 6 passed in 0.10s, exit 0
```

The 7 cited paths, all verified on disk: `docs/STATUS.md`, `docs/2026-08-09-lane-c-non-llm-planner-design.md`, `docs/2026-08-09-representative-sample-batch-results.tsv`, `tests/reasoning/test_dflss_planner_solve_chicago.py`, `tests/reasoning/test_planner_federation_chicago.py`, `tests/sota/test_decision_basis_sregym_chicago.py`, `tests/sregym_sota/test_result_summary.py`.

## Drift finding (the one honest correction)

Ledger row w604 says "8/8 cited paths on disk". Actual: **7 distinct** cited paths (8th is a double-count of the two duplicated seeAlso triples). All cited paths exist; risk-control substance intact. Recommend ledger be corrected to "7/7" (or "9 seeAlso triples / 7 distinct, all on disk").

## Standing

- Pin test: ALIVE on the exact subject above (observed execution, exit 0, real rdflib parses + real subprocess pytest, zero mocks).
- Ledger row: PARTIAL_ALIVE — confirmed with one count drift (8→7 distinct citations).
- Pre-existing unrelated failures: none observed (only the two test files above were run; both green). Full repo suite not run (out of lane scope).
- No build root/venv created (system python3 `/opt/homebrew/bin/python3`, rdflib 7.6.0, pytest 9.0.3 already present; `__pycache__` pre-existing from other lanes' runs).
