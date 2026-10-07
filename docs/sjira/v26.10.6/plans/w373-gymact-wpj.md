# W373 — gymact WP-J (version metadata)

Subject: /Users/sac/gymact @ d3eb5e8 (HEAD). No commits made; no worktrees.

## Finding: NO-OP — version coherence already holds at 26.10.6

The version bump 26.9.28 → 26.10.6 is **already present uncommitted** in the
working tree (pre-existing, not introduced by this lane):

- `pyproject.toml:7` → `version = "26.10.6"` (committed value: `26.9.28`)
- `src/gymact/__init__.py:556` → `__version__ = "26.10.6"` (committed: `26.9.28`)
- `src/gymact/surfaces/fastapi.py` has **no hardcoded version string** — it
  derives via `_app_version()` (`importlib.metadata.version("gymact")`, falling
  back to `gymact.__version__`; line ~37 is `return __version__`). Nothing to
  edit; the surface reports the package version.

## Coherence check (real output)

- `.venv/bin/python -c "import gymact; print(gymact.__version__)"` → `26.10.6`
- `from gymact.surfaces.fastapi import _app_version` → `fastapi app version: 26.10.6`
- `.venv/bin/python -m pytest tests/ -k version -q` → 0 FAILED/ERROR lines
  (output is all SKIPPED lines for optional extras: dspy, docker gyms, tau2, etc.)
- `.venv/bin/python -m pytest tests/test_production_surfaces.py tests/test_surfaces_sota.py -q`
  → `....   [100%]` (4 passed)

## Staging census (WP-J commit coordinator-gated; nothing staged by this lane)

git status --short (7 dirty files — NOT the 3 docs r8 expected):

```
 M CHANGELOG.md
 M README.md
 M docs/reference.md
 M pyproject.toml
 M src/gymact/__init__.py
 M src/gymact/gyms/ggen.py
 M src/gymact/surfaces/fastapi.py
```

Note: dirty set includes pyproject.toml, __init__.py, gyms/ggen.py, fastapi.py —
other lanes' uncommitted work or campaign-era edits; not staged, not touched by
W373 beyond read-only inspection. No tags in repo (`git tag --list` empty);
date-based 26.x.y convention confirmed via CHANGELOG/merge history (v26.9.28 was
the last integration).

## Verdict

Changed: **no** (already consistent at 26.10.6 everywhere; wrong-version edits
would be strictly worse). Coherence: **ALIVE** — package version, `__version__`,
and derived FastAPI app version all report 26.10.6 with a green narrow test slice.
