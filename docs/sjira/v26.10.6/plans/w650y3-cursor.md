# W650y3 — AtlassianCursor depth court

Lane W650y3 · branch `feat/playwright-surface` · repo `/Users/sac/xaas`
Subject: `lib/xaas/sjira/atlassian_cursor.ex` @ working tree 2026-10-07,
parent commit `52764939`.

## Module surface analysis

`Xaas.Sjira.AtlassianCursor` — 3 public functions, 4 heads, pure data
transformation, no process/IO. The real surface is an offset/token pagination
state machine; there is **no encode/decode, no malformed-cursor input path** —
cursors are internal maps, never serialized to clients. Task framing adapted
accordingly.

- `initial/1` — `%{mode:, next:, exhausted:, seen:}`; unknown mode raises
  CaseClauseError (residual risk, untested, crash-class not invariant-class).
- `params/2` — 3 heads: offset → `%{startAt:, maxResults:}`; token/nil-next →
  `%{maxResults:}` (omits `nextPageToken`); token with token → adds
  `nextPageToken`. Offset nil-next coerced by `|| 0`.
- `advance/2` — exhausted head → typed `{:error, :cursor_exhausted}`;
  offset: vals=`"issues" || "values"`, next=start+len; termination cond
  precedence **total (integer) > isLast > shortfall (length < maxResults)**;
  on done, next=nil. token: `done = isLast == true or is_nil(token)`.

## Court

`test/xaas/sjira/w650y3_atlassian_cursor_depth_court_test.exs` — 5 Chicago
tests, real module, real state assertions, no mocks:

1. Offset roundtrip: params→advance→params threads `startAt` 0→3→6.
2. Typed refusal: `{:error, :cursor_exhausted}`, idempotent.
3. Termination precedence: total > isLast > shortfall, all branches reachable
   with opposing signals.
4. Token mode: nil token ⇒ no `nextPageToken` key; token propagation; isLast
   and nil-token exhaust; exhausted state omits the token key.
5. Boundary/accounting: empty page terminates via `max(len,1)`; `seen`
   accumulates 0/6/3 across pages and modes.

Per-test mutation rationale inline in the file.

## Verification (real output)

Env: `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`, pinned toolchain
(elixir 1.20.2-otp-28). Logs: `/tmp/w650y3_fresh1.log`, `/tmp/w650y3_f2b.log`,
`/tmp/w650y3_fresh3.log`, `/tmp/w650y3_f3b.log`.

- Run A — `_build-laneW650y3-f1`, fresh compile from zero: **Result: 5 passed**, exit 0
- Run B — `_build-laneW650y3-f2` (warm): **Result: 5 passed**, EXIT=0
- Run C — `_build-laneW650y3-f3`, fresh compile from zero, green; test file was
  deleted mid-compile by a concurrent lane ("did not match any file"), restored
  via heredoc, re-run in the fresh-compiled f3 root: **Result: 5 passed**, EXIT=0

Both fresh-root compiles (f1, f3) hold; f3's test execution ran against its
fresh compile. The test file was deleted by concurrent lanes twice and the
receipt once; all restored. Disclosed per same-checkout law.

Earlier disclosures: (1) my own invalid pseudo-syntax (`is nil`/`is true`)
flagged by first compile, fixed to `is_nil/1`/`== true`. (2) Court initially
advanced a token-mode page with no `nextPageToken` expecting success — the real
module exhausts there; fixture fixed, module untouched.

## Mutation rationale summary

Classes killed: startAt-derivation state-loss, exhausted-head removal (infinite
re-fetch), cond-reorder termination flips, nil-key leak in token params,
seen-drift accounting, empty-first-page termination.

## Typed disposition

Not a 2-trivial-function case: 3 functions / 4 heads with a three-branch
termination cond and mode-dependent param shaping — full 5-test court
justified, no UNSUPPORTED reduction claimed.

## Standing

**PARTIAL_ALIVE** — court green 5/5 on two fresh-root compiles (f1, f3) plus a
warm f2 run, on the working tree of `feat/playwright-surface` @ 52764939.
Uncommitted; standing does not extend to main or any other checkout. Residual
risks: `initial/1` unknown-mode CaseClauseError untested; sibling uncommitted
court `w984dp3_atlassian_cursor_court_test.exs` exists in tree (no conflict).

## Falsifiers

- Fresh-root: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=<fresh> mix test test/xaas/sjira/w650y3_atlassian_cursor_depth_court_test.exs` — any failure falsifies.
- Mutate `atlassian_cursor.ex` cond order (swap total/isLast) → test 3 must fail.
- Remove exhausted head → test 2 must fail.

## Build roots left for coordinator

`_build-laneW650y3`, `-f1`, `-f2`, `-f3` (rm -rf permission-denied; left for
coordinator cleanup per instructions).
