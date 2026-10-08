# W984lo — Landing Batch #13 Lane Commit Receipt

- **Lane**: W984lo · Date 2026-10-08 · checkout `/Users/sac/xaas`,
  branch `feat/playwright-surface` (no branch switch, no stash; explicit
  pathspec `git add --` only; fetch-then-ff push).
- **Base at gate time**: `52ce8236` + concurrent W984kn batch #12
  (`fcef478b`/`6ff734f2`/`1ba31a97`) which appeared mid-session and took
  the jv/ju courts and jn/kl/kh/jx receipts (skipped per dispatch).

## Commits (6)

| SHA | subject |
|---|---|
| `d3189b40` | fix(lib): W984kk notifications 204 silence (repaired from the tree's known-broken else-clause first attempt to the receipt's do-branch `case`), W984jz `:approved_by` accept-list removal, W984kg lease `{:ok, nil}` arm — 3 files |
| `be2591bd` | test(courts): 11 new court files + title_iii M (jv/ju/jk already taken by kn batch #12) |
| `4371fcff` | fix(lib): W984ks orphan-change retirement (2 billing change modules deleted, w984ea court rows dropped, w984er register RETIRED flips + receipt) |
| `9ba3a44f` | docs(sjira): 19 w984 probe/repair receipts + km-wave-receipt + kw-burndown |
| `dc125c8c` | docs(diataxis): truth-pass edits kx/ky/kz/kv/lb (8 files) |
| `038fd867` | docs(registers): closure receipt/regen, runbook 10th addendum, closure plan, W850 manifest, w650y4 + w984dq3 register flips, evidence index |

## Gates (real, `_build-laneW984lo`, pinned asdf toolchain)

- `mix compile` → EXIT=0 (fresh lane root, full dep compile).
- Batch gate (14 candidate court files): **88 passed, exit 0** (title_iii
  excluded by `@moduletag :eu_ai_act`; run separately `--include
  eu_ai_act` → **391 passed**, matching w984ke receipt).
- W984ks gate re-run: `mix test test/xaas/billing` → **80 passed**,
  exit 0 (matches w984ks-retirement.md exactly; receipt arrived on disk
  mid-session and was verified TODO-free before landing).
- Mock gate `scan_mock_usage(["test","lib"])` → `[]`.

## Skips (per dispatch)

- kp/lc/lh/ln and later lp/lq/lr/lt/lw/lx/lz: probes appeared/changed
  mid-session — treated as in-flight/other-lane-owned, not landed.
- e2e/*, playwright.config.cjs, .github/ci_cd.yaml and other M files not
  in the batch #13 candidate list: left uncommitted (other lanes).
- w984kj socket court landed; kn-overlap files deduped via pathspec.

## Standing

ALIVE for batch #13 landing: all commits on real green gates re-run on
this lane's build root; receipts TODO-free at use time.
