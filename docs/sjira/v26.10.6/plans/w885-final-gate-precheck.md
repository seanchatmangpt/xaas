# W885 — Final gate precheck (receipt)

- **Lane**: W885, v26.10.6 campaign.
- **Subject**: /Users/sac/xaas @ `feat/playwright-surface`, HEAD `a0723bf6`, canonical checkout. Read-only vs the tree; only this receipt written. No commit, no build root.
- **Task**: coordinator pre-commit dry check against W881's final manifest (`docs/sjira/v26.10.6/plans/w881-manifest-final.md` + the `## Final (W881)` section of `_COMMIT_MANIFEST_W850.md`). Findings-only.

## (a) Coverage falsifier — `git status --porcelain` vs manifest groups

Method: extracted every path named anywhere in `_COMMIT_MANIFEST_W850.md` (both the CG-01..CG-15 staging section and the Final section), diffed against live `git status --porcelain` (444 entries).

- **230 of 334 untracked entries** are `docs/sjira/v26.10.6/plans/*.md` receipts → covered by the CG-14 receipt blanket.
- **All 4 deletion pairs** — covered by adjudication/OPERATOR row 1.
- **Untracked dirs** `lib/xaas/a2a/validations/`, `lib/xaas/ledger/validations/`, `priv/semantic/generated/` — covered (W772 / W762→CG-03 adjudication; OPERATOR row 2).
- **Adjudicated transients** `cleanup-plan.json`, `test/w707_tmp/` — covered (delete, do not commit).

**Exact coverage gaps (working-tree paths named nowhere in the manifest):**

