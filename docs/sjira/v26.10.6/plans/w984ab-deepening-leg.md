# W984ab — conference_deepening stale-leg flip (W983a contract)

- Date: 2026-10-07 · Lane: W984ab · Repo: /Users/sac/xaas (branch `feat/playwright-surface`, uncommitted)
- Source order: W984c disclosure (`docs/sjira/v26.10.6/plans/w984c-terminal-guard.md`) — deepening
  "reads are deterministic after writes" fails 10/11 with W983a's `EnforceActiveRegistrationIdentity`
  and passes against HEAD (pre-W983a contract).
- Write set: `test/xaas/conference_deepening_test.exs` ONLY (plus this receipt). No commit.

## Before (stale leg, HEAD-matching semantics)

Leg `(d)` asserted the pre-W981s/W983a contract: with `b` holding a `:cancelled`
registration, a duplicate `create!` for `b` was expected to `raise Ash.Error.Invalid`.
Under the landed `EnforceActiveRegistrationIdentity` (active-only filter), cancelled
re-registration is legal — the create succeeds, so `assert_raise` fails. It also
claimed ETS `unique_attendee_session` enforcement that no longer exists (identity
intentionally absent per `lib/xaas/conference/registration.ex:48-56`).

## After (landed contract; determinism property not weakened)

- Duplicate **ACTIVE** (`:registered`/`:attended`) `(attendee, session)` write → typed
  `Ash.Error.Invalid ~r/has already been taken/` (`EnforceActiveRegistrationIdentity`,
  same error shape the W981s pre-check produced). Aligned with the W981s/W973b court
  (enrollment_journey 5/5, passing).
- Typed refusal leaves the projection untouched: 5 identical re-reads after the refusal.
- Cancelled re-registration remains legal (`re_reg.status == :registered`), projection
  grows 3 → 4 rows; 5 identical re-reads confirm successful writes are deterministic.
- Total row count asserted on the unfiltered read (`== 4`).

## Runs (real tails, fresh root `_build-laneW984ab`, PATH=asdf shims, MIX_ENV=test)

| command | result |
|---|---|
| `mix test test/xaas/conference_deepening_test.exs test/xaas/conference/conference_test.exs` | **14 passed** (deepening 11/11 incl. flipped leg, conference 3/3), exit 0 |
| `mix test test/xaas/conference/enrollment_journey_court_test.exs` | **5 passed** (incl. W973b now-green leg), exit 0 |
| `mix test test/xaas/conference/conference_test.exs test/xaas/conference/keynote_graphql_surface_court_test.exs` | 3 passed (conference_test); keynote leg void — file deleted at 10:54 by another lane between runs (see below) |

Heat check before editing: deepening mtime Oct 7 04:34, conference_test Oct 6 23:36 —
no concurrent write conflicts encountered on my write set.

Out-of-scope observation: `test/xaas/conference/keynote_graphql_surface_court_test.exs`
(existed 09:37, 2395 B) was deleted at 10:54 during my lane's runs — not by W984ab.
Flagging for coordinator census.

## Standing

- Deepening leg: **flipped REPAIRED** — file green on the landed W983a contract (14/14, exit 0).
- Enrollment journey court: ALIVE 5/5 (unchanged, confirms semantics alignment).
- Falsifier used: the leg itself — it fails on the pre-W983a assertion and passes after
  alignment without weakening the determinism property (typed-refusal determinism +
  post-success re-read determinism both asserted).
- Lane build root `_build-laneW984ab`: deleted after runs.
