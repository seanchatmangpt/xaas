# W95 — gymact full-suite receipt (v26.10.6 convergence)

- Repo: `/Users/sac/gymact`
- Date: 2026-10-06
- Command: `cd /Users/sac/gymact && ~/gymact/.venv/bin/python -m pytest` (full run, no `-x`, no deselects; pyproject `addopts = "-q -rs --strict-config --strict-markers --import-mode=importlib"`)
- Exit code: **0**

## Final counts (verbatim)

```
2356 passed, 41 skipped, 10 xfailed in 1257.99s (0:20:57)
```

Zero failures, zero errors. The task's literal `pytest -q` form was first run twice (exit 0 both
times) but the extra `-q` collapses to `-qq`, which suppresses the final counts line; the counts
above come from a third full run at the addopts-level `-q`. All three runs exit 0.

## Skip classification (41 total, all named-standing)

All 41 skips are named standing reasons emitted through `src/gymact/standing.py:136`
(`LOCAL_EXTRA` / `LOCAL_GYM` / `LOCAL_CHECKOUT` / `BLOCKED` vocabulary) or the same real-availability
gate pattern in test files — the expected skip class. No skip is an unexplained or vacuous skip.

### Environment/extra availability (via standing.py:136)

| Reason class | Count | Representative reason |
|---|---|---|
| `LOCAL_EXTRA:gyms` | 8 | botocore bundled endpoints.json / gyms extra not installed (`uv sync --extra gyms`) |
| `LOCAL_EXTRA:dspy` | 5 | dspy extra not installed (`uv sync --extra dspy`) (+3 identical test-file dspy import gates, see below) |
| `LOCAL_EXTRA:bpmn` | 2 | bpmn extra not installed (`uv sync --extra bpmn`) |
| `LOCAL_GYM:browsergym-openended` | 2 | browsergym-core 0.14.3 + Playwright Chromium required |
| `LOCAL_GYM:cube-container-counter` / `cube-counter` | 2 | cube/docker extras absent or no reachable Docker daemon (`colima start`) |
| `LOCAL_GYM:kubernetes-goat` | 1 | no kube cluster on context, or vendored checkout not at pinned rev `723a0db4` |
| `LOCAL_GYM:kubernetes-reconciliation` | 1 | no reachable Kubernetes cluster |
| `LOCAL_GYM:swegym` | 1 | no Docker daemon or `datasets` extra missing |
| `LOCAL_GYM:tau2-bench` | 1 | tau2 not installed or `TAU2_DATA_DIR` not set to real data checkout |
| `LOCAL_GYM:terminal-bench` | 1 | terminal-bench not importable or no Docker daemon |
| `LOCAL_GYM:terraform-docker-apply` | 1 | no terraform/tofu on PATH or no Docker daemon |
| `LOCAL_GYM:inspect-evals` | 1 | `inspect_ai` not importable |
| `LOCAL_CHECKOUT:wasm4pm` | 2 | no wasm4pm checkout with cargo at `/Users/sac/wasm4pm` |
| `LOCAL_GYM:sregym` (test file) | 1 | live sregym: no reachable kubernetes cluster (kubectl probe quoted in reason) |
| `LOCAL_GYM:platform-console` (test file) | 2 | `PLATFORM_CONSOLE_BASE_URL/API_KEY` unset; "Skipped, not mocked, per docs/DOD-v26.8.18-FDE-ACTUATION.md §4" |

### Test-file gates (same real-availability pattern)

| Location | Count | Reason |
|---|---|---|
| `tests/test_ocel_emitters_schema_chicago.py:250,284,293` | 3 | `could not import 'dspy'` — same dspy class as `LOCAL_EXTRA:dspy` |
| `tests/test_ocel.py:28` | 1 | `could not import 'counter_cube'` |
| `tests/powl/test_canonical_bridge.py:30` | 1 | published `seanchatmangpt/POWL` wheel is dist-info-only (empty); local `~/POWL` checkout not pip-installed |
| `tests/test_ggen_togaf_gym_pack.py:282` | 1 | pinned ggen toolchain capsule executes on the GitHub Python 3.13 leg (CI-only) |
| `tests/test_ggen_world_cyber_pack.py:138` | 1 | same CI-only ggen capsule gate |
| `tests/test_gym_index_chicago.py:73` | 1 | no real awesome-ai-gyms checkout at pinned SHA (`BLOCKED:VENDOR_CHECKOUT_MISSING`) |
| `tests/test_vendor_benchmarks.py:153` | 1 | AUTOFDE_LAB real collaborator checkout not present |
| `tests/test_protocol_gym_ontology_parity.py:23` | 1 | `BLOCKED:PROTOCOL_CAPABILITIES_NEVER_IMPLEMENTED` (module docstring) |

Count check: 8+5+3+2+2+2+2+1×13 = 41. Environment-class (standing.py:136) = 32; test-file
real-availability gates = 9.

## Classification summary

- **Failures: 0.** Nothing to fix.
- **xfailed: 10** — expected-failure marks, working as intended.
- **Skips: 41**, every one a named standing/real-availability reason (missing optional extras
  gyms/dspy/bpmn, no Docker/kind cluster, missing vendor checkouts at pinned SHAs, CI-only
  capsule legs, one `BLOCKED:PROTOCOL_CAPABILITIES_NEVER_IMPLEMENTED` known-blocked surface).
  This is the expected skip class per lane contract. No test-file bugs; no fixes applied; no git
  operations.

## Replay

```
cd /Users/sac/gymact && ~/gymact/.venv/bin/python -m pytest   # 2356 passed, 41 skipped, 10 xfailed, exit 0
```

Log of the authoritative run: `/tmp/w95_run3.log` (temporary; counts line quoted verbatim above).
