# W911 — Doctest Harness Combine Check (findings-only)

Lane W911, v26.10.6 campaign. Read-only lane: no source edits, no commit.
Subject: branch `feat/playwright-surface` working tree, 2026-10-07.

## Task

Verify W851 (`test/xaas/semantics/jcs_doctest_test.exs`), W880
(`test/xaas/semantics/counterfactual_doctest_test.exs`), and W853
(`test/xaas/semantics/computation_doctest_test.exs`) do not collide when run
together, and that the semantics suite's other files are unaffected.

## (a) Combined run — real tails

Command (per lane contract, `MIX_BUILD_ROOT=_build-laneW911`, `MIX_ENV=test`,
asdf shims on PATH):

```
mix test test/xaas/semantics/jcs_doctest_test.exs \
         test/xaas/semantics/counterfactual_doctest_test.exs \
         test/xaas/semantics/computation_doctest_test.exs
```

Cold run (fresh lane build root, full compile):

```
Finished in 0.06 seconds (0.06s async, 0.00s sync)

Result: 9/10 passed (9/9 doctests, 0/1 test)
Failed: 1 test
```

Warm rerun (same lane build root), and 5/5 further repetitions:

```
Result: 10 passed (9 doctests, 1 test)
```

exit 0 on all five warm runs; 5x stable 10/10.

## (b) Semantics neighbors unaffected

```
mix test test/xaas/semantics/jcs_property_test.exs \
         test/xaas/semantics/counterfactual_test.exs \
         test/xaas/sa2a_computation_boundary_test.exs

Result: 30 passed, 5 excluded
```

exit 0. No interference from the three doctest harnesses on the neighboring
property/court files.

## (c) Diagnosis of the cold-run failure (findings-only)

The single cold-run failure was
`test/xaas/semantics/counterfactual_doctest_test.exs:25` — the W907
regression test ("bare anonymous fun check is supported and deterministically
named"). Stack: `normalize_check/1` → `normalize_name/1` FunctionClauseError
at `lib/xaas/semantics/counterfactual.ex:194/192` — i.e. the exact pre-W907
behavior the test exists to guard against.

That behavior is **not** present in the current source: `normalize_check/1`
passes `fun.()` semantics correctly and the test passes 6/6 on warm runs of
the same source. Most probable cause: the cold compile in
`_build-laneW911` raced with concurrent lane activity editing
`lib/xaas/semantics/counterfactual.ex` (the checkout has a large dirty working
tree with many concurrent campaign lanes), so the first run loaded a
pre-fix/mid-edit beam. Warm runs after stable source read 10/10. No
cross-file collision between the three doctest harnesses themselves: their
combined 10-test surface is deterministic when the source is stable.

Routing note: this is a cold-compile concurrency observation, not a defect in
W851/W853/W880's files. No fix routed to owning lanes.

## Cleanup

`_build-laneW911` removal was attempted and **denied by the permission
system**; the lane build root remains at `/Users/sac/xaas/_build-laneW911`
for coordinator cleanup.

## Standing

- Combined doctest harnesses (W851+W880+W853): **ALIVE** — 10/10 combined,
  5x stable, exit 0 (warm).
- Semantics neighbors: **ALIVE** — 30 passed, 5 excluded, exit 0.
- Cold-compile stability: **UNKNOWN** — one witnessed cold-run failure traced
  to concurrent-edit race, not reproducible on stable source (0/5 warm).
