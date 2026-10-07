# W981f — AIRo wiring ledger Wave-2 receipt

- Date: 2026-10-07
- Subject: xaas @ feat/playwright-surface (working tree, uncommitted —
  coordinator owns commits)
- Method: identical to W981e — exact SHA via `git rev-parse HEAD`,
  plausible AIRo risk dimension with on-disk-verified cited paths,
  falsifier naming the pin court required for UNKNOWN→ALIVE.

## Executed

- Read W981e receipt + current ledger; confirmed `docs/airo/` contained
  only W981e's three repos (ash_graphlaw, ggen-ecosystem,
  chatman-ecosystem) — no duplication risk.
- Verified all six candidate checkouts exist under `$HOME`.
- `git -C <repo> rev-parse HEAD` per repo (real output):
  - ash_atlassian (main): `43e3d21b7c4e4571493fcf3757392ed16f2dd967`
  - ash_dspy (feat/v26926-ashdspy-abb-sbb-seed): `5d985d5332e86d663ba554d249498ba5bd9a0306`
  - ash_kudzu (main): `2d600ffd4a6721ed5534c753bd4031cd2bf77500`
  - ash_planning_center (main): `5ee26cbdc8fef26c92c7691355c76f5aed2e7b2c`
  - ash_expo (test/end-to-end-codegen): `59a80d5e9a18208d8b25c47e02de6e714e0b8e8c`
  - ash_autofde (main): `65cd05e1bd884383456423af3e516981d8747560`
- Stale-number check: W981e flagged ash_atlassian `43e3d21b…` as
  possibly stale; re-verified it IS the current HEAD on main.
- Filesystem check per repo: `find <repo> -iname '*airo*'` (excluding
  `.git`/`_build`/`deps`) → zero matches in all six. No AIRo artifact
  exists anywhere in any of them; no row invented beyond UNKNOWN.
- Surveyed each repo's `lib/` tree to select a plausible risk dimension
  with concrete cited paths (all paths verified present on disk).
- Appended Wave-2 section to `docs/cro/artifacts/airo-wiring-ledger.md`
  (6 rows).
- Wrote reference docs: `docs/airo/<repo>/airo-reference.md` for all six
  repos.

## Standing (per repo)

| repo | HEAD | standing | falsifier |
|---|---|---|---|
| ash_atlassian | `43e3d21b` | UNKNOWN | pin court at SHA w/ vocab sha `6274d2d8…` + cited paths + RiskSource/Control/Risk graph parse |
| ash_dspy | `5d985d53` | UNKNOWN | pin court at SHA, same shape |
| ash_kudzu | `2d600ffd` | UNKNOWN | pin court at SHA, same shape |
| ash_planning_center | `5ee26cbd` | UNKNOWN | pin court at SHA, same shape |
| ash_expo | `59a80d5e` | UNKNOWN | pin court at SHA, same shape |
| ash_autofde | `65cd05e1` | UNKNOWN | pin court at SHA, same shape |

Rows added: 6. Ledger total after W981f: 25 repos (16 wave + 3 W981e +
6 W981f). No UNSUPPORTED(no-referent) rows — every repo had a concrete
cited surface. No commit, no mix command, no build root created.
