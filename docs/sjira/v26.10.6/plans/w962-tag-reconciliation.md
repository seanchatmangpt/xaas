# W962 — open-gap tag reconciliation (W935b discrepancy follow-up)

- Date: 2026-10-07
- Lane: W962, xaas v26.10.6 campaign
- Subject: branch `feat/playwright-surface`, HEAD `fab56ae1` + live shared working tree
  (no commits made, per lane contract; no lib/ or test/ edits by this lane)
- Build root: `_build-laneW962` (deletion denied by the permission system — left for
  coordinator per the lane-contract fallback)
- Toolchain: asdf shims (elixir 1.20.2-otp-28), MIX_ENV=test
- Role: reconcile W935b's flagged discrepancy: gated run excluded 1 test but census
  found 34 open-gap tests ("~33 open-gap tests ran and passed INSIDE the gated 1352").

## Verdict

**DEFENSIBLE — and stronger: the flagged discrepancy does not exist on the current
tree.** No mis-tagged tests exist. The open-gap tag binds exactly 1 test — the
by-design Art. 49(3) flunk marker. W935b's census of 34 (33 passed + 1 flunk) is a
non-reproducible outlier, most plausibly captured mid-edit in the shared-tree churn
window before the 06:46 commit (`9a8ba282`, which landed the W732/W861 title
restructures; this lane itself hit two live mid-write compile races this session:
`lib/xaas/operations/capability_liveness_regressions.ex` at 07:39 and
`lib/xaas/governance/checks/freeze_window_active.ex` at 07:45, both transient).

## (a) Tag sites and scopes (real greps)

Exactly 4 runtime declaration sites repo-wide (plus doc-comment mentions only in
`title_ii_test.exs`):

| file:line | declaration | scope | tests bound now |
|---|---|---|---|
| `test/eu_ai_act/title_i_test.exs:577` | `@moduletag :eu_ai_act_open_gap` | per-module (`TitleIOpenGapsTest`) | 0 — `@gap_details` empty since W648b |
| `test/eu_ai_act/title_iii_test.exs:1133` | `@moduletag :eu_ai_act_open_gap` | per-module (`TitleIIIOpenGapsTest`) | 0 — `TitleIII.Lines.open_gaps/0` returns [] |
| `test/eu_ai_act/title_vi_xiii_test.exs:803` | `@moduletag :eu_ai_act_open_gap` | per-module (`TitleVIXIIIOpenGapsTest`) | 0 — `TitleVIXIII.Lines.open_gaps/0` returns [] |
| `test/eu_ai_act/title_iv_v_test.exs:451` | `@tag :eu_ai_act_open_gap` | per-test (in `:open_gap` case clause) | 1 — Art. 49.3, flunks by design |

The three gap modules carry ONLY `:eu_ai_act_open_gap` (deliberately no
`:eu_ai_act` — their moduledocs document the include-over-exclude resurrection
hazard); the iv_v generator tags EVIDENCED/NOT_APPLICABLE tests per-test with
`:eu_ai_act` and OPEN_GAP tests with ONLY `:eu_ai_act_open_gap`.

## (b) Intended convention (W648/W779/W815 design)

Deliberate and documented in-file and in the receipts:
- Gap-marker tests (flunk by design) carry ONLY `:eu_ai_act_open_gap`; the gated
  run `--include eu_ai_act --exclude eu_ai_act_open_gap` excludes them, and the
  census selects exactly them. Gated "1 excluded" IS the designed signal that
  exactly one real typed open gap (49.3) remains.
- All other eu_ai_act tests carry `:eu_ai_act`; the per-file moduletag shape on
  gap-module files is not accidental — it is the W525b/W534/W525 split-module
  restructure (moduledocs explain the resurrection hazard explicitly).
- W779/W815 record the deliberate 1-open-gap design; W815 re-stamped the
  census-vs-gate delta = 1 as the invariant.

