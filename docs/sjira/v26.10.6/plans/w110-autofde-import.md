# W110 — autofde-lab `DeterministicPlanningDomain` ImportError under pytest/xdist

Lane: W110, v26.10.6 convergence. Subject: `/Users/sac/autofde-lab` (canonical checkout).

## Diagnosis

- `.venv` state: `python -c "import autofde_lab"` → `/Users/sac/autofde-lab/src/autofde_lab/__init__.py` (correct src-layout resolution, not namespace).
- Editable install present: `_autofde_lab_editable.pth` + `_autofde_lab_editable.py` (scikit-build-core editable, dist-info `autofde_lab-26.9.18.dev96+gfe81a5526.d20260919`); note `.venv/bin/pip` and `python -m pip` are absent (uv-managed venv).
- Packaging: `pyproject.toml` `[tool.scikit-build] wheel.packages = ["src/autofde_lab", "src/skdecide"]`; `__init__.py` present.
- Root `conftest.py` is a worktree-only shim (no-ops when `_ORIGINAL_PREFIX == _WORKTREE_PREFIX`, i.e. in the canonical checkout).

## Before / After

- Before (W78 report): 34+ occurrences of `ImportError: cannot import name 'DeterministicPlanningDomain' from 'autofde_lab' (unknown location)` under pytest/xdist — classic "autofde_lab resolved as namespace package" signature.
- After (this run, canonical checkout): **0** occurrences.
- Command: `.venv/bin/python -m pytest tests/domains tests/lab tests/test_utils.py tests/test_schema_migration.py tests/domains/python/test_cloudgoat_iam_privesc_unit.py -q --tb=no --continue-on-collection-errors -n 4` (xdist `-n 4` on the first run of the same subset).
- Outcomes (from progress lines, 323 outcomes): **290 passed, 18 failed, 13 skipped, 2 errors**; exit 1.
- Exact-falsifier count: `grep -ci DeterministicPlanningDomain /tmp/w110_final.log` → **0**.

## Conclusion

The W78 failure class does not reproduce on the canonical checkout: bare import and xdist both resolve `autofde_lab` to `src/autofde_lab/__init__.py` via the existing scikit-build editable install. No conftest or packaging change was needed (none made). W78's 34+ failures are consistent with a run in a worktree copy whose editable finder still pointed at the canonical `src/` (the exact hazard the root `conftest.py` shim guards against) — the shim exists at the canonical root only, and any worktree lacking it would show exactly this failure.

## Remaining failures (out of W110 scope, pre-existing, different classes)

- Missing optional deps: `stable_baselines3`, `plado` (3 collection errors), `z3-solver`, cube extra (`cube-standard`/`counter-cube` under `vendor/gyms/`).
- 18 failed / 2 errors in `tests/domains/python/` — level4 crown/real-trial, typed-induction (cube extra), bridge-provider construction, azuregoat runtime-parse. Not the import class.

## Files changed

None (venv state already correct; no conftest/pyproject edit required).
