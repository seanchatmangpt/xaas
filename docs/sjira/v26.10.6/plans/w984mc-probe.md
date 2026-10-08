# W984mc — thirteenth landing addendum probe (runbook W984ef→lx conventions)

Date: 2026-10-08 · Lane: W984mc · Branch: `feat/playwright-surface` ·
NO commit, NO stash, NO branch switch, NO build root. Docs-only.

## Subject

Append-only thirteenth dated landing addendum to
`docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md`, following the
W984ef/ft/gn/hs/jg/jy/kl/kv/ld/li/lt/lx conventions.

## Real commands (from /Users/sac/xaas)

- `git log --oneline -15` → HEAD `1ba31a97` (batch #12 receipt);
  zero new commits since W984lx's stated boundary.
- `git fetch origin` + `git rev-parse origin/feat/playwright-surface`
  → `1ba31a9781a6738ec9c3b40775041317ef7e7747` — HEAD = origin;
  push current.
- W984lo batch #13: zero log hits, zero `w984lo*` files in either
  milestone's `plans/` tree → NOT LANDED.
- Per-SHA receipt grep over the batch #12 SHAs; table carries no new
  rows (no commits since boundary).
- On-disk refresh:
  `ls docs/sjira/v26.10.6/plans/ | grep -E 'w984(lo|lh|ls|lu|lz|mb|kp|lc|ko|lq|lp|lr|lw)'`
  → kp/lc/lh/lp/lq/lr/lw/lz present; lo/ls/lu/mb absent.
- `git status --porcelain docs/sjira | grep -c '^??'` → 85 (up from 78
  at W984lx).
- `ls -d _build-lane* | wc -l` → 9 (down from 109 at W984lx).
- `grep -cE '^\| *9[0-9] *\|' docs/cro/artifacts/evidence-claims-index.md`
  → 6 rows in the 90s; rows 93/94/95 read back: `fcef478b` (batch #12
  courts), `6ff734f2` (receipt-only lanes jn/kl/kh), `1ba31a97`
  (receipt itself) — debt flagged by W984lt/lx is now CLOSED.
- `docs/sjira/v26.10.7/_CLOSURE_RECEIPT.md`: still DRAFT, exactly 2
  blockers (seal `56325fa5` not reachable from `origin/main` until
  coordinator merge; ash_pplan `847f487` operator call) — re-verified
  2026-10-08 (W984lf) per the file. Unchanged.
- Census chain unchanged: w984ko witness (1394/1394/1) + w984lq 8th
  re-census (829/810/772/38/19 = 95.3%).
- Falsifier chain lp PASS → lr fix → lw non-vacuity proof: closed on
  disk, unchanged.
- W984ls (route-validations) and W984lu (flake classification): no
  receipt files in either plans tree. In-flight /
  unverifiable-from-disk.
- Mutation audits: kp (#5) + lc (#7) on disk untracked; #6/#8/#9
  absent (no `w984mb*`).

## Result

Addendum appended as the new tail section of the runbook; `git diff`
shows only the W984mc section. All counts above re-read from disk at
write time (receipt-cited counts re-verified, not recalled).
