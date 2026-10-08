# W984il — landing batch #9 lane commit receipt

Lane W984il, 2026-10-07, branch `feat/playwright-surface`, checkout `/Users/sac/xaas`.

Base at start: `3961c4ab` (after W984hx batch: fc2adcb0/3961c4ab). Pushed head:
see `git log -1` after push (this file updated in the receipt commit; pushed
head recorded below before push).

## Landed (3 commits)

1. `6fbfb47a` fix(mix_tasks): W984gk doctor/stogaf fixes + 11-test family court.
   lib diffs verified to be exactly the two disclosed fixes in w984gk-probe.md
   (empty-SHA fallback; per-lane census walk cap). Plus one W984il re-tightening:
   the 2,000-file/lane cap still overran the court's 120s timeout against 127
   orphaned `_build-lane*` roots on the landing host — cap lowered to 200/lane,
   truncation still disclosed in the check detail. Court updated accordingly.
2. `c58a8cea` test(courts): 8 family/remainder courts + probes from finished
   lanes: W984hf (11), W984hh (10), W984hj (8), W984he (3), W984hi (3),
   W984ho (7), W984hq (6), W984hp (10). Receipt-only lane W984hp also had an
   untracked court file — landed with its probe in this commit (message above
   lists it).
3. `663786f5` docs(diataxis): W984hv/hy/hz/ik truth-pass edits + receipt-only
   probes w984hk/hs/hv/hy/hz/ik. (w984gz-probe.md and w984hd-repin.md were
   already tracked — skipped. how-to/fix-ash-admin doc already tracked and
   unmodified — nothing to land for gz beyond its probe, already tracked.)

## Gates (real runs, lane build root `_build-laneW984il`, MIX_ENV=test)

- Mock gate: `mix run -e 'IO.inspect(scan_mock_usage(["test","lib"]))'` → `[]`.
- `mix compile` EXIT=0 (cold lane build, asdf-pinned toolchain).
- Batch gate: all 8 court files together → `Result: 53 passed, 0 failures`,
  exit 0. First batch run was 52/53 — the W984gk doctor census test timed out
  at 120s (127 lane roots × up to 2k sync File.lstat each); repaired by the
  cap re-tightening above, then 11/11 gk court and full batch 53/53 green.
- `mix xaas.doctor` smoke run: EXIT=0, well under 120s; lane_leases detail
  shows 113 roots, 112 truncated at the 200-file cap (disclosed truncation).

## Not landed (out of contract)

- All other dirty files in the shared tree (e2e/, playwright.config.cjs,
  lib/xaas/eds|library|operations|semantics, other test files,
  http-api-surface.md, ci_cd.yaml, etc.) belong to other lanes — untouched.
- w984gz-probe.md / w984hd-repin.md / fix-ash-admin doc: already tracked.

## Standing

ALIVE for the landing transition: every landed test file executed green on the
exact committed subject (batch gate), compile + mock gate + doctor smoke green.
Falsifier: any landed court failing on a fresh lane build of HEAD.

## Cleanup

`_build-laneW984il` deleted after push (lane-lease law); verified absent.
