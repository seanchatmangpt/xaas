# W826 — closure-gates.yml verification (findings-only lane)

Subject: `/Users/sac/xaas/.github/workflows/closure-gates.yml` @ a0723bf6,
branch feat/playwright-surface. Read-only lane; workflow unmodified.
Receipt path convention check: `artifacts/ci/receipt.json` (created by the
`receipt` job itself via `mkdir -p artifacts/ci`, then uploaded with
`if-no-files-found: error`) — self-consistent; no pre-existing tree artifact
collides with it.

## Per-check table

| check | method | result | standing |
|---|---|---|---|
| (a) YAML parses | `python3 yaml.safe_load` | clean parse; 4 jobs (`prod-strict-compile`, `surface-drift`, `root-sync-drift`, `receipt`); step lists coherent | ALIVE |
| (a) step paths exist on tree | `ls` / grep | `.tool-versions`, `mix.exs`, `mix.lock`, `priv/ash_surface/` (7 entries), `ggen.lock`, `.ggen-v2/receipt.json` all present; `mix xaas.ash_surface` task exists at `lib/mix/tasks/xaas.ash_surface.ex` (writes `priv/ash_surface/` — matches drift-check path) | ALIVE |
| (a) external refs | checkout of `seanchatmangpt/ggen@1e9fcb9679a61460fbd641415cb72511c7e50b33`, `_ggen/Cargo.toml`, rustup `nightly-2026-06-22` | not verifiable from this tree; identical pins already used by `ci_cd.yaml` gen-parity (lines 555-601) | UNKNOWN (locally); mirrored from admitted ci_cd |
| (b) receipt-upload artifact path | grep of write vs upload steps | write: `artifacts/ci/receipt.json` (line 218); upload `path:` (line 228) identical; `if-no-files-found: error` | ALIVE |
| (c) action version pins | grep `uses:` | `actions/checkout@v7` ×4, `actions/cache@v6` ×3, `actions/upload-artifact@v4`, `erlef/setup-beam@54075bcc5e249e4758d363f27d099f55d843f124` (full-SHA pin); `GGEN_SHA` pinned. Same major tags as `ci_cd.yaml` uses; no deviating floating tags | ALIVE |
| (d) advisory posture | read + grep | `name: Closure Gates (advisory)`; `continue-on-error: true` on exactly the 3 gate legs (4 occurrences incl. comment); receipt job `if: !cancelled()` aggregates leg results; no branch-protection/`required` claims anywhere in file; header states file never modifies `ci_cd.yaml` — confirmed, `grep closure-gates ci_cd.yaml` = 0 hits | ALIVE |
| (e) superseded claims | grep `ci_cd.yaml` | header claims "standalone mirror of ci_cd.yaml production job" and "mirror of ci_cd.yaml gen-parity": both target jobs exist (ci_cd lines 326/555); root-sync-drift is a step-faithful mirror of gen-parity (same GGEN_SHA, rustup pin, `test -f ggen.lock`/`.ggen-v2/receipt.json`, identical drift check) with dev-cache + assert-identity steps added. `ci_cd.yaml` receipt `needs:` does not list closure-gates legs — matches the documented pre-promotion posture. No stale counts or file lists found | ALIVE |

## Typed notes (no corrections warranted)

- INFO: `root-sync-drift` pins `ubuntu-24.04` while the other legs use
  `ubuntu-latest` — this faithfully mirrors ci_cd gen-parity (also
  ubuntu-24.04), so it is intentional runner parity, not drift.
- INFO: `artifacts/ci/receipt.json` is a new path not shared with ci_cd's
  root-level `publish-receipt.json` / `deploy-receipt.json` — no collision.
- UNKNOWN (external): ggen repo state at the pinned SHA; unverifiable from a
  light lane, low risk given byte-identical pins in the blocking ci_cd.

## Standing

ALIVE. No step references a nonexistent path; nothing corrected. Every
in-file claim cross-checked against `ci_cd.yaml` holds.
