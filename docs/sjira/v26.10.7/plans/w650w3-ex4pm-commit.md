# W650w3 — Commit receipt: W650w2 Ex4Pm depth court landed

Lane W650w3, repo /Users/sac/xaas, branch `feat/playwright-surface`, v26.10.7
fleet seal. Date 2026-10-07. Role: verify + commit + push lane W650w2's
landed-uncommitted work (receipt `docs/sjira/v26.10.6/plans/w650w2-probe.md`).
Build root `_build-laneW650w3` (deleted at lane close, see Verification).

## Subject

Committed exactly 2 paths, explicit pathspec:

1. `test/xaas/chicago/bridges/ex4pm_test.exs` (modified, +110/-73 — depth
   court, 7 tests; W650w2's work, mtime-stable >9 min before gating)
2. `docs/sjira/v26.10.7/plans/w650w3-ex4pm-commit.md` (new — this receipt)

Note: W650w2's probe receipt
(`docs/sjira/v26.10.6/plans/w650w2-probe.md`) did not need staging here —
a sibling sweep had already landed it (ed4bd154, "W650h6 sweep 4 commit
1/3"); disk content byte-identical (clean `git status` on the path).
`docs/sjira/v26.10.6/plans/w650w-probe.md` (W650w's, still untracked) was
deliberately left out of this pathspec.

## Gates (real output, fresh lane root)

Freshness: both W650w2 files mtime-identical after a 300 s wait
(1791415236 / 1791415435 unchanged; test file >9 min stable).

1. **Strict fresh-root compile** — `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
   MIX_BUILD_ROOT=_build-laneW650w3 mix compile --force` on an empty root
   (426 MB built, ~30 min under concurrent fleet load): **EXIT=0**
   (mix's own exit code, re-witnessed after the first run's exit was
   tail-masked by the pipe). 5 warnings, all pre-existing in shared-tree lib
   files owned by other lanes (`refusal_ledger_export.ex:388` et al.); zero
   ex4pm-path warnings (grep-verified). `--warnings-as-errors` fails on those
   same pre-existing shared warnings — disclosed, not introduced by this lane.
2. **Ex4Pm depth court** — `mix test test/xaas/chicago/bridges/ex4pm_test.exs`
   → **7 passed, 0 failed, 0 skipped** (0.4 s).
3. **Bridges dir regression** — `mix test test/xaas/chicago/bridges/` →
   **44 passed, exit 0** (includes the 7 new + pplan 5 + sa2a 6 + registry).

Base moved during gating: a31f3745 → d7fe61cd (sibling lane W650z5's
docs-only receipt commit; test/code surface unchanged — verified via
`git show --stat`). Gates ran against the working tree, whose relevant
content equals d7fe61cd.

## Commit / push

- Fetch-first: `origin/feat/playwright-surface` at d7fe61cd, local HEAD
  identical, `--is-ancestor` confirmed → fast-forward.
- Commit SHA: **bae6bdc1** (parent d7fe61cd, `git commit -F <msg> -- <paths>`
  pathspec-scoped, exactly the 2 paths above).
- Incident, fixed forward before push: the first attempt (5defdc0b) staged
  via `git add` + bare `git commit -F` and swept 12 sibling-lane entries from
  the shared index. Repaired by non-destructive `git reset --soft HEAD~1`
  (restoring the exact prior index state for those lanes) followed by a
  pathspec-scoped recommit. bae6bdc1 is the only commit that exists on the
  branch; nothing was pushed between attempts, so no remote history changed.
- Push: fast-forward, no force.
- Addendum (same lane, same day): a shared-`git index` race then folded this
  receipt's SHA-correction edit into the sibling lane W650k2's commit
  (428ae270) via `git commit --amend -- <path>` landing on a moved HEAD;
  `bae6bdc1` retains receipt v1 ("see git log" line) — both forms are
  content-accurate. bae6bdc1 reached `origin` inside 428ae270's ancestry
  (W650k2's push of the amended HEAD). No force, no rewrite of pushed
  history.

## Standing

**ALIVE** for `Xaas.Bridges.Ex4Pm` on this subject: real ex4pm engine
execution, typed refusal passthrough, mutation falsifier (fitness 1.0 →
0.667) all witnessed green twice (W650w2 + this lane's re-run on a fresh
build root). Bridges non-graphlaw family: **COVERED**. Open falsifiers
elsewhere unchanged (W650c's 4 typed OPEN_GAPs — not this lane's scope).

Build root `_build-laneW650w3` deleted after push per lane-lease law.
