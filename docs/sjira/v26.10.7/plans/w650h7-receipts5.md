# W650h7 — Receipt sweep 5 (v26.10.7 fleet seal)

Date: 2026-10-07 · Lane: W650h7 · Repo: /Users/sac/xaas · Branch: `feat/playwright-surface`

Task: progressive unblocking of W650h6's sweep-4 exclusions. Enumerate still-untracked
sjira receipts + test files; stage newly-completed-lane receipts and their mapped tests;
gate; 2 commits; push ff.

## Enumerated untracked (this sweep's scope check)

`docs/sjira/v26.10.6/plans/*.md` + `docs/sjira/v26.10.7/plans/*` untracked:
w649-3022475-refresh2, w984cw4-ops-probe, w984di-sjira-probe, w984dj5-generation,
w984dk-provenance, w984dp4-probe, w984dq2-autofde, w650f2-c0-flip, w650g4/g5/g5b,
w650i, w650k, w650n, w650p, w650q, w650q2, w650r(+txt), w650v2, w650z2, w651/b/c/c2/d/e/f.

Untracked `test/xaas/**/*.exs` — 40+ files, mapped below.

## Receipts checked (task items 2 & 4) — tracked status at sweep time

| receipt | on disk | tracked |
|---|---|---|
| w984dj5b2-lock-encode.md | **NO** (not on disk) | — |
| w984dj6-host-reconcile.md | yes | TRACKED (already landed) |
| w640-differential-shacl.md | yes | TRACKED (already landed) |
| w984dq3 receipt | NO — not on disk | — |
| **w984dp4-probe.md** (v26.10.6) | yes | UNTRACKED → staged this sweep |
| w984dg receipt | NO — not on disk | — |
| w984dr receipt | NO — not on disk | — |
| w650y3-cursor.md | NO — not on disk | — |
| w650y4-status-transition.md | NO — not on disk | — |
| w650g3-commit.md | yes | TRACKED (already landed) |
| w650f2-c0-flip.md | yes | UNTRACKED → staged this sweep |
| w650h6-receipts4.md | yes | TRACKED (already landed) |

## Mapped and staged this sweep

| test file (staged) | receipt (staged) |
|---|---|
| test/xaas/operations/project_measure_github_actions_court_w984dp4_test.exs | docs/sjira/v26.10.6/plans/w984dp4-probe.md |

- `w650f2-c0-flip.md` staged (lane done, receipt on disk, was untracked).
- Test verified: `MIX_ENV=test mix test test/xaas/operations/project_measure_github_actions_court_w984dp4_test.exs`
  → **5 passed, 0 failures** (real run, 0.3s).
- Strict fresh-root compile: `MIX_BUILD_ROOT=_build-w650h7 MIX_ENV=test mix compile` → EXIT=0
  (build root deleted after gate).

## Still excluded (NOT staged, with reason)

| class | items | reason |
|---|---|---|
| receipt not on disk | w984dj5b2-lock-encode, w984dq3, w984dg, w984dr, w650y3-cursor, w650y4-status-transition | receipt absent; mapped tests stay excluded (bridges/w984dq3_durable_adapter, marketplace/catalog_consumption_depth_w984dg, governance/w984dr_{environment,pentest_finding_status}_court, sjira/w650y3_atlassian_cursor_depth_court, conference/registration_status_transition_court_w650y4) |
| deliberately-excluded older probes (on disk pre-sweep-4, not in unblock list) | w984cw4-ops-probe, w984di-sjira-probe, w984dj5-generation, w984dk-provenance, w984dq2-autofde | W650h6 sweep 4 enumerated these as exclusions already; not in this sweep's named unblock set — left to sweep 6 / owning lanes |
| other untracked receipts | w649, w650g4/g5/g5b, w650i/k/n/p/q/q2/r/v2/z2, w651b-f | not named by this sweep; owning lanes |

Standing: PARTIAL_ALIVE — dp4 court landed with its receipt; named sweep-5 unblocks
w984dj5b2/w650y3/w650y4/dq3/dg/dr remain BLOCKED on receipts landing.
