# W236 — Consolidated Refusal-Suite Capstone Receipt

- Lane: W236 (integration), v26.10.6 convergence, repo `/Users/sac/xaas`
- Subject: branch `feat/playwright-surface`, working tree at run time (no fixes, no git actions)
- Command: `cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/castle_refusal_negative_test.exs test/xaas/castle_refusal_negative_batch2_test.exs test/xaas/castle_refusal_negative_batch3_test.exs test/xaas/castle_refusal_negative_batch4_test.exs test/xaas/castle_refusal_negative_batch5_test.exs test/xaas/castle_refusal_negative_batch6_test.exs test/xaas/semantics/r2rml_refusal_test.exs test/xaas/semantics/vkg_refusal_negative_test.exs test/xaas/actuation_refusal_negative_test.exs test/xaas/accounts/token_revocation_test.exs test/xaas_web/plugs/require_internal_api_token_test.exs test/xaas_web/endpoint_body_limit_test.exs`
- Toolchain: pinned asdf (elixir 1.20.2-otp-28), MIX_ENV=test
- Result (verbatim): **Result: 86 passed** — 0 failures, 0 skipped. This is the W202 delta-zero capstone number.
- All 12 listed files existed; none dropped.

## Per-file breakdown (each file also run individually; sum = 86)

| File | Passed |
|---|---|
| test/xaas/castle_refusal_negative_test.exs | 19 |
| test/xaas/castle_refusal_negative_batch2_test.exs | 12 |
| test/xaas/castle_refusal_negative_batch3_test.exs | 7 |
| test/xaas/castle_refusal_negative_batch4_test.exs | 3 |
| test/xaas/castle_refusal_negative_batch5_test.exs | 3 |
| test/xaas/castle_refusal_negative_batch6_test.exs | 18 |
| test/xaas/semantics/r2rml_refusal_test.exs | 2 |
| test/xaas/semantics/vkg_refusal_negative_test.exs | 3 |
| test/xaas/actuation_refusal_negative_test.exs | 5 |
| test/xaas/accounts/token_revocation_test.exs | 4 |
| test/xaas_web/plugs/require_internal_api_token_test.exs | 7 |
| test/xaas_web/endpoint_body_limit_test.exs | 3 |

Consistency check: 19+12+7+3+3+18+2+3+5+4+7+3 = 86 = consolidated-run total.

## Transcript artifacts

- Batch background per-file run output:
  `/private/tmp/claude-501/-Users-sac-xaas/91f5365d-5434-44dc-a0ee-ffb6967a2a2a/tasks/bpobcwxdk.output`
- Consolidated run: `Result: 86 passed`, `Finished in 8.9 seconds (1.4s async, 7.4s sync)`.
- Notes: compile-phase Spark/Ash domain-inclusion warnings (R2RMLRefusalTest resources) are
  pre-existing and warning-only; an earlier single-file retry hit a transient build-dir lock +
  `duplicate_column` migration race while two runs overlapped, cleared on retry (exit 0, 3 passed).
- Standing: ALIVE on exact subject `feat/playwright-surface` working tree, 2026-10-06.

## W263b final

- Lane: W263b (integration), v26.10.6 convergence, repo `/Users/sac/xaas`
- Subject: branch `feat/playwright-surface`, working tree at run time (no fixes, no git actions)
- Toolchain: pinned asdf (elixir 1.20.2-otp-28), MIX_ENV=test
- Date: 2026-10-06

### (1) W236 refusal capstone re-run (exact 12-file command from receipt above)

```
Result: 86 passed
Finished in 7.4 seconds (1.2s async, 6.2s sync)
```

- Target 86 passed: **met**. 0 failures, 0 skipped.
- First attempt hit a build-dir lock held by a concurrent process (PID 63714) and failed
  during protocol consolidation (`could not write to .../consolidated/Elixir.Bandit.HTTPTransport.beam`);
  waited for the lock to clear, retried once, clean run above. Same transient class as
  recorded in the original W236 receipt.

### (2) `mix test test/mix --seed 0` (W249's discriminating order)

```
Result: 48 passed, 1 skipped, 15 excluded
Finished in 18.2 seconds (0.4s async, 17.8s sync)
```

- Target 48 passed / 1 skipped / 0 failed: **met**. (15 excluded are the pre-existing
  `@tag :exclude`d tests, unchanged.)

### Standing

ALIVE on exact subject `feat/playwright-surface` working tree, 2026-10-06. Both
convergence verification targets reproduced with real output; no code changes made.

## W312 post-format

Command:

```
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/castle_refusal_negative_test.exs test/xaas/castle_refusal_negative_batch2_test.exs test/xaas/castle_refusal_negative_batch3_test.exs test/xaas/castle_refusal_negative_batch4_test.exs test/xaas/castle_refusal_negative_batch5_test.exs test/xaas/castle_refusal_negative_batch6_test.exs
```

Real output (tail):

```
Result: 62 passed
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```

All green: 62 passed, 0 failures, 0 skipped. Format-only re-run post-W237 confirms no behavioral change across all six castle refusal negative batches.
