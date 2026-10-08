# W650k2 — Release-audit remediation: verify, gate, commit, push

Date: 2026-10-07 · Lane W650k2 · Repo `/Users/sac/xaas` · Branch
`feat/playwright-surface` · Parent at commit time `bae6bdc1` · Landed
commit **`428ae270`** · Pushed fast-forward `d7fe61cd..428ae270`
(origin/feat/playwright-surface).

## Pre-state verified fresh (all exist on disk)

15 paths confirmed present before gating: the 10 modified remediation
targets, `docs/sjira/v26.10.7/_CLOSURE_PLAN.md`, restored
`docs/sjira/v26.10.6/plans/w649-§5-refresh2.md`, receipts `w645` and
`w650k`. Of these, 3 were already tracked-clean — `_CLOSURE_PLAN.md`,
`w645-release-audit.md`, and `w649-§5-refresh2.md` landed via W650g
integration commit `1bd62808` before this lane ran — so the commit
surface was the remaining 12 paths.

## Gates (pinned toolchain via asdf shims, MIX_ENV=test, fresh root `_build-laneW650k2`)

- `mix compile --force` (fresh lane root): **EXIT=0**. Warning set
  unchanged from W650k's disclosure: pre-existing type warning in
  `lib/xaas/operations/refusal_ledger_export.ex:388`
  (`assert_all_pinned/1`) and unused-function warning in
  `lib/mix/tasks/xaas.airo.compile_shacl.ex:273`
  (`descriptions_with_predicate/2`) — both pre-existing, not
  session-introduced.
- `mix xaas.release_audit`: **ALIVE ×2**, exit 0 both runs. Tails:
  `XAAS_RELEASE_AUDIT ALIVE version=26.10.7 tracked_files=5149
  ash_resources=122` (run 1) and `... tracked_files=5153
  ash_resources=122` (run 2, post-fetch).
- **Findings state: zero findings, not one.** The dispatch expected the
  tag-baseline finding (VERSION=26.10.7 vs newest tag v26.10.6) to
  remain as the designed pre-tag gate. Actual: the `v26.10.7` tag
  exists on the repo (W635/W649 landed it), and W650k's tag-check bug
  fix now compares correctly — so the tag check passes and even that
  finding is cleared. This is a strict improvement over the expected
  state, witnessed exit 0 twice.
- Audit courts: `mix test test/mix/tasks/xaas_release_audit_test.exs
  test/xaas/release_audit_enoent_court_test.exs` → **17 passed, 0
  failures** (exit 0, 29.3 s).

## Commit

Temp-index plumbing (real index carried other lanes' staged files:
`w650w3-ex4pm-commit.md`, `test/xaas/chicago/bridges/ex4pm_test.exs` —
excluded). `read-tree HEAD` → add 12 paths → `write-tree`
(`2890a3c6`) → `commit-tree -p bae6bdc1` → `update-ref` with old-value
guard → minted `75c5155d`.

**Ref race, resolved with zero content loss**: between update-ref and
push, a concurrent lane re-created the commit as `428ae270` — same
message, same parent `bae6bdc1`, all 12 W650k paths **blob-identical**
(per-path `git rev-parse <commit>:<path>` comparison: 12/12 SAME), plus
one extra path (`docs/sjira/v26.10.7/plans/w650w3-ex4pm-commit.md`,
10-line lane-receipt tweak owned by W650w3). My duplicate `75c5155d`
was dropped from the ref history; the content is fully landed in
`428ae270`. Verified `428ae270` is the pushed remote head and carries
the complete W650k surface. No re-commit performed (identical blobs;
a re-commit would be a no-op).

Push: `git fetch` → merge-base check (`d7fe61cd` = remote head, ff
precondition held) → `git push origin feat/playwright-surface` →
`d7fe61cd..428ae270`, fast-forward only, no force.

## Staged / landed table

| path | status in `428ae270` |
|---|---|
| `lib/mix/tasks/xaas.release_audit.ex` | +221/− (constants re-pin + 3 bug fixes) |
| `test/mix/tasks/xaas_release_audit_test.exs` | +215/− (courts on new contract) |
| `lib/xaas/operations/capability_liveness_receipt.ex` | 2 ± (then-49 comment) |
| `docs/claude/diataxis/explanation/architecture-overview.md` | 9 ± (116→122, Governance 28→34, **122** marker) |
| `docs/claude/diataxis/explanation/errc-innovation-grid.md` | 28 ± (historical figures hyphenated) |
| `docs/claude/diataxis/explanation/security-and-testing-decisions.md` | 2 ± (then-49 reframing) |
| `docs/archive/ASH-MIGRATION-PLAN.md` | 2 ± (then-real domains) |
| `docs/claude/diataxis/reference/w849-census-relocate-plan.md` | 2 ± (link repair) |
| `docs/claude/diataxis/reference/w919-census-relocate-plan.md` | 2 ± (link repair) |
| `docs/sjira/v26.10.6/plans/w376-diataxis-tutorial-howto.md` | 4 ± (then-49 reframing) |
| `docs/sjira/v26.10.6/plans/w467-release-audit-pin.md` | 2 ± (regex literal hygiene) |
| `docs/sjira/v26.10.7/plans/w650k-audit-remediation.md` | +130 (W650k receipt, new) |
| `docs/sjira/v26.10.7/plans/w650w3-ex4pm-commit.md` | 10 ± (W650w3's path, landed piggyback — disclosed) |

Already landed separately: `_CLOSURE_PLAN.md` + `w645` receipt +
`w649-§5-refresh2.md` (via `1bd62808`).

## Cleanup (lane-lease law)

`_build-laneW650k2` deleted; temp index files (`/tmp/w650k2*.index`,
patch, msg) deleted. Witnessed gone.

## Standing

- Release audit: **ALIVE ×2** (exit 0, zero findings, ash_resources=122).
- Audit courts: **ALIVE** (17/17).
- Compile: **ALIVE** (EXIT=0 fresh root; 2 pre-existing warnings,
  unchanged from W650k disclosure).
- Commit + ff push: **ALIVE** (`428ae270` on origin).
- v26.10.7 closure-plan preconditions 1+2: **CLOSED** (remediation
  landed; closure plan on mainline history).

## Falsifiers / notes for coordinator

- Expected one-remaining-finding state did not materialize: tag
  `v26.10.7` pre-empts it. If the coordinator's seal script asserts
  exactly one finding, it will see zero instead.
- Concurrent ref races on this branch dropped my first commit object
  (`75c5155d`, dangling) — lanes should use old-value-guarded
  update-ref AND re-check `git rev-parse HEAD` immediately before
  push; the winning commit `428ae270` already carries the full lane
  surface.
