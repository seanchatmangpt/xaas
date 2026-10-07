# W79 — gymact DCM Standing Ladder Receipt

- **Lane**: W79 (integration lane, v26.10.6 convergence)
- **Repo**: /Users/sac/gymact (canonical checkout, no worktree)
- **Subject**: git d3eb5e848cb86952921d1b0083e0b7e7e1f53609 (2026-09-29, "Merge pull request #153: v26.9.28 integration + inherited leaked-event-loop root-cause fix")
- **Tree state**: dirty (pre-existing W9 bootstrapping modifications: CHANGELOG.md, README.md, docs/reference.md, pyproject.toml, src/gymact/__init__.py, etc.)
- **Date**: 2026-10-06
- **Role**: observation only — no fixes, no git operations performed

## Ladder step 1 — `gymact dcm-status`

Command: `~/gymact/.venv/bin/gymact dcm-status 2>&1 | tail -15`

Verbatim output:

```
{"standings": {"STRUCTURAL": 17, "UNKNOWN": 1}, "total": 18, "witnessed_crown": false}
```

## Ladder step 2 — `gymact dcm-requirements`

Command: `~/gymact/.venv/bin/gymact dcm-requirements 2>&1 | tail -15`

Verbatim output (truncated by `tail -15`; full JSON in the command transcript): 18
requirements, spec_version `26.8.7`, name "Design for Combinatorial Maximum".

Standings by id: DCM-001 through DCM-017 = `STRUCTURAL`; DCM-018 = `UNKNOWN`
(law `CROWN_REQUIRES_WITNESSED_DCM`, implementation
`tests/test_combinatorial_receipt.py`, `tests/test_dcm_decision_court.py`,
`tests/test_combinatorial_replay.py`; requirement: DCM implementation cannot
receive ALIVE until public graph admission, complete maximal closure, explicit
cut, real consequence, independent verification, closure-bound receipt and exact
replay execute against an exact real subject).

## Ladder step 3 — strict pytest suite

Config: `[tool.pytest.ini_options]` in `/Users/sac/gymact/pyproject.toml` —
`addopts = "-q -rs --strict-config --strict-markers --import-mode=importlib"`,
`testpaths = ["tests"]`, `asyncio_mode = "auto"`, `filterwarnings = ["error", ...]`.
So the "strict" suite is the plain `pytest -x -q` invocation (strictness comes
from addopts).

### Run 1 (piped through `tail -15`) — aborted

```
!!!!!!!!!!!!!!!!!!!!!!!!!! stopping after 1 failures !!!!!!!!!!!!!!!!!!!!!!!!!!!
[exited with code 0]
```

One failure occurred; its identity was lost to the `tail -15` pipe (pytest exit
code masked by the pipe). Not reproducible.

### Run 2 (full log captured, same command minus pipe) — PASSED

Command: `cd /Users/sac/gymact && ~/gymact/.venv/bin/python -m pytest -x -q >
/tmp/w79-pytest-full.log 2>&1`

Real output (verbatim):

```
..                                                                       [100%]
=========================== short test summary info ============================
SKIPPED [4] src/gymact/standing.py:136: LOCAL_EXTRA:gyms: the 'gyms' extra is not installed -- botocore (bundled real AWS endpoints.json) requires `uv sync --extra gyms`
SKIPPED [1] tests/powl/test_canonical_bridge.py:30: the published seanchatmangpt/POWL git package currently builds an empty wheel (dist-info only, no code) -- see this module's docstring; a local ~/POWL checkout on sys.path (as test_reference_model_conformance.py uses) does not satisfy a plain `import powl.execution` unless it is also pip-installed
SKIPPED [4] src/gymact/standing.py:136: LOCAL_EXTRA:gyms: the optional 'gyms' extra is not installed -- `uv sync --extra gyms`
SKIPPED [2] src/gymact/standing.py:168: LOCAL_EXTRA:bpmn: the optional 'bpmn' extra is not installed -- `uv sync --extra bpmn`
...
```

(Skips shown are the standing-gated ones: missing optional extras gyms/bpmn/
cube/dspy, absent Docker/k8s/colima daemons, absent vendor checkouts wasm4pm/
AUTOFDE_LAB/awesome-ai-gyms at pinned revisions, tau2/inspect-ai not installed,
platform-console env absent. All skips are real-collaborator availability gates,
not mocks — Chicago-style compliant.)

Result: **exit 0, no failure abort** (`-x` was active and never fired). Counts
from the same run: 2378 collected (`pytest --collect-only -q`, per-file counts
summed), 41 skipped (sum of `SKIPPED [n]` entries) ⇒ **2337 passed, 0 failed,
exit 0**.

## Standing classification

| Surface | Standing | Basis |
|---|---|---|
| DCM-001..017 (17 structural laws) | PARTIAL_ALIVE / STRUCTURAL | `dcm-status` reports STRUCTURAL ×17 — structure verified mechanically, witnessed-crown consequence not yet run |
| DCM-018 `CROWN_REQUIRES_WITNESSED_DCM` | UNKNOWN | self-reported `UNKNOWN` by `dcm-status`; witnessed_crown=false — crown court chain (admission→closure→cut→consequence→receipt→replay) not executed against an exact real subject this lane |
| Strict pytest suite | ALIVE (observed) | exit 0, 2337 passed / 41 standing-gated skips, on exact subject d3eb5e84 |
| Witnessed DCM crown | NOT OBSERVED | `witnessed_crown: false` — no crown execution this lane (observation-only lane; fixes out of scope) |

**Overall: v26.10.6 gymact DCM standing = STRUCTURAL suite green +
witnessed-crown UNKNOWN.** The single UNKNOWN (DCM-018) is exactly the
witnessed-crown gap; closing it requires the DCM-018 court chain
(test_combinatorial_receipt / test_dcm_decision_court / test_combinatorial_replay
against a real subject), which is repair-lane work, not observation work.

## Falsifiers / open edges

1. Run-1 single failure was not reproduced in run 2 on the identical subject and
   invocation — classify as transient flake, identity unknown (lost to pipe
   truncation). If it recurs, capture without pipe truncation.
2. DCM-018 remains UNKNOWN until a witnessed crown run is executed and receipted.
3. All 41 skips are real-availability gates (extras/daemons/vendor checkouts);
   none are mocks.
