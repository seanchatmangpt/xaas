# W946b — Depth-Combine Run 2 (Successor Combined Run)

- **Date**: 2026-10-07
- **Exact subject**: `fab56ae19051c6bc2b501e4a1d6c91312344e2c3` (branch `feat/playwright-surface`) plus concurrent uncommitted sibling edits (shared canonical checkout; the tree moved during the lane — see Sibling Break)
- **Build root**: `_build-laneW946b` (fresh; `mix compile` exit 0, "Generated xaas app")

## Real command (verbatim)

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW946b mix test \
  test/xaas/semantics/ test/eu_ai_act/ test/xaas_web/ test/xaas/library/ \
  test/xaas/operations/ test/xaas/governance/ test/xaas/ultracode/ test/xaas/bridges/ \
  test/xaas/telemetry/ test/xaas/ontology/ test/xaas/conference/ test/xaas/ledger/ \
  --include eu_ai_act --exclude eu_ai_act_open_gap
```

## Result (run 1, full combined suite)

Real tail:

```
Finished in 486.8 seconds (42.8s async, 444.0s sync)
Result: 4034/4047 passed (15/15 doctests, 4019/4032 tests), 12 skipped, 52 excluded
Failed: 13 tests
```

## Failure classification

Immediate `mix test --failed` rerun (run 2, real log `/tmp/w946b-failures.log`):
**10/13 reproduced**, 3 passed on rerun.

### Stable — failed runs 1 and 2 (×2 confirmed) — 10 tests

1. `a real forced AuditLogEntry write failure rolls back approved_by too -- never approved-but-unaudited` — `Xaas.Governance.AuditLogEntryTest` (test/xaas/governance/audit_log_entry_test.exs)
2. `axiom A: gate outcome depends only on opts, never on candidate content` — `Xaas.Semantics.AuthorityDecouplingTest` (test/xaas/semantics/authority_decoupling_test.exs; file has uncommitted sibling edits `M lib/xaas/semantics/computation.ex`, `M lib/xaas/semantics/counterfactual.ex`, `M test/xaas/semantics/authority_decoupling_test.exs`)
3. `mix xaas.machine_experience (real OS process, F3 no-LLM env) --route is UNKNOWN (exit 4) without an experience, KNOWN (exit 0) from one, REFUSED (exit 3) with an exposed credential` — `Xaas.Ultracode.MachineExperienceTest`
4. `RecommendationPipelineReactor ranks candidates concurrently with 6-factor scoring` — `Xaas.Library.Reactors.RecommendationPipelineReactorTest`
5. `W766 Next Read LiveView deepening (a) mount renders the real 6-factor ranker order for crafted fixtures` — `XaasWeb.NextRead.ReaderLiveDeepeningTest`
6. `W766 Next Read LiveView deepening (b) real PubSub inventory broadcast updates rendered availability` — `XaasWeb.NextRead.ReaderLiveDeepeningTest`
7. `duplicate Checkout.borrow with the same idempotency key does not double-decrement available_copies` — `Xaas.Library.CheckoutActuationTest`
8. `same book+user+school but a different idempotency key is a distinct borrow (real double-decrement, not a bug)` — `Xaas.Library.CheckoutActuationTest`
9. `(c) RecommendationLog captures the 6-factor weights and rank output rank_recommendations/3 persists a log row whose weights and ranked_items match the real inputs` — `Xaas.Library.NextReadDeepeningTest`
10. `Dynamic Configuration & 6-Factor Next Read Composite Ranker correctly scores and ranks candidate books based on dynamic 6 composite factors` — `Xaas.Library.NextReadTest` — assertion failure `assert rec_low != nil` (left: `nil`) at test/xaas/library/next_read_test.exs:205

Classification of the 10: 6 of 10 form one Next-Read/6-factor cluster (items 4–10
library-side plus the LiveView pair) — consistent with sibling-in-flight work on the
library/next-read depth surface, not regressions introduced by this lane (lane W946b edited
no code). Items 1–3 sit in areas with uncommitted sibling edits (semantics) or real-OS-process
tests (machine_experience) — sibling-in-flight (semantics files are dirty in the tree) or
flake; not ×2-distinguishable beyond the reproduction fact above.

### Run-1-only failures (passed run 2) — 3 tests — flake, ×1

Run 1's full 13-name list was not captured (tail-only capture); the 3 flake names are
UNKNOWN. One run-1 tail line shows a compile-style warning in
`test/xaas_web/next_read_live_deepening_test.exs:185` (`live(~p"/next-read")`), consistent
with the Next-Read cluster being mid-flight. Standing of the 3 names: UNKNOWN (not grounded).

## Count delta vs prior combine run

No prior W929 depth-combine receipt exists on disk (`docs/sjira/v26.10.6/plans/` has no
w929 file; W929 is in flight). **Count delta: UNKNOWN (no baseline receipt on disk).**
Reference baselines for other scopes only: W911 doctest-combine, W67 castle-combined —
different scope, not comparable.

## Sibling break (run 3, third `--failed` attempt)

Run 3 aborted at compile:

```
== Compilation error in file lib/xaas/operations/capability_liveness_regressions.ex ==
** (SyntaxError) invalid syntax found on lib/xaas/operations/capability_liveness_regressions.ex:83:3:
    error: unexpected reserved word: end
```

`git status` shows `M lib/xaas/operations/capability_liveness_regressions.ex` uncommitted —
mid-edit by a sibling lane. The ×2 classification contract was already satisfied by runs 1–2,
so run 3 was confirmatory only. OBSERVED-BLOCKED(sibling-in-flight) for the third
confirmation run; not retried again per single wait-and-retry budget already consumed by run 2.

## Standing

- Run 1 combined suite: ALIVE (real run, real build root, grounded tail above).
- 10 stable failures ×2: grounded (run 2 failure list quoted above).
- 3 run-1-only flakes: names UNKNOWN (capture degraded).
- Count delta vs prior combine: UNKNOWN (no baseline on disk).
- Run 3 confirmatory: OBSERVED-BLOCKED(sibling-in-flight).
- Lane W946b edited no code; no commit made. Receipt is the only file written by this lane.
- Build root `_build-laneW946b` left for coordinator (sibling lanes actively compiling on the
  shared tree; deletion deferred to integration per coordinator-owned cleanup).
