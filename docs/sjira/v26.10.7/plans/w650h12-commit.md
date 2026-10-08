# W650h12 lane receipt — W984dp3 AtlassianCursor depth court: verify + gate + land

**Standing: ALIVE (gates witnessed ×1 this lane; content already landed by coordinator integration — no new commit required, empty commit refused).**

## Subject

- Repo: /Users/sac/xaas, branch `feat/playwright-surface`
- HEAD at verification: `64e1595e` (`test(governance): W984ds — land W984dr2 governance courts (DR failover + audit export token freeze)`), in sync with `origin/feat/playwright-surface`
- Task: W984dp3 receipt + court test `test/xaas/sjira/w984dp3_atlassian_cursor_court_test.exs`

## Findings vs. task premise (stale)

1. Task said the court test was "landed-untracked". **Stale**: it is tracked at HEAD,
   landed via W650h6 (`9ec12305`, sweep 4, receipt-mapped w984d* files).
2. Task said stage test + receipt and commit. **Superseded**: while this lane's strict
   compile gate ran (~20 min fresh root), coordinator integration landed both — the
   receipt's run-2/ALIVE content is byte-identical at HEAD
   (`git show HEAD:docs/sjira/v26.10.6/plans/w984dp3-sjira.md`). Working tree is clean
   for both paths; `git commit` with explicit pathspec returned "no changes added".
   No empty commit was made.

## Gates (this lane, fresh `_build-laneW650h12`, pinned asdf toolchain, MIX_ENV=test)

- `mix compile --force` — **EXIT=0** (fresh root, 209 deps + app compiled)
- `mix test test/xaas/sjira/w984dp3_atlassian_cursor_court_test.exs` — **5 passed, 0 failures, exit 0** (~0.09s async)
- `git fetch` before push check — branch up to date with origin (no ff divergence)

## Files

- `test/xaas/sjira/w984dp3_atlassian_cursor_court_test.exs` — tracked, clean at HEAD (landed 9ec12305)
- `docs/sjira/v26.10.6/plans/w984dp3-sjira.md` — tracked, clean at HEAD (run-2 ALIVE content landed by coordinator)

## Falsifier

The court (5 tests, real AtlassianCursor module, real returned state) passes at current
HEAD `64e1595e` in a fresh compile; a green run on a stale/non-fresh root or a failing
run at HEAD would falsify this receipt.

## Standing

ALIVE — court witnessed green on the exact subject (fresh-root compile + run at
`64e1595e`); receipt on disk verified; both paths confirmed clean and landed. No new
SHA minted by this lane (nothing to commit). Lane build root `_build-laneW650h12`
deleted at integration per cleanup law (first `rm -rf` attempt was permission-denied;
sandbox-escalated retry succeeded — root confirmed absent).

## Standing vocabulary

ALIVE (witnessed execution on exact subject) — not to be read as a new-commit receipt.
