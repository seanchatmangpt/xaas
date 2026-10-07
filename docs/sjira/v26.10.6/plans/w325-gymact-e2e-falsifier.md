# W325 — gymact end-to-end falsifier receipt

Date: 2026-10-06. Lane: W325, v26.10.6 convergence. Subjects: /Users/sac/gymact (read-only on sources, tests executed), /Users/sac/xaas (e2e spec only). No commits, no worktrees, no source edits.

## Leg 1 — gymact pytest courts

Command: `cd /Users/sac/gymact && .venv/bin/python -m pytest -q 2>&1 | tail -15`

Result (real, three full runs, all exit 0):

- `pytest -q` run 1: exit 0; tail showed only SKIPPED lines (typed, honest-environment skips — dspy/platform-console/sregym-k8s/autofde-lab-vendor not present; skipped, not mocked).
- Run 3 with full log saved: `/tmp/w325_pytest_full.log` — progress reached `[100%]` with only `.`/`s` characters (zero F/E), then `short test summary info` (all SKIPPED), then exit 0.
- `pytest --collect-only` → `2378 tests collected in 30.27s` (prior receipt's ~2356 pass count; current tree collects 2378).
- Skips are environment-typed (LOCAL_GYM/LOCAL_EXTRA gates in `src/gymact/standing.py:136`), each naming the real missing collaborator — Chicago discipline, no mocks.

## Leg 2 — DCM-018 crown status (W129 finding re-check)

Re-verified from source at current tree:

- `src/gymact/dcm_requirements.py:76`: `witnessed_crown = standings.get(Standing.ALIVE.value, 0) == len(data["requirements"])` — requires ALL 18 rows ALIVE.
- `src/gymact/dcm_requirements.py:64`: raises `DCM_CROWN_CANNOT_BE_PREMARKED_ALIVE` — the crown row is forbidden to be ALIVE in the file.
- Actual schema state (`src/gymact/schemas/dcm-v26.8.7.json`): `Counter({'STRUCTURAL': 17, 'UNKNOWN': 1})` — 17 STRUCTURAL, 1 UNKNOWN, zero ALIVE.

W129's finding HOLDS: `witnessed_crown: true` is unreachable by construction (OS-10, convergence-honest). No runtime receipt→standing feedback path exists.

## Leg 3 — xaas gymact-surface e2e (autofde-lab)

Command: `PATH=$HOME/.asdf/shims:$PATH PW_PORT=4025 INTERNAL_API_TOKEN=w325-token npx playwright test e2e/autofde-lab.spec.cjs 2>&1 | tail -10`

Result (real tail):

```
[global-setup] marketplace catalog written: /Users/sac/.cache/tmp/xaas-e2e-marketplace-catalog.json (13 packs)
[global-setup] W55_SEED_OK: witness rows seeded

Running 2 tests using 1 worker

  ✓  1 e2e/autofde-lab.spec.cjs:30:1 › autofde-lab dashboard renders real benchmark history panel (1.6s)
  ✓  2 e2e/autofde-lab.spec.cjs:55:1 › autofde-lab dashboard renders real webhook deliveries panel (1.2s)

  2 passed (1.3m)
```

Server boot: no collision (booted cleanly on PW_PORT=4025 with w325-token).

## Verdict

**gymact standing end-to-end = ALIVE.**

- Leg 1 green: full pytest courts exit 0 at 100% (2378 collected, zero failures/errors; only typed environment skips).
- Leg 3 green: autofde-lab e2e 2 passed on real booted server (PW_PORT=4025, w325-token).
- Leg 2: W129 finding re-confirmed — `witnessed_crown` unreachable by construction (17 STRUCTURAL / 1 UNKNOWN, `DCM_CROWN_CANNOT_BE_PREMARKED_ALIVE` guard intact at `src/gymact/dcm_requirements.py:64`). This is the known convergence-honest OS-10 finding, not a new blocker; it does not downgrade leg-1/leg-3 standing.

For _FRONTIER gymact row (coordinator applies): gymact ALIVE; DCM-018 remains open per W129's typed requirement list.
