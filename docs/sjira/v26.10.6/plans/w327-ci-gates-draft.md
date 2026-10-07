# W327 — closure-gates workflow draft (DoD 2 / P2-2)

Subject: /Users/sac/xaas @ feat/playwright-surface (new file only, no existing workflow modified)

## Deliverable

`.github/workflows/closure-gates.yml` — NEW standalone workflow, three jobs on
ubuntu (root-sync leg on ubuntu-24.04, matching the gen-parity lane it mirrors).
Validated with `python3 -c "import yaml; yaml.safe_load(...)"` → `YAML OK`.

## Per-leg mapping

| Job | Plan row | Command | Gate |
|---|---|---|---|
| prod-strict-compile | EA34 (exact-head production compile) | `MIX_ENV=prod mix compile --force --warnings-as-errors` | warnings-as-errors prod leg |
| surface-drift | x8 gap 3 (ash_surface regeneration) | `mix xaas.ash_surface` then `git diff --exit-code priv/ash_surface` | generated-surface drift |
| root-sync-drift | v26.10.6 §3 gate 1 (clean-tree generation parity) | `ggen sync run` at repo root then `git diff --exit-code` + tracked-drift count | stale projection |

## Advisory status

Every leg job carries `continue-on-error: true` and a `[advisory]` name prefix;
the receipt job reports leg results in `$GITHUB_STEP_SUMMARY` only. Wiring this
file cannot break CI. Promotion to blocking is an explicit operator transition:
remove `continue-on-error` per job once green on main, then add the legs to the
`receipt.needs:` list in `ci_cd.yaml` (separate reviewed change; this lane did
not touch `ci_cd.yaml`, which is dirty from another lane).

## Setup notes

- Toolchain: `erlef/setup-beam` with `version-file: .tool-versions` / strict —
  resolves to elixir 1.20.2-otp-28 / erlang 28.5.0.2 as pinned. Same action SHA
  as the existing gen-parity job in `ci_cd.yaml`.
- Caching: `actions/cache@v6` on `deps` + `_build/<env>`, keyed on
  `runner.os + elixir-version + hashFiles('mix.lock')` with prefix
  `closure-gates-<env>-`.
- Root-sync leg rebuilds the exact ggen manufacturer at the same pinned SHA
  (`GGEN_SHA=1e9fcb9...`, nightly-2026-06-22) the ci_cd.yaml gen-parity lane
  uses, so its drift signal is comparable.

## Standing

UNKNOWN until first CI run on an exact subject. Local evidence: YAML parses;
no workflow execution witness.