| Path | Status | Probable owner (receipt on disk) |
|---|---|---|
| `lib/xaas/semantics/dataset_admission.ex` [M] | not named in manifest | W865 (`plans/w865-gap3-fix.md` — receipt names exactly this file + its test) |
| `lib/xaas/semantics/jcs.ex` [M] | not named in manifest | W851 (`plans/w851-jcs-doctests.md` — receipt's stated diff is exactly jcs.ex + the doctest harness) |
| `test/xaas/semantics/jcs_doctest_test.exs` [??] | not named in manifest | W851 (same receipt) |
| `test/xaas/ledger/reversal_deepening_test.exs` [??, inside untracked dir `test/xaas/ledger/`] | dir not named in manifest | W799 (`plans/w799-reversal-deepening.md`) |
| `test/xaas/release_audit_enoent_court_test.exs` [??] | not named in manifest (manifest names only `lib/mix/tasks/xaas.release_audit.ex`, W814/W845 VERIFY-AT-COMMIT) | W845 (`plans/w845-audit-enoent.md`, probable) |

Interpretation: these are post-W881 lanes (w851, w865, w799-reversal, w845 court) whose
diffs landed after the manifest's path census; the manifest is stale by exactly these 5
paths. Not a missing-owner situation — every gap has a landed receipt naming it. The
manifest needs a 5-path addendum row (or a fresh blanket row covering post-W881 lanes
with landed receipts) before the coordinator stages.

## (b) Receipt presence — test -f sweep (real, this lane, 2026-10-07)

| Check | Receipt | State |
|---|---|---|
| Census certified | `plans/w821-terminal-census-2.md` | **LANDED** (test -f OK) |
| Gate green | `plans/w778-gate-fix-verify.md` | **LANDED** (test -f OK) |
| Priority e2e | `plans/w842-e2e-revalidation.md` | **LANDED** (test -f OK) |
| Doctor statuses | `plans/w847-doctor-recal.md` | **LANDED** (test -f OK) |
| W875 adjudication | `plans/w875-hold-adjudication.md` | **LANDED** (test -f OK) |
| W810–W826 wave sample | w810, w811, w826 (sampled) + W881's full 17-receipt sweep | **LANDED** |
| W878 lease census | `plans/w878-lease-census.md` | **LANDED — CHANGED SINCE W881**: W881 recorded this PENDING (not on disk); it is now on disk (`du -sk` census, ~28.57 GB deletable across 73 lease dirs). One of W881's two PENDING rows resolves to LANDED. |

**Checklist state: 7 LANDED / 1 PENDING** (only "explicit user commit instruction" remains PENDING). All 8 test -f checks returned present; zero missing.

## (c) Drift vs W881's recorded numbers

| Metric | W881 (recorded) | W885 (live) | Drift |
|---|---|---|---|
| `git diff HEAD --stat` tail | 112 files, +3213/−458 | **111 files, +3331/−477** | −1 file, +118 ins, +19 del |
| `git status --porcelain` entries | 440 | **444** | +4 |
| untracked (`??`) | 328 | **333** | +5 |
| modified unstaged (` M`) | 98 (combined M) | **66** | — |
| modified staged (`M `) | 10 MM reported | **30** | — |
| `MM` | 10 | **11** | +1 |
| deleted (`D`+` D`) | 4 | **4** | 0 |

The −1 file / +118 ins / +19 del and the +5 untracked / +1 MM are consistent with the
post-W881 lane diffs landing (jcs doctests, dataset_admission fix, w882/w884/w885
receipts, w878 receipt) — same channel as the (a) gaps, no unexplained drift.

## (d) OPERATOR rows — final gate list

1. **Deletion-pair staging confirmation** (W792 receipted deletion): the 2 platform
   pairs (`route_orgs_custom_domain_approve.ex` + `route_orgs_custom_domain_requires_approver.ex`,
   `route_projects_backups_approve.ex` + `route_projects_backups_requires_approver.ex`);
   operator confirms intent, stage with the CG-06/W792 group.
2. **priv/semantic/generated/ generator step**: run the lawful generator and commit the
   projection, or leave uncommitted this pass. Operator call; never hand-commit.
3. **W786/W804 dev migrate**: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=dev mix ecto.migrate`
   on `xaas_dev` (migrations 20261007111457 and 20261007120000, the latter deleting dup
   rows — keep-rule: earliest inserted_at, smallest id) before committing CG-01's
   migration files.

## Standing

- **Precheck itself: ALIVE** — every number above from real commands at a0723bf6 this lane.
- **Manifest staging coverage: PARTIAL_ALIVE** — 5 exact path gaps (all receipt-owned,
  post-W881 lanes); manifest needs the addendum before coordinator staging.
- **Commit execution: UNKNOWN** — coordinator-owned. Gate condition now: 7/8 checks
  LANDED, only the explicit user commit instruction PENDING; plus resolve the 5-path
  manifest addendum.
- **W878: PENDING → LANDED** since W881 (receipt on disk; census totals recorded above).

## Falsifiers (carried + new)

- Any checklist row LANDED whose receipt goes absent at commit time (none observed).
- Any manifest path absent from live `git status` at commit time (W867's falsifier).
- **New (this lane)**: any of the 5 gap paths staged into a group other than its landed
  owner receipt (w851/w865/w799/w845) refutes the staging coverage claim.

## Replay

```
git -C /Users/sac/xaas diff HEAD --stat | tail -1
git -C /Users/sac/xaas status --porcelain | awk '{print substr($0,1,2)}' | sort | uniq -c
comm -23 <(git -C /Users/sac/xaas status --porcelain | awk '{print substr($0,4)}' | sed 's:/$::' | sort -u) \
         <(grep -oE '(lib|config|test|docs|e2e|priv|assets|rel|bin)/[A-Za-z0-9_./-]+' /Users/sac/xaas/docs/sjira/v26.10.6/_COMMIT_MANIFEST_W850.md | sort -u)
for f in w821-terminal-census-2 w778-gate-fix-verify w842-e2e-revalidation w847-doctor-recal w875-hold-adjudication w810 w811 w826 w878-lease-census; do ls docs/sjira/v26.10.6/plans/${f}*.md; done
```
