# W313 — Final sjira-root + semantics receipt (post-format)

- Subject: /Users/sac/xaas @ d1db2b03179975213c14663b9dbd86b5ac2a14cf (branch feat/playwright-surface)
- Date: 2026-10-06, integration lane W313, v26.10.6 convergence
- Command (run as given):
  `PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test mix test test/sjira test/xaas/semantics`
- Result (verbatim): `Result: 62 passed, 4 skipped` (0 failures)
- Runtime: 53.2 seconds (1.2s async, 52.0s sync); re-run with `--trace` confirmed same counts.
- Failures: none.
- Skips (all typed, all in `test/sjira/v26_9_23_goal_test.exs` — GGEN_IGNITER_DIR-dependent
  real-subprocess courts):
  1. registry resolves GC-26.9.23 (graph/order receipts/court env) [L437]
  2. `mix xaas.stop_court --checkpoint GC-26.9.23 --only GC23-0` real-subprocess ADMITTED ALIVE receipt [L503]
  3. GC23-0 real sh + ggen_igniter `compile_prose --check` refuses hand-edited compiled/orders.ttl [L844]
  4. GC23-3 real sh + ggen_igniter `--admit-goal` refuses goal.ttl missing sj:postcondition (F1) [L864]
- Standing: ALIVE for test/sjira + test/xaas/semantics at d1db2b03.