## The mechanism that makes both of W935b's run-1 numbers correct

ExUnit resolves includes OVER excludes (documented in-file): the gated run
excludes only tests carrying ONLY `:eu_ai_act_open_gap`. On the current tree that
is exactly 49.3 → gated "1 excluded" is correct AND the census selects exactly
that 1 test. Gated and census are consistent by design; the "~33 ran inside the
gated run" reading was the wrong inference from a bad census witness.

## Real runs (this lane, `_build-laneW962`, real tails)

| run | command | result |
|---|---|---|
| gated | `mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap` | **1352 passed, 1 excluded** — matches W935b run 1 exactly |
| census, per-test trace | `mix test test/eu_ai_act --include eu_ai_act_open_gap --seed 0 --trace` | **0/1 passed, 1352 excluded, 1 failure** = `EUAI-ACT 49.3 — OPEN_GAP: Before putting into service...` (`Xaas.EUAIAct.TitleIVVTest`, `title_iv_v_test.exs:453`); every other test in the path traced as `(excluded)` |
| W779-style probe | `mix test test/eu_ai_act --only eu_ai_act_open_gap` | **0/1 passed, 1352 excluded** |

The census trace is the decisive witness: zero additional tag carriers bind
anywhere under `test/eu_ai_act`. No test in the suite both passes and carries the
open-gap tag. W935b's 33 "passing open-gap tests" are not present.

## Why W935b's 34 cannot arise from any committed shape

- Every runtime tag site in HEAD (`fab56ae1`), HEAD's parent tree
  (`9a8ba282^`), and the working tree binds flunk-by-design tests only;
  open-gap-tagged tests cannot pass in any committed shape (gap-module generators
  pull `Lines.open_gaps()/@open_gaps` and `flunk` unconditionally).
- `@tag` does not accumulate across the iv_v comprehension iterations
  (empirically refuted: census selects 1, not the ~190 iv_v tests after 49.3).
- The only shape reproducing W935b's exact pair (gated exclude=1 AND census=34
  with 33 passing) is 33 tests carrying BOTH tags AND passing — impossible for
  any committed generator.
- `9a8ba282` (06:46 today) did not change the tag structure (verified via
  `git diff 9a8ba282^ 9a8ba282` on the three title files: no tag-site hunks).
- Most plausible capture: W935b's run-2 census ran in the pre-`9a8ba282` churn
  window on a transient mid-edit working tree — the same race class this lane
  hit twice (mid-write `capability_liveness_regressions.ex` 07:39, mid-write
  `freeze_window_active.ex` 07:45). The residual unexplained part (how 33
  flunk-shaped tests appeared to PASS) is flagged honestly: the current-tree
  measurement is decisive for the convention either way, but W935b's run-2 tail
  should be treated as a non-reproducible witness, not evidence of mis-tags.

## (c) Per-test side assignments

No test falls on the defect side. The single tag carrier is the by-design 49.3
gap marker (`title_iv_v_test.exs:453`). Zero mis-tagged test names to list.

## Replay

```bash
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/tmp/w962-replay \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap 2>&1 | grep Result:
# → 1352 passed, 1 excluded
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/tmp/w962-replay \
  mix test test/eu_ai_act --only eu_ai_act_open_gap 2>&1 | grep Result:
# → 0/1 passed, 1352 excluded (the 1 failure is the intentional 49.3 flunk)
```

## Standing

ALIVE (observed): all runs executed in this lane's build root on the live tree;
per-test trace witnessed zero extra tag carriers. Cross-lane flags for the
coordinator:
1. W935b's run-2 census (34) is a transient/non-reproducible witness — the
   convention is defensible as-is; no fix lane required.
2. Pre-existing unrelated: two concurrent-lane files (`capability_liveness_regressions.ex`,
   `freeze_window_active.ex`) were seen mid-write/broken-compile during this lane;
   both compiled clean by 07:53. Not this lane's ownership.
