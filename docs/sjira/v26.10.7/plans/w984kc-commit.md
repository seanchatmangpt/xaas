# W984kc — release_audit glob fix landing receipt

Subject: `/Users/sac/xaas` @ `feat/playwright-surface` (lane W984kc, shared
canonical checkout). Lands the uncommitted lib fix recorded by
`docs/sjira/v26.10.7/plans/w984kb-push.md`.

## Diff verification (step 1)

`git diff lib/mix/tasks/xaas.release_audit.ex` = exactly one hunk (+15/−1):
`ref_resolves?/1` extracted with `Path.wildcard` character-class widening
(`[[...]]` classes widened to `?` before resolution), W984gv's disclosed fix.
No other content in the diff; no split-staging needed.

## Disclosure: w984gv-probe.md does not exist

`docs/sjira/v26.10.7/plans/w984gv-probe.md` is absent from the working tree and
from all history (`git log --all -- '*w984gv*'` → no receipt commit). The task
brief's "+ w984gv-probe.md if untracked/modified" condition is therefore
vacuously unsatisfied; only the fix itself lands.

## Gates (all real runs, pinned toolchain, `MIX_BUILD_ROOT=_build-laneW984kc`)

- `mix compile` → **EXIT=0**
- `mix test test/xaas/release_audit/ test/mix/tasks/xaas_release_audit_test.exs`
  → **19 passed**, exit 0
- `mix xaas.release_audit` → **exit 0, zero findings**
  (`XAAS_RELEASE_AUDIT ALIVE version=26.10.7 tracked_files=5435 ash_resources=122`)
- Mock gate `scan_mock_usage(["test","lib"])` → **`[]`**

## Audit-zero repair (disclosed, within lane)

The first audit run (exit 1, 4 findings) was itself the widened-glob fix
working: it surfaced verbatim quoted stale literals (`all 6 real domains`,
`all 49 resources`, `44 of 49 resources`, `for all 49 resources`) inside
`w984ia-audit-witness.md` and `w984ir-remediation.md` — the scanner
self-trigger class those two docs themselves document. Remedy applied is the
one both docs prescribe (w467 hyphenation precedent): quoted before-literals
hyphenated with the pre-fix form elided. Zero findings on re-run.

## Commit

See commit message (this file + lib fix + the two repaired receipt docs,
pathspec commit, `-F` message file). Push: fetch-first fast-forward only.
