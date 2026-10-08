# W984gd — unclaimed-family probe: `lib/xaas/sa2a/` (W984gd lane)

- Subject: /Users/sac/xaas @ feat/playwright-surface, tested at working tree of 2026-10-07
  ~21:05 local (no commit made; lane-disjoint, no git state commands run beyond status read).
- Court file: `test/sa2a/family_court_w984gd_test.exs` (new, untracked — NO commit per lane law).
- Disjoint from W984dq9/W984es (`test/sa2a/changes/execute_deepening_test.exs`, which courts
  `Xaas.Sa2a.Changes.Execute`); this lane touched zero `lib/` files and zero other test files.
- Did not touch `lib/xaas/a2a/` (another lane's in-flight surface).

## Command receipt

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984gd \
  mix test test/sa2a/family_court_w984gd_test.exs   # Result: 15 passed (ran green 3x)
mix run -e '...scan_mock_usage([...])'              # -> []
```

Mock gate: `[]`. All runs exit 0. Pre-existing unrelated warnings (PromEx/Grafana nxdomain,
AshA2A legacy-compat, autofde-not-on-PATH app-boot warning) are environment noise, not
session-introduced.

## Per-module dispositions (11 modules in lib/xaas/sa2a/)

| module | disposition | basis |
|---|---|---|
| changes/execute.ex | COVERED | courted by W984dq9/W984es (execute_deepening_test.exs, 3 tests) + execute_test.exs; not re-courted (lane disjointness) |
| route.ex | COVERED (indirect+direct) | route_test.exs (21 tests), sa2a_route_surface_test.exs (27), sa2a_bridge_deepening_test.exs (order_formal/tuple tests) |
| court.ex | COVERED + **NEW COURTS (this lane)** | static refusal branches covered (execute_test, court_stale_plan_test, execution_policy_test); the port-access residue courted here |
| executor.ex | COVERED (indirect) | execute_test.exs (Executor pre-flight, FORBIDDEN, replay, BLOCKED), sa2a_bridge_deepening_test.exs (ensure_bridge arms, authority-context assertion). The `authorized/1` defensive `{:ok,false}` 2-tuple and `other` arms are defensive-unreachable (Ash.can called with return_forbidden_error?: true always returns 3-tuples); documented, not double-forced |
| bridge.ex | COVERED (indirect+direct) | bridge_test.exs, bridge_authority_* tests, sa2a_bridge_deepening_test.exs (JSON-lines protocol incl. mid-stream death); the single-slot busy/kill state machine gets NEW courts here |
| execution.ex | COVERED (indirect) | via execute_test.exs full DO path (succeeded/replayed/refused/failed rows) |
| execution_policy.ex | COVERED | execution_policy_test.exs (7 tests, deny-by-default floor) |
| canonical.ex | COVERED + **NEW COURTS (this lane)** | \r/\b/\f escape shortcuts, control-char \u0001 hex4 path, atom→string + integer-map-key encoding vs a REAL python3 cross-implementation, invalid-UTF-8 and non-JSON-term typed raises were all unexercised |
| wave_outcome.ex | COVERED + **NEW COURTS (this lane)** | binary parse path, recovery/1 full mapping (:stop/:replan/:reconcile_before_replan), settlement for failed/timeout/compensated, parse(nil)/parse(42) |
| receipt_feedback.ex | COVERED + **NEW COURTS (this lane)** | string-keyed receipts with "id"/"subject" keys, semantic_subject>subject>exact_subject fallback chain, non-terminal outcome classify-resistance |
| semantic_evidence.ex | COVERED | semantic_evidence_test.exs (admit/attach/nil/digest/authority-refusal) |

## What the new court actually executes (15 tests, zero mocks)

1. `Court.bridge/2` `:bridge_busy` retry-then-success against a genuinely busy single slot
   (real scripted port sleeps 0.5s; holder Task owns the slot; court retries win the real
   plan_hash). Mutation: deleting the retry loop fails the test with {:blocked,:bridge_busy}.
2. `Court.bridge/2` retry-budget exhaustion -> `{:error, {:blocked, :bridge_busy}}` (holder
   sleeps 3s > 50x40ms budget). Mutation: lengthening the budget past 3s flips the outcome.
3. `Court.bridge/2` non-noproc exit catch -> `{:error, {:blocked, {:bridge_exit, :killed}}}`
   (real Process.exit(pid, :kill) mid-call). Mutation: removing the catch clause crashes the
   test task.
4. `admit_unexpected_reply` BLOCKED arm (port answers sa2a_admit with JSON lacking "ok" ->
   Bridge returns {:ok, map}, court's `other ->` arm fires with the {:ok, map} wrapper).
5. `plan_unexpected_reply` BLOCKED arm (same for sa2a_plan).
6. Canonical \r \b \f \u0001 escapes byte-agree with a real `python3
   json.dumps(sort_keys, separators, ensure_ascii)` sha256 (independent implementation, not
   the port grading itself) — the prior suite only crossed \t \n 😀 \u007f.
7. Canonical atom→string and integer-map-key encodings Python-identically.
8. Canonical invalid UTF-8 -> ArgumentError; tuples and pids -> ArgumentError (typed, never a
   mis-hash).
9. WaveOutcome binary-vocabulary parse paths + parse(nil)/parse(42) -> :unknown_outcome.
10. WaveOutcome recovery/1 maps :executed/:refused/:compensated→:stop, :failed/:timeout→:replan,
    unknown→:reconcile_before_replan (asserted against the real ash_a2a RecoveryPolicy).
11. WaveOutcome settlement/chainable? arms for failed/timeout/compensated/binary.
12. ReceiptFeedback string-keyed receipt ("id"/"subject"/"outcome") projects identically.
13. ReceiptFeedback semantic_subject > subject > exact_subject fallback precedence (stop/refused).
14. ReceiptFeedback non-terminal outcome (:busy) stays typed
    (:unknown_outcome_reconcile_first).

Items 4/5 are state-bearing: they are the only paths from a live-but-lying port to the
court's typed BLOCKED (an environment fact, not a policy refusal) — previously nothing
executed them.

## Standing

ALIVE for the court file: real subprocess ports (w741 convention), real single-slot
GenServer concurrency, real python3 cross-implementation, real Ash replan vocabulary; 15/15
green across 3 runs, mock gate []. NO commit made (lane law).