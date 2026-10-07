# W982q — Register REPAIRED-count reconciliation (DRIFT(REGISTER_COUNT))

Lane: W982q, xaas v26.10.6 campaign, 2026-10-07. Repo: /Users/sac/xaas.
Trigger: W982n's drift flag (plans/w982n-cro-cycle-advance.md §(a)) — register
REPAIRED count 31 (W980j receipt + CYCLE-LOG) vs 32 (disk grep). No mix
commands run; no commit made; test execution deferred to W982o.

## Method

Fresh read of `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md`; awk tally
of the status column over all table rows (not a grep of prose).

## Full row tally (disk, this session)

| status | count |
|---|---|
| OPEN | 17 |
| REPAIRED | 32 |
| TYPED-OPEN | 2 |
| total data rows | 51 |

## The +1 identity

`W969e GAP(same-attendee-re-register-blocked-by-identity)` — appended to the
register after W980j's snapshot (W981s), status REPAIRED citing
`w981s-registration-identity-scope.md`. Matches the dispatch's prediction.

## Evidence verification (all on tree, this session)

1. Receipt on disk: `plans/w981s-registration-identity-scope.md` (present;
   itself states "REPAIRED total 31 → 32").
2. Court test present:
   `test/xaas/conference/enrollment_journey_court_test.exs` — step-6
   re-register leg at lines 402-408 ("Repair of
   GAP(same-attendee-re-register-blocked-by-identity)").
3. Repair on tree: `EnforceActiveRegistrationIdentity` before_action change
   wired at `lib/xaas/conference/registration.ex:76`; module defined at
   `lib/xaas/conference/registration.ex:187`.

## Disposition

The 32nd REPAIRED is **legitimate** — no revert. Register footer updated:
"Total rows: **51** (17 OPEN + 32 REPAIRED + 2 TYPED-OPEN)" plus a dated
W982q reconciliation note citing w982n + w981s. CYCLE-LOG CYCLE-3 entry
appended a correction line resolving DRIFT(REGISTER_COUNT).

## Standing

ALIVE (documentation reconcile: counts re-read from disk, evidence paths
witnessed on tree). Open residue: the W981s court run itself (3/5 ×2 in the
receipt, with both RED legs disclosed as pre-existing pins) is un-re-run this
session — test execution is W982o's assigned scope, not run here.

## Falsifier

An awk status-column tally of the register yielding anything other than
17 OPEN / 32 REPAIRED / 2 TYPED-OPEN (51 rows) refutes this receipt.
