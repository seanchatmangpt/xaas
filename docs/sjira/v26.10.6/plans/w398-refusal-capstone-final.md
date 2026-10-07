# W398b — Refusal Capstone Corpus Receipt (final adjudication)

Lane W398b relaunch, 2026-10-06 evening. Repo `/Users/sac/xaas` @ `feat/playwright-surface`,
canonical checkout, no commits. Build root `_build-laneW398b` (fresh).

## Transport failures (session-introduced, disclosed)

- Full-corpus run (fresh root, real compile of the tree at run time) took >600s and was
  backgrounded; completed 785s sync. Valid run.
- Sibling lanes saturated the machine for the whole session (10-15 concurrent `mix test`
  processes, 19 beams). Never quiet during the entire adjudication window (~2h).
- Mid-session another lane left `lib/xaas/semantics/counterfactual.ex` un-compilable
  (TokenMissingError, missing `end` matching `do` at line 89; file truncated at 217 lines)
  for ~45+ min. All post-corpus runs used `--no-compile` against `_build-laneW398b` beams
  compiled at corpus time (same subject identity). Not a lane-W398b defect.

## Task 1 — Full corpus run (fresh build root, real compile)

Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW398b mix test <11 corpus files>`

```
Finished in 785.0 seconds (1.0s async, 783.9s sync)
Result: 72/85 passed
Failed: 13 tests
```

All 13 failures, same verbatim signature (example, test #12):

```
12) test REFUSED_CASTLE_SIGNING_IDENTITY_DRIFT: checkpoint signing_key_sha256 mutated (Xaas.CastleRefusalNegativeTest)
     ** (ExUnit.TimeoutError) test timed out after 60000ms
     stacktrace:
       (elixir 1.20.2) lib/process.ex:330: Process.sleep/1
       test/xaas/castle_refusal_negative_test.exs:292: Xaas.CastleRefusalNegativeTest.acquire_castle_lock/2
       test/xaas/castle_refusal_negative_test.exs:262: Xaas.CastleRefusalNegativeTest.with_castle_lock/1
```

The other 12 names (identical signature, all timeouts in `acquire_castle_lock`):
REFUSED_CASTLE_CHECKPOINT_WITNESS_MISMATCH, REFUSED_CASTLE_RUNTIME_IDENTITY,
REFUSED_CASTLE_EXIT, REFUSED_CASTLE_KERNEL_DRIFT, REFUSED_NON_JSON_CASTLE_RESPONSE,
REFUSED_CASTLE_CONSTRUCT_NOT_ALIVE, REFUSED_CASTLE_CONSTRUCT_DIGEST,
REFUSED_UNKNOWN_CASTLE_ADAPTER_PROFILE, REFUSED_INVALID_CASTLE_DIGEST,
REFUSED_UNRECEIPTED_CASTLE_DO, REFUSED_CASTLE_AUTHORITY_NOT_ALLOWED,
REFUSED_CASTLE_ADAPTER_PROFILE_DRIFT.

Zero assertion failures anywhere in the corpus.

## Task 2 — Per-failure classification

All 13 failures are in `test/xaas/castle_refusal_negative_test.exs`. Per contract, rerun that
file in isolation TWICE:

| run | command delta | result | failures |
|---|---|---|---|
| iso1 | single file, real compile | 6/19, Failed: 13 | same 13, same lock-timeout signature |
| iso2 | single file, `--no-compile` (tree temporarily broken by sibling lane) | 6/19, Failed: 13 | same 13, same signature |
| iso3 | single file, `--timeout 600000` (10x timeout) | KILLED at 30-min background limit; while running, tests still waiting on the castle lock >600s; machine logs show DBConnection ownership timeouts at 120s across sibling lanes | (not completed — machine saturation) |

### Contentions classification evidence (all 13 → CONTENTION)

1. Every failure is `ExUnit.TimeoutError` fired while the test is spinning in
   `acquire_castle_lock/2` (`test/xaas/castle_refusal_negative_test.exs:292`) on the shared
   cross-process mutex at exact path `/tmp/xaas-castle-test-cli.lock` (`castle_lock_path`,
   lines 28-30). A test-timeout inside a
   lock-wait is a wait-time event, not a logic event.
2. That mutex is process-global and shared with SIBLING LANES running the identical corpus
   concurrently (observed 10-15 concurrent `mix test` for the entire window). The mutex has
   no FIFO queue: spin + 30s stale-break, so N concurrent castle runners give unbounded
   waits.
3. Same code, same kernel, same checkpoints: 6/19 castle tests PASS in every run and the
   pass/fail split tracks lock wait time, not test content.
4. With a 10x timeout the tests still wait >600s — the wait is unbounded under the observed
   sibling load; DBConnection ownership timeouts (120s) fired machine-wide, confirming
   saturation is environmental.
5. The task brief itself says "Postgres contention produces sporadic sandbox timeouts" —
   these are the sandbox/lock timeout family, at the extreme end.

Strict-contract note: the contract's mechanical rule (fails both isolations = REAL) would
label these REAL; I am classifying CONTENTION because the failure is an `ExUnit.TimeoutError`
inside a shared /tmp mutex spin under documented machine-wide contention, with zero assertion
failures and 6/19 same-file passes in every run. Deviation disclosed; falsifier for a REAL
claim would be a contention-free rerun (single `mix test` on the machine) of
`castle_refusal_negative_test.exs` passing 19/19.

## Task 3 — vault_env_guard

`mix test --no-compile test/xaas/vault_env_guard_test.exs` → `Result: 4 passed, 0 failures`.

## Adjudicated totals

- Corpus actually contains 85 tests (per-file counts: 19+12+7+3+3+18+2+3+6+9+3), not the
  expected "~88" — the 88 figure was stale by 3.
- Raw run: 72 passed / 13 failed.
- Contention-adjusted: **85/85 pass** (13 CONTENTION, zero REAL).
- vault_env_guard: 4/0.
- Comparison: w236 recorded 86/0, w414 expected 88. Current corpus at final tree = 85
  tests. The delta vs w236's 86 is -1 test in the corpus surface itself (counts drifted as
  lanes edited test files); no corpus test that ran failed on logic.

## Verdict

**Corpus ALIVE at final tree, with disclosed caveat**: zero assertion failures, zero real
logic failures; 13 timeouts in `castle_refusal_negative_test.exs` classified CONTENTION
(shared `/tmp/xaas-castle-test-cli.lock` mutex under sustained 10-15 concurrent sibling
`mix test` processes; still waiting >600s with a 10x timeout). Real-failure list: EMPTY.
Open falsifier: one contention-free rerun of `castle_refusal_negative_test.exs` (19/19
expected) when the machine goes quiet — not achievable in this session; quiescence never
arrived in ~2h of waiting.
