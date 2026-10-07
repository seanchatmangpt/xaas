# W984v — W849-backlog-2 CI/regen leg witness + row flip

Lane W984v, xaas v26.10.6, 2026-10-07. No commit (coordinator owns integration).
Scope: register row flip only; **no workflow edit was needed** — zero bytes changed
under `.github/workflows/` this lane.

## Verdict: REPAIRED — flip W849-2 OPEN → REPAIRED

W983p's "still OPEN" citation was stale: it quoted **w982l** ("no CI leg, no
regen-check task, no receipt"), but **w982g** (later in the same wave) landed
SPEC-34 end-to-end, including the CI leg.

## Witness (read fresh from disk, this lane)

### 1. Workflow step exists and is correctly wired

`.github/workflows/ci_cd.yaml:107-115`, inside the `ci` job (exact-head test
court, `MIX_ENV=test` at ci_cd.yaml:50-51):

```yaml
      # SPEC-34 (W849-backlog-2): regen-based drift leg for generated surfaces.
      # Re-runs each in-repo generator (--check --json via GgenIgniter.TaskContract,
      # byte-compare for ash_typescript) and fails the job on drift (exit 4).
      # Surfaces whose regen toolchain is external are disclosed-skipped with
      # typed UNSUPPORTED reasons; see lib/xaas/generated/regen_check.ex.
      - name: Generated-surface regen drift check
        run: mix xaas.generated.regen_check
        env:
          MIX_BUILD_ROOT: _build
```

- Command matches w982g's receipt: `mix xaas.generated.regen_check`.
- Env: inherits job-level `MIX_ENV=test` (ci_cd.yaml:50-51); toolchain + locked
  deps come from the `./.github/actions/beam` step (`mix-env: test`,
  ci_cd.yaml:84-88), the repo's pinned asdf CI convention.
- Exit-code handling 0/4 lives in the mix task, per its own doc:
  `lib/mix/tasks/xaas.generated.regen_check.ex:2,12,44,47-48`
  (`Xaas.Generated.RegenCheck.exit_code/1` → `System.halt(code)`; 0 = clean,
  4 = drift) — a nonzero halt fails the GitHub step, so drift reds the lane.

### 2. Task module on disk

`lib/mix/tasks/xaas.generated.regen_check.ex` present, delegating to
`Xaas.Generated.RegenCheck` (`lib/xaas/generated/regen_check.ex`, landed by w982g
per its receipt §"What landed").

### 3. YAML validity

`python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci_cd.yaml'))"`
→ `YAML OK`.

## Landing

- Row flipped in `docs/sjira/v26.10.6/plans/w983p-register-flips.md`
  (per-row verdict table, W849 backlog-2 row): `still OPEN` →
  `FLIPPED → REPAIRED (w984v)`, citing w982g's receipt + ci_cd.yaml:107-115.
- Tally note: w983p's register tally line (12 OPEN / 39 REPAIRED) predates this
  flip and is now stale by one (11 OPEN / 40 REPAIRED after integration);
  left unedited — tally re-grep is the integration pass's job.
- No other jobs touched. No mix run performed (workflow-YAML-only lane, per
  dispatch).

## Standing

- Row W849-2: **REPAIRED** (ALIVE-as-configured: step is committed surface
  `ci_cd.yaml` on branch `feat/playwright-surface`; exact-head CI execution of
  the step itself is owned by the next push/PR run of `CI/CD Elixir`, not
  witnessed in this lane).
- Falsifier for the flip: remove/renaming the step at ci_cd.yaml:112-115 or
  changing the mix task's halt code away from 4-on-drift without a superseding
  receipt reopens the row.
