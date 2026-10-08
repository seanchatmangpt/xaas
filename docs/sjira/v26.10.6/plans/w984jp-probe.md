# W984jp — Mutation Non-Vacuity Audit #4 over Newest Court Subjects

Lane: W984jp · Date: 2026-10-07/08 · Branch `feat/playwright-surface` (no branch switch,
no commits, no stash). Method held exactly per `w984ek-probe.md` + `w984ha-probe.md`
(FILE-SWAP baseline: HEAD-verified snapshots kept in `/tmp/w984jp/` via `cp`, one
surgical lib mutation at a time, targeted court run, `cmp`-verified byte-identical
restore, post-restore green confirmation). Compound-mutation leg convention per W984ha
included (M3c below).

Subjects: W984iv fortune batch (k8s/route_secrets approve rules), W984jc OCEL one-hop
walk, W984ht EDS lib fixes, W984io projection-injection contract, W984iq ARD-005 pins.

Gates: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984jp`.
Fresh lane-root compile: EXIT=0. Baselines (before any mutation): fortune 16 passed,
ocel 6, eds 14, resource 6, ard 51 — all EXIT=0.

## Mutation Matrix

| # | Court (subject lane) | Test file | Mutated lib file | Mutation | During | Verdict |
|---|---|---|---|---|---|---|
| M1 | fortune batch (W984iv) | test/xaas/operations/fortune_batch_court_w984iv_test.exs | lib/xaas/platform/validations/route_secrets_requires_approver.ex | `is_nil(approved_by) or approved_by == ""` → `false or approved_by == ""` (missing-approver guard dropped) | EXIT=2, 15/16 passed | **KILLED** (missing-approver refusal test fails) |
| M2 | fortune batch (W984iv) | same court | lib/xaas/operations/validations/approval_k8s_fault_remediate_suggest_requires_approver.ex | `approved_by == requested_by` → `!=` (maker-checker inverted) | EXIT=2, 13/16 passed | **KILLED** (self-approval refusal + happy-path tests fail) |
| M3a | OCEL one-hop walk (W984jc) | test/xaas/ocel/family_court_w984jc_test.exs | lib/xaas/ocel/case_view.ex | dropped `Enum.reject(&(&1 == object_id))` self-exclusion in `related_object_ids/1` | EXIT=0, 6 passed | **SURVIVED** (single) |
| M3c | OCEL one-hop walk, compound leg | same court | lib/xaas/ocel/case_view.ex | dropped `Enum.reject` AND `Enum.uniq_by(& &1.id)` simultaneously | EXIT=2, 5/6 passed | **KILLED** (dedup test fails: duplicate events surface) |
| M4 | OCEL projection import head (W984jc) | same court | lib/xaas/ocel/projection.ex | deleted `def import(_other), do: {:error, :malformed_ocel_map}` head clause | EXIT=2, 5/6 passed | **KILLED** (FunctionClauseError instead of typed refusal) |
| M5 | EDS whitespace fix (W984ht) | test/xaas/eds/family_court_w984ht_test.exs | lib/xaas/eds/executable_research_claim.ex | `if String.trim(v) == ""` → `if v == ""` (re-introduces W984ht defect #1) | EXIT=2, 13/14 passed | **KILLED** (blank `artifact_ref` accepted → refusal test fails) |
| M6 | EDS non-map run/2 (W984ht) | same court | lib/xaas/eds/falsifier.ex | deleted non-map `run/2` guard clause (re-introduces W984ht defect #2) | EXIT=2, 13/14 passed | **KILLED** (FunctionClauseError instead of error tuple) |
| M7 | projection-injection (W984io) | test/xaas/resource_base_court_w984io_test.exs | lib/xaas/resource.ex | `Xaas.Semantics.Registry.projection(__MODULE__)` → `:w984jp_mutant` constant | EXIT=2, 4/6 passed | **KILLED** (projection==admit==bang value pins fail) |
| M8 | ARD-005 pins (W984iq) | test/xaas/sjira/ard_court_test.exs | lib/xaas/sjira/ard_court.ex | dropped `++ Enum.sort(unlisted)` from ARD-005 failure aggregation | EXIT=2, 49/51 passed | **KILLED** (ARD-005 refusal-inventory pin fails) |

## Standing Verdicts

- M1 route_secrets missing-approver guard: **NON-VACUOUS**
- M2 k8s maker-checker inversion: **NON-VACUOUS**
- M3a OCEL self-exclusion reject: **SURVIVED single, KILLED as compound (M3c)** — the
  reject is individually unobservable because `Enum.uniq_by(& &1.id)` masks it at the
  event level. Second instance of the W984ha redundant-pair finding: a single-clamp-style
  mutation here is a green lie; only the pair is load-bearing.
- M4 import head clause: **NON-VACUOUS**
- M5 EDS whitespace fix: **NON-VACUOUS** — reverting W984ht's real disclosed fix is
  detected; the court genuinely pins its repair, not just its test names.
- M6 EDS non-map run/2 clause: **NON-VACUOUS**
- M7 resource base projection: **NON-VACUOUS**
- M8 ARD-005 pins: **NON-VACUOUS**

7/8 single mutants killed; the 1 survivor killed by its compound leg. No crash-only
kills: every kill was an exact typed/value assertion.

## Tree Cleanliness

Every restore `cmp`-verified byte-identical to the pre-mutation working-tree snapshot
(`/tmp/w984jp/`); the six HEAD-identical subjects were verified equal to
`git show HEAD:` before first mutation. The two EDS files were `M` at lane start
(W984ht's uncommitted fixes); mid-lane the coordinator committed them (ad159c18, W984jm
landing batch #10) — disk now matches HEAD and matches my snapshots
(`SNAPSHOT_MATCHES_DISK` verified). Final sweep: `git status --short` on all 8 subject
paths → empty. Remaining `lib/` edits belong to other lanes (release_audit, billing,
library/book, operations, semantics, controllers) — pre-existing, untouched.

Final green sweep: fortune 16 / ocel 6 / eds 14 / resource 6 / ard 51, all EXIT=0.

Standing: **ALIVE** — non-vacuity observed on exact subjects (W984iv / W984jc / W984ht /
W984io / W984iq courts) on branch feat/playwright-surface, this lane.

## Replay

```bash
cd /Users/sac/xaas
export PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984jp
# baseline the five courts (16/6/14/6/51, exit 0)
# apply one mutation from the matrix, run the paired court, expect EXIT=2
# restore from snapshot (cp), cmp-verify byte-identical, court returns EXIT=0
```

## Cleanup

`rm -rf _build-laneW984jp` SUCCEEDED (exit 0, directory confirmed absent; shutil
fallback confirmed `exists: False`). No lane lease remains.
