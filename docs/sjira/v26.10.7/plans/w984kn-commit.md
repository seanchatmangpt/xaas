# W984kn — landing batch #12 lane commit receipt

- Lane W984kn, xaas v26.10.6, repo `/Users/sac/xaas`, branch
  `feat/playwright-surface` (shared canonical checkout; explicit-pathspec
  commits only; no worktree, no stash, no force).
- Task: land the staged-untracked set W984kl enumerated
  (`docs/sjira/v26.10.6/plans/w984kl-probe.md`).

## Gates (this lane, real runs)

- Mock gate: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
  MIX_BUILD_ROOT=_build-laneW984kn mix run -e 'IO.inspect(...scan_mock_usage)'`
  → `[]`, exit 0.
- Batch gate: the 10 candidate court files → **58 passed, 0 failures,
  exit 0** — exactly the sum of the per-lane counts (2+6+9+6+8+5+3+11+3+5).
- Cold lane build root `_build-laneW984kn` compiled from scratch; one
  unrelated PromEx/Grafana `:nxdomain` upload warning during compile
  (environment, disclosed).

## Mid-flight re-scope (disclosed)

W984kf's batch #11 landed while this lane was gating: `9a00385c` (TOFU,
W784), `caf91669` (16 courts — including 14 of this batch's 16 files),
`86c69061` (W784/W902 register flips, kd tally + addendum, jy runbook
addendum, kh W729 flip + addendum, jl/fs receipts), `52ce8236` (kf lane
receipt); plus W984kc's release_audit landing `7d9968d0`. Re-verified all
paths against the new HEAD with explicit pathspec before staging; nothing
duplicated.

## Commits

| SHA | Subject | Paths |
|---|---|---|
| `fcef478b` | test(courts): 10 family/remainder courts from finished lanes | 6 files: courts `family_court_w984jc`, `stragglers_court_w984jv`, `library_pack_render_court_w984ju` + probes w984jc/ju/jv (the other 14 pathspec members were already landed by `caf91669`; git committed only the genuinely-unlanded 6) |
| `6ff734f2` | docs(sjira): receipt-only lanes jn/kl/kh | `w984jn-shacl-drift.md`, `w984kl-probe.md`, `w984kh-w729.md` (kh receipt now on disk, TODO-free; its flip already landed in `86c69061`) |

## Disclosed skips / out-of-lane

- **Runbook addendum #7 (W984kl)** — already landed in `86c69061`; the
  current uncommitted `_INTEGRATION_RUNBOOK.md` diff is a **tenth dated
  landing addendum (lane W984li)**, another in-flight lane's working edit —
  NOT staged here.
- `w984kd-tally.md`, `w984jy-probe.md`, w859 kd addendum + W784/W902 flips —
  landed by `86c69061`.
- `w984kh-w729.md` — landed here (6ff734f2) once it existed and read
  TODO-free; task had gated it on receipt existence.
- **W984kc release_audit** — landed by its own lane in `7d9968d0`; skip
  condition held.
- `w984ip` court + probe: `reactor_undo_court_w984ip_test.exs` +
  `w984ip-probe.md` were landed by `caf91669` before this lane committed;
  this lane's batch gate included it (2 passed leg of the 58).

## Standing

Batch #12 COMPLETE for this lane's contract: every candidate either landed
by this lane or witnessed as landed by batch #11/kc with the skip conditions
the task specified. Falsifier for the landing: `git log --oneline -5` shows
`6ff734f2` / `fcef478b` on `feat/playwright-surface`; the 10-court batch
reruns 58/58 green.
