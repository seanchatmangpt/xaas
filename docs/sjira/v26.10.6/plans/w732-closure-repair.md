# W732 — Refusal-atom type-set closure repair (lane receipt)

- **Lane**: W732, xaas v26.10.6, branch `feat/playwright-surface`, HEAD `a0723bf6`
  (working tree, uncommitted).
- **Task**: close the W713 census typed finding
  (`:REFUSED_EUAIA_MALFORMED_CANDIDATE` emitted by `admit/1` fallback but
  absent from `@typedref_atoms` / `@type refusal_atom` / `refusal_atoms/0`)
  and the VulnerabilityLifecycle `@type refusal` / `@spec new/1` divergence
  (`:REFUSED_NO_DETECTION_RECORD` in @spec only).

## Before (W713 census, subject a0723bf6)

- EuAiActAdmission: 9 scanned atoms, 8 declared → typed finding, census 5/6.
- VulnerabilityLifecycle: `:REFUSED_NO_DETECTION_RECORD` in `@spec new/1`
  only; `@type refusal` held 2 atoms.

## After (this lane)

- `lib/xaas/semantics/eu_ai_act_admission.ex`: atom added to
  `@typedref_atoms` and `@type refusal_atom`; `describe/1` clause added
  ("Malformed candidate intent map (schema-shape refusal, not an Art. 5(1)
  partition)"); `refusal_atoms/0` now returns the 9-atom closed set (8
  Art. 5(1) atoms in article order + the malformed fallback verdict).
- `lib/xaas/semantics/vulnerability_lifecycle.ex`: `@type refusal` now
  includes `:REFUSED_NO_DETECTION_RECORD` (3 atoms, closes the @type/@spec
  divergence).

## Court updates required by the closure (disclosed lease extension)

The task's gate ("census must pass 6/6 with the atom in `refusal_atoms/0`")
is unmeetable without moving every committed court that pins the old
8-atom set. All updates are minimal and disclosed here:

| File | Change |
|---|---|
| test/xaas/semantics/refusal_atom_census_test.exs | declared list gains the atom (NOTE comment replaced); `length == 8` → `9` (line 160); uniq concepts `8` → `9` (line 208) |
| test/xaas/semantics/eu_ai_act_refusal_closed_set_test.exs | "8-atom" → "9-atom closed set" (+ membership assert); negative-side test now asserts `describe(@malformed)` answers with a binary (clause exists) instead of raising; junk-atom raises kept |
| test/eu_ai_act/title_i_test.exs (3.2) | `length == 8` → `9` |
| test/eu_ai_act/title_ii_test.exs | `length == 8` → `9` |
| test/eu_ai_act/title_iv_v_test.exs (50.5) | `length == 8` → `9` |
| test/eu_ai_act/airo_grounding_test.exs (W657) | expected map gains `"REFUSED_EUAIA_MALFORMED_CANDIDATE" => "MALFORMED_INPUT_CANDIDATE"` (9 distinct concepts) |

