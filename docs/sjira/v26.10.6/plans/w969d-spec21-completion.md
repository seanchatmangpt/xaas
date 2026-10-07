# W969d — SPEC-21 Completion Receipt

Standing: **ALIVE** (exact subject `fc14f10b`, observed execution)

## Task

Commit b2758300 integrated W969c's SPEC-21 (RouteProjects :create) but omitted the
`lib/xaas/checks/system_actor.ex` map entry — the hunk sat uncommitted, so the
committed courts failed at HEAD while the working tree was green. This lane commits
exactly that hunk.

## Pre-state

- HEAD at lane start: `84a5ef51` (branch `feat/playwright-surface`)
- `git diff HEAD -- lib/xaas/checks/system_actor.ex` showed the uncommitted hunk:
  `{Xaas.Platform.RouteProjects, :create}` added to the SystemActor map after
  `{Xaas.Platform.RouteProjects, :approve}`, with the W969c/SPEC-21 comment.
  Confirmed verbatim before staging.
- W880 doctest file: checked `git status` — no w880/doctest file uncommitted.
  W880's doctest work already landed in `ba9703fb`
  ("fix(semantics): W907 bare-fun + W853/W880/W851 doctest hardening"). No action.

## Session-introduced blockers (fixed forward, disclosed)

Two compile-blocking artifacts from concurrent lanes sat in the working tree:

1. `lib/xaas/bridges/graphlaw.ex` — uncommitted hunk had `defp do_assess` header
   duplicated without a closing `end` (TokenMissingError). Fixed by removing the
   duplicated stray fragment; a concurrent lane repaired it identically seconds
   later (Edit hit file-changed race, re-read showed the fix already applied).
2. `lib/xaas/graphlaw/limit_gate.ex` — untracked new file from lane W976 called
   `fail_closed/2` without defining it (CompileError). Fixed forward by adding the
   missing private `fail_closed/2` (fail-closed `{:refused, ...}` envelope with
   `code: :limit_read_error`, atom keys matching the `assess/2` gate handler).
   This repair remains uncommitted (not this lane's file; left for lane W976).

## Commit

- SHA: `fc14f10bf68f9bebc5458580afbd2ed61eccee39`
- Message: `fix(platform): register RouteProjects :create in SystemActor map (w969c completion)`
- Diff: `lib/xaas/checks/system_actor.ex`, 3 insertions (comment + map entry), exactly
  the W969c completion hunk, staged alone (`git add` of that file only).

## Verification (real output)

Pre-commit (working tree):

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/platform/route_projects_create_court_test.exs
.....
Finished in 0.6 seconds (0.6s async, 0.00s sync)
Result: 5 passed
```

Post-commit at `fc14f10b`:

```
$ ... mix compile   # completed, warnings only
$ ... mix test test/xaas/platform/route_projects_create_court_test.exs
Finished in 0.4 seconds (0.4s async, 0.00s sync)
Result: 5 passed
```

`git status --porcelain lib/xaas/checks/system_actor.ex` → clean; hunk is in HEAD.

## Standing / falsifier status

- Falsifier for this lane ("the hunk is committed and the create court passes at
  the commit that contains it") — passed: 5/5 at `fc14f10b`.
- Not pushed (per instructions). Commit message file
  `docs/sjira/v26.10.6/plans/w969d-commit-msg.txt` left in tree (untracked).
