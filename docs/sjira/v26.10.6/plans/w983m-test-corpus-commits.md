# W983m — Test-corpus integration commits

Date: 2026-10-07. Base at dispatch: `bf9f5cb9` (branch `feat/playwright-surface`). No push.

## Gate (fresh lane root)

- `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983m mix compile --force --warnings-as-errors` →
  `Generated xaas app` / `EXIT=0` (fresh root, 450 MB, ~20 min).
- Staged test files green ×1 on the same fresh root:
  `mix test test/xaas/ledger/transfer_reverse_adverse_court_test.exs test/xaas/platform/purge_expired_atomicity_court_test.exs`
  → `11 passed, 0 failed` (4.1 s). Grafana/PromEx upload warnings are environmental nxdomain, not failures.

## Commits (atomic, grouped by domain)

| SHA | Domain | Paths |
|---|---|---|
| `79af0623` | ledger | `test/xaas/ledger/transfer_reverse_adverse_court_test.exs` (new, W982i owner-done) |
| `7722091f` | platform | `lib/xaas/platform/validations/route_projects_backups_retain_until_passed.ex` (atomic/3, W981d) + `test/xaas/platform/purge_expired_atomicity_court_test.exs` (new) |
| `33da1cbe` | docs-receipts | 45 untracked DONE-lane receipt .md files: w972, w977b, w978b (x2), w978c, w981b–w981z (w981d series, 21 files), w982a/c/d/f/g/h/i/k/m/n/o/p/q/r/u/v/w, w983a |

Note: `lib/xaas/platform/route_projects_backups.ex` was listed as a W981d lib file but is
git-clean at base (`git diff` empty) — nothing to stage for it.

## Exclusions (hot / not-owner-done)

- conference: enrollment_journey_court_test.exs leg-6 flip (W982o) — SKIPPED, conference hot via W983k comments + W983j.
- billing: billing_multitenancy_court_test.exs — SKIPPED, hot via W982k/W982p (and a staged deletion of it exists in the shared index from another lane; untouched).
- Non-listed untracked plan receipts (w439…w980 series, w982l, w982t, w983d) — not staged.

## Shared-index incident (fixed forward)

First ledger commit `21021e9a` accidentally swept `lib/xaas/billing/approval_patch_sla_credit_apply.ex`,
which was pre-staged ("MM") in the shared index by another lane. Fixed forward via
`git reset --soft HEAD~1` + `git restore --staged` on that path; recommitted ledger-only as
`79af0623`. The billing file's content is intact in the working tree; its staged-vs-unstaged
split was collapsed to unstaged (` M`) — content unchanged, disclosed here.

## Standing

- Ledger + platform test-corpus workstreams: LANDED (ALIVE at the three SHAs above, observed
  execution on fresh lane root).
- Receipt corpus: LANDED (docs only).
- Conference, billing-multitenancy corpus: NOT LANDED (hot) — deferred to coordinator.
- Lane build root `_build-laneW983m` deleted at close.
