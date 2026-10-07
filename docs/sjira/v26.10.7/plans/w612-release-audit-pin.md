# W612 — release_audit baseline hardening (WP-5, OS-19)

Date: 2026-10-07 · Lane W612 · v26.10.7 campaign · branch `feat/playwright-surface`

## Subject

- `lib/mix/tasks/xaas.release_audit.ex` — extended (not rewritten). W872/W896
  contracts untouched: `required_input!/1`, the W845 typed-:enoent arms, the
  W896 wrapped-refusal render, and the OS-19 parity law all still pass
  (17/17 courts, twice).
- `test/mix/tasks/xaas_release_audit_test.exs` — W612 legs added.

## Validation contract

`check_version_tag/1` inserted as the second check (right after
`check_version/1`):

1. `newest_release_tag/0` (public seam): `git tag --list v[0-9]*`, filter
   `^v\d+\.\d+\.\d+$`, max by parsed `Version` (Enum.max_by/3 sort_fun —
   **not** lexicographic; v26.10.6 > v26.9.29).
2. Tag-absent path: typed finding
   `no vX.Y.Z release tag present for VERSION baseline <ver> — tag absent`.
3. Tag-diverged path (the live path today): tag exists but
   `tag != "v" <> VERSION` → typed finding
   `release tag <tag> does not match VERSION baseline <ver> — pins diverged`.
4. Tag-present path: `closure_receipt_findings/1` (public seam) validates the
   tagged release's closure surface, fail-closed:
   - `docs/sjira/<version>/_CLOSURE_PLAN.md` present;
   - `docs/sjira/<version>/plans/*.md` corpus non-empty;
   - every explicit `docs/sjira/<version>/plans/...md` reference in the
     closure plan resolves to >=1 file on disk (globs expanded via
     `Path.wildcard`).
5. Git transport failure → typed finding, never a crash.

## Real execution (pinned toolchain, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW612)

- `mix compile` fresh root: exit 0 ("Generated xaas app").
- `mix xaas.release_audit` (live tree, v26.10.6 now tagged by W601q):
  exit 1, 19 typed findings — expected: the pre-existing W872/W896-era
  stale-claim/rpc/etc. findings **plus** the new typed baseline finding
  `REFUSED(release_audit, detail: %{finding: "release tag v26.10.6 does not
  match VERSION baseline 26.10.7 — pins diverged"})`. The diverged refusal is
  the contract working: VERSION was bumped to 26.10.7 for this campaign and
  v26.10.7 is not yet tagged. First run (mid-W601q tagging) also exercised
  the semver-order path: it observed v26.9.29 before v26.10.6 landed.
- Courts x2, both runs: `Result: 17 passed`
  (`test/mix/tasks/xaas_release_audit_test.exs` +
  `test/xaas/release_audit_enoent_court_test.exs`), including new W612 legs:
  tag-absent fixture, tag-diverged fixture, tag-present+resolving fixture,
  missing-closure-plan fixture, unresolved-plan-reference fixture, live-tree
  baseline finding observation, and `newest_release_tag/0` /
  `closure_receipt_findings/1` seams.

## Defects found and fixed in-session (all in new code, not the W872/W896 lineage)

1. `Regex.scan(..., capture: :all_but_first)` on a groupless regex yields
   `[[]]` → `hd/1` crash. Fixed with an explicit capture group.
2. `Enum.max_by/3` empty-list `Enum.EmptyError` (no tags) and inverted
   sort_fun comparator (`== :gt` selects the MINIMUM under Enum.sort
   semantics) → empty-guard + `!= :gt`. The inversion was caught by the real
   audit run picking v26.9.29 over v26.10.6 after W601q tagged mid-lane.
3. Test helper cwd leak on assertion failure → `try/after` restore.

## Standing

- check_version_tag fail-closed legs (absent/diverged/receipt-resolution):
  ALIVE on fixture subjects + observed typed refusal on the live tree.
- Closure-receipt legs on a genuinely tagged, fully-resolving release
  (v26.10.7): UNKNOWN — gated on the tag existing; the fixture leg proves the
  path, the live leg fires when W-coordinator tags v26.10.7.
- Pre-existing audit findings (stale-claim corpus, PRD v26.8.21, architecture
  70-total, rpc alignment vs live tree) are pre-existing, disclosed, not
  introduced by this lane.
