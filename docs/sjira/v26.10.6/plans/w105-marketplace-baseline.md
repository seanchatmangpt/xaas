# W105 Marketplace Baseline Receipt — v26.10.6

- Lane: Integration W105
- Subject: `/Users/sac/ggen-marketplace` @ `93895f808` (W48-modified tree; dirty worktree: `M CHANGELOG.md`, `M marketplace.active.toml`)
- Date: 2026-10-06
- Scope: baseline own gates on the W48-modified tree. No fixes, no git operations.

## Gate 1: verify_msct_profile.py

Command: `cd /Users/sac/ggen-marketplace && uv run python scripts/verify_msct_profile.py`
Exit: **0**

```
MSCT/MX profile invariants: ALIVE
active_packs=13 front_door=ggen-platform-pack
minimum_novelty=reuse>compose>extend>invent
human_implementation_required=false grants_do_authority=false
```

## Gate 2: verify_enterprise_kudzu_profile.py

Command: `cd /Users/sac/ggen-marketplace && uv run python scripts/verify_enterprise_kudzu_profile.py`
Exit: **0**

```
Enterprise Kudzu profile invariants: PARTIAL_ALIVE
active_packs=13 front_door=ggen-platform-pack
closed_loop_observation=true
dfcm_order=reuse>compose>extend>invent
human_twin=identity_state_only
do_authority=external_existing_boundary
```

## Gate 3: pytest (full suite)

Test surface: `pyproject.toml` `[tool.poe.tasks] test = "pytest tests/"` — 107 test files, 1291 collected test functions; no README dev section prescribing pytest (README has no test/pytest instructions).

Command: `cd /Users/sac/ggen-marketplace && uv run pytest tests/ -q`
Exit: **0**

Verbatim summary line:

```
1956 passed, 58 skipped, 75716 warnings, 146 subtests passed in 1188.36s (0:19:48)
```

Warnings: deprecation noise only (rdflib `Dataset.default_context`/`contexts`/`identifier`, pm4py numpy `np.matrix` PendingDeprecationWarning). No failures.

## Classification

- Failures: **0**
- Skipped: 58 (pre-existing skips, not session-introduced)
- Standing: baseline gates ALIVE on the W48-modified tree; both profile verifiers exit 0 (MSCT ALIVE, Enterprise Kudzu PARTIAL_ALIVE by their own self-report).

## Verification commands (replay)

```bash
cd /Users/sac/ggen-marketplace
git rev-parse HEAD   # expect 93895f808...
uv run python scripts/verify_msct_profile.py
uv run python scripts/verify_enterprise_kudzu_profile.py
uv run pytest tests/ -q
```
