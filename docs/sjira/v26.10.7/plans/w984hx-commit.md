# W984hx — Lane Commit Receipt: W984fx library-circulation AIRo trio landing

- date: 2026-10-07
- lane: W984hx
- repo: /Users/sac/xaas, branch `feat/playwright-surface`
- work order: land W984hm-excluded W984fx trio (library-circulation AIRo wiring)
- upstream probe receipt: `docs/sjira/v26.10.6/plans/w984fx-probe.md` (committed in this lane's commit)

## Pre-landing verification (on disk + git log)

- `git diff` on `lib/xaas/semantics/airo_risk_mapping.ex`: exactly one additive
  `risk_controls/0` entry — `Xaas.Library.Changes.EnforceBorrowCap`
  (`lib/xaas/library/changes/enforce_borrow_cap.ex`), detects/mitigates
  `UNRECEIPTED_OVER_CAP_LENDING`.
- `git diff` on `test/xaas/semantics/airo_risk_mapping_depth_test.exs`: test 7
  only (tag `w984fx`).
- `git diff` on `docs/cro/artifacts/airo-wiring-ledger.md`: W984fx extension
  section only.
- `git log -- lib/xaas/semantics/airo_risk_mapping.ex`: last commits
  3c03bffa / 297da2f1 — W984fy/gu/hc adapter commits did not carry the mapping
  change; entry was uncommitted in the working tree.
- Receipt file `docs/sjira/v26.10.6/plans/w984fx-probe.md` present on disk.

## Gates (PATH=$HOME/.asdf/shims:$PATH, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW984hx)

| gate | result |
|---|---|
| `mix test test/xaas/semantics/airo_risk_mapping_depth_test.exs` | 7 passed, exit 0 |
| `mix xaas.airo.compile_shacl` | exit 0 — 46 classes / 46 shapes / 130 triples, vocab sha `6274d2d8…` |
| sibling airo courts (airo_shacl_court, airo_vendored_pin, airo_risk_mapping, airo_ledger_surface, ferroplan_airo_pin) | 27 passed, 1 skipped, exit 0 |
| mock gate `scan_mock_usage(["test","lib"])` | `[]` exit 0 |

## Commit

- `fc2adcb0` — `test(airo): W984hx — land W984fx library-circulation AIRo RiskControl trio`
- 4 files changed, 140 insertions(+): mapping, test, ledger, w984fx-probe.md
- one pathspec-scoped commit, message written via `-F` file
- push: fetch-first fast-forward `82f7f558..fc2adcb0` on
  `origin/feat/playwright-surface` (no force)

## Lane cleanup

- `_build-laneW984hx` deleted after landing (see below); verified absent.
