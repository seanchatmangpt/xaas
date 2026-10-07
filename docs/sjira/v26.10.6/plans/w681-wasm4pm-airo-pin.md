# W681 — wasm4pm AIRo wiring pin test

Lane W681, xaas v26.10.6 AIRo wiring ledger extension.

## Subject

- Repo: /Users/sac/wasm4pm (canonical checkout, no worktree)
- Branch: `fix/v26.9.30-ci-fmt-tsc`
- HEAD at test time: `32deb59f6e40cbf6812f2a9581e545c92b60d1ae`
- Tree state: dirty from other lanes (package.json/README/test edits — not touched by this lane). This lane added exactly one file: `tests/ontology/test_airo_w681_pin.py`.

## Ledger claim under test (airo-wiring-ledger.md, w615 row)

| claim | verification |
|---|---|
| artifact `tests/ontology/airo_risk_description.ttl` (8,511 B) | VERIFIED — file present, `stat().st_size == 8511` |
| rdflib parse + structure court | VERIFIED — real `rdflib.Graph().parse` in pin test; 3 risks / 2 controls / 3 risk sources / typed AISystem asserted |
| 4 passed (`tests/ontology/test_airo_risk_description.py`) | VERIFIED — court file has exactly 4 `test_*` functions; all 4 re-run and pass at W681 HEAD |
| 5 cited `file:` paths grounded | VERIFIED — every `<file:...>` citation resolves on disk (incl. absolute w525d path in xaas) |

sha256(`tests/ontology/airo_risk_description.ttl`) =
`b9316af2782655474ae96097c10157883590d246b6ec822d020cc2ac6f991697`
(shasum -a 256; also printed by
`test_cited_paths_and_sha_stability` at run time).

## New test

`/Users/sac/wasm4pm/tests/ontology/test_airo_w681_pin.py` — 4 tests, real
file reads + real rdflib parse. No mocks, no network. Pins: exact path,
exact byte size, court presence/test-count, graph structure counts,
citation grounding, sha256 stability.

## Run (real output)

```
$ python3 -m pytest tests/ontology/test_airo_w681_pin.py tests/ontology/test_airo_risk_description.py -v
platform darwin -- Python 3.14.3, pytest-9.0.3
collected 8 items
tests/ontology/test_airo_w681_pin.py::test_ledger_artifact_present_at_exact_size PASSED
tests/ontology/test_airo_w681_pin.py::test_pre_existing_court_present_with_four_tests PASSED
tests/ontology/test_airo_w681_pin.py::test_rdflib_parse_counts_match_ledger_surface PASSED
tests/ontology/test_airo_w681_pin.py::test_cited_paths_and_sha_stability PASSED
tests/ontology/test_airo_risk_description.py::test_cited_paths_exist PASSED
tests/ontology/test_airo_risk_description.py::test_ttl_exists_and_prefixes_declared PASSED
tests/ontology/test_airo_risk_description.py::test_rdflib_parse_and_airo_structure PASSED
tests/ontology/test_airo_risk_description.py::test_minimal_turtle_sanity_without_rdflib PASSED
============================== 8 passed in 0.19s ===============================
```

- W681 pin: 4/4 passed.
- Pre-existing W615 court: 4/4 passed (regression confirms the ledger's
  "4 passed" at current HEAD).
- No new build root/venv needed (system python3 + pytest + rdflib).
- Pre-existing unrelated dirty tree from other lanes disclosed above; no
  failures observed in this lane's boundary.

## Standing

ALIVE — ledger row w615/wasm4pm CONSISTENT as claimed; surface pinned by
an executable court at exact HEAD.

## Before/after

- Before: ledger row cited a w615 receipt with no re-verifiable pin at
  current HEAD.
- After: `tests/ontology/test_airo_w681_pin.py` re-verifies the exact
  surface (path, size, parse, structure, citations, sha) at any HEAD;
  drift fails loudly.

Not committed, per lane instructions (coordinator owns commits).