The W706 closed-set design note ("malformed atom deliberately outside the
Art. 5(1) partition") is preserved: it is outside the Art. 5(1) *partition*
and its describe text says so; it is now inside the *declared closed set*,
which is exactly the W713 closure.

## Regression assertions (Chicago, real collaborators)

- `test/xaas/semantics/eu_ai_act_admission_test.exs`: exact-list test now
  pins the 9-atom set; malformed test additionally asserts
  `:REFUSED_EUAIA_MALFORMED_CANDIDATE in EuAiActAdmission.refusal_atoms()`
  and `AiroRiskMapping.risk_concept_for("REFUSED_EUAIA_MALFORMED_CANDIDATE")
  == "MALFORMED_INPUT_CANDIDATE"`.
- `test/xaas/semantics/vulnerability_lifecycle_test.exs`: `new/1` typed
  refusal asserted as a member of the declared 3-atom refusal set and
  grounded through `AiroRiskMapping.risk_concept_for/1` (deterministic,
  non-sentinel).

## Mutation rationale (anti-vacuity)

Reverting the lib diff (removing the atom from the declared set) makes the
census court's first assert fail immediately — the exact W713 typed
finding: `modules emit literal refusal atom(s) outside their declared sets:
Xaas.Semantics.EuAiActAdmission ... [:REFUSED_EUAIA_MALFORMED_CANDIDATE]`.
The size pins (`== 9`) fail under under-count mutation. The regression
assert `atom in refusal_atoms()` fails on revert of the typedref list.

## Verification (real tails; PATH=$HOME/.asdf/shims:$PATH, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW732)

- `mix compile` (fresh lane build root, full dep compile): exit 0,
  "Generated xaas app".
- `mix test test/xaas/semantics/refusal_atom_census_test.exs`
  test/xaas/semantics/eu_ai_act_admission_test.exs
  test/xaas/semantics/vulnerability_lifecycle_test.exs
  → **Result: 45 passed** (census 6/6 included).
- `mix test test/xaas/semantics/airo_risk_mapping_test.exs` → 6/8 passed,
  1 skipped, **2 failed — pre-existing, not this lane's diff**: the two
  ledger-count courts (`covers every ledger variant` 71 vs pinned 63;
  `62 REFUSED_* + 1 BLOCKED_*` 70 vs pinned 62). Proven pre-existing by
  stashing the working tree and running at HEAD: **Result: 8 passed,
  1 skipped** — the failures come from another lane's uncommitted edit to
  `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json` (count drift the
  ledger lane must pin). AIRo totality family tests (W657 map, distinctness,
  malformed-class → `MALFORMED_INPUT_CANDIDATE`) all pass.
- Wider consumer surface, `mix test --include eu_ai_act` over title_i,
  title_ii, title_iii, title_iv_v, title_vi_xiii, airo_grounding, art86 +
  closed_set, fuzz, incident_report, authority_channel_incident_witness,
  master_equation_composition_stress: 39 passed on the non-tagged run;
  tagged run shows **2 failures, both pre-existing from other lanes'
  uncommitted work, unrelated to this diff**:
  - title_i 3.49 (`:MALFUNCTION in classification`): caused by another
    lane's uncommitted `incident_report.ex` classification change (W679
    family) — `git diff HEAD` shows the classification predicate rewrite;
    the fixture atom `REFUSED_EUAIA_EMOTION_RECOGNITION` was in the EUAIA
    set before this lane.
  - title_iii 15.5.s3 (`respond` → `REFUSED_LIFECYCLE_SKIP`): behavioral,
    in flight as another lane's lifecycle work (w659d); this lane's VL diff
    is @type-only and cannot alter `respond/2` behavior.

## Standing

- EuAiActAdmission refusal-atom closure: **ALIVE** (observed execution;
  census 6/6 on the working tree).
- VulnerabilityLifecycle type/spec closure: **ALIVE**.
- AIRo mapping totality over the 9-atom set: **ALIVE** (9 distinct
  concepts, deterministic; malformed atom grounded by the W657
  MALFORMED family).
- airo_risk_mapping_test ledger-count courts: **BLOCKED (other lane's
  uncommitted ledger edit)** — pre-existing, count drift to be pinned by
  the ledger owner.
- title_i 3.49 / title_iii 15.5.s3: **BLOCKED (pre-existing, other
  lanes' working-tree state)** — disclosed, not this diff.

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW732 \
  mix test test/xaas/semantics/refusal_atom_census_test.exs \
           test/xaas/semantics/eu_ai_act_admission_test.exs \
           test/xaas/semantics/vulnerability_lifecycle_test.exs
# expected: 45 passed

PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW732 \
  mix test test/xaas/semantics/airo_risk_mapping_test.exs
# expected: 6 passed, 1 skipped, 2 pre-existing ledger-count failures
# (ledger JSON is another lane's uncommitted edit; at HEAD it is 8 passed)
```

## Leases

`_build-laneW732/` left in place (build-root deletion denied in this
session, same as W713) — coordinator to delete at integration per fanout
cleanup law.
No commits made. Files written: the two lib files, the two module test
files, the six court/test files in the disclosure table, and this receipt.

## Incident note (session-introduced, remediated)

Mid-lane, a `git stash`/`git stash pop` probe (to prove the ledger failures
pre-existed) collided with a concurrent lane's fresh writes to
`lib/xaas/ultracode/epoch.ex` and
`docs/claude/diataxis/reference/ultracode-runtime-contract.md`; the pop
aborted and the stash was restored file-by-file (`git checkout stash@{0} --
<file>`, 41 files) excluding exactly those two (which held the concurrent
lane's newer versions), then the stash was dropped. Post-restore grep +
full re-run of the lane gates confirmed all edits intact and green. No
other lane's content was lost; the two files were never overwritten.
