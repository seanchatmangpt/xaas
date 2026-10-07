# W133b — compile_prose migration STOP (receipt)

*Backfilled by coordinator from lane completion report.* Subject: /Users/sac/xaas + /Users/sac/ggen_igniter, 2026-10-06.

## STOP verdict
The compile_prose → observe_prose migration cannot proceed without faking equivalence.

- Courts GC23-0.sh/2/3/12 require BOTH `compiled/propositions.ttl` AND `compiled/orders.ttl`, an `ADMITTED: N propositions` line, per-gate `REQUIRED_BY` tally, `CHECK: ... outputs recompute byte-identically`, and a work-order count.
- Successor `observe_prose` (ggen_igniter dc27242, "prose is observation-only") emits propositions.ttl only — `orders.ttl` was deliberately removed (SJ-002: Prose ↛ WorkOrder). Output-line formats differ (OBSERVED: vs ADMITTED:, no REQUIRED_BY).
- Input flags map fine; the gap is the output contract. Court scripts live outside test-file lane ownership.

## Disposition
OS-9 (law evolution): courts need observation-only redesign — v26.10.7+ work, not convergence. Test-side: W155/W195 typed-skipped the machinery-dependent tests (re-arm at machinery-bearing SHAs).
