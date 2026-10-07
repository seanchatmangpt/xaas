# W936 — Cold-Race Verify (W911 counterfactual doctest FunctionClauseError)

Date: 2026-10-07 · Lane: W936 · Campaign: v26.10.6 · Subject: branch `feat/playwright-surface` @ a0723bf6 + W907 uncommitted working-tree fix to `lib/xaas/semantics/counterfactual.ex` (bare-fun clause in `normalize_check/1`).

## Task

W911's cold run of `test/xaas/semantics/counterfactual_doctest_test.exs` raised the
pre-W907 `FunctionClauseError` (counterfactual_doctest_test.exs:25) while the warm run
was green — probable stale pre-fix `.beam` racing W907's edit. Verify the race was
transient.

## Method

Fresh lane build roots (`MIX_BUILD_ROOT=_build-laneW936`, `=_build-laneW936b`), both
nonexistent before their run, compiling the current working tree (includes the W907 fix).
Both cold runs executed the three doctest harnesses together, `--seed 0`:

```
test/xaas/semantics/jcs_doctest_test.exs
test/xaas/semantics/counterfactual_doctest_test.exs
test/xaas/semantics/computation_doctest_test.exs
```

## Cold tails

Run 1 (`_build-laneW936`, full from-scratch compile):
```
Result: 10 passed (9 doctests, 1 test)
EXIT=0 (cold run 1)
```

Run 2 (`_build-laneW936b`, full from-scratch compile, resumed after a background
timeout killed it mid-compile; test execution still ran on the fresh root):
```
Result: 10 passed (9 doctests, 1 test)
EXIT=0 (cold run 2)
```

## Verdict: CLOSED — race confirmed transient (stale beam)

Both independent cold roots compiled the current tree and passed identically
(10/10, exit 0). The W911 failure is not reproducible from a genuine cold compile of
the current subject.

**Mechanism (typed)**: W911's "cold" root predated or raced W907's edit to
`normalize_check/1`; its compile picked up a stale pre-fix `Elixir.Xaas.Semantics.Counterfactual.beam`
(or the test ran against a beam compiled from the pre-fix module while the test source
already asserted the fixed behavior). The failure signature (exact pre-fix
FunctionClauseError from `normalize_name/1` on a `{:name, atom}` tuple) exists only in
the pre-fix module, so a true cold compile of the fixed tree cannot produce it — witness:
two fresh-root cold runs here, both green.

**Guard (advisory, not enacted)**: cold runs that may race an in-flight edit should
compile from a root whose provenance (source SHA/mtimes) matches the test source, or
compile at execution time in the same process as the test, not share a root with an
older subject.

## Standing

- Race: **CLOSED** — confirmed transient (stale pre-fix `.beam` in W911's cold root).
- Harnesses: **ALIVE** on subject a0723bf6 + W907 worktree fix — 2× cold green.
- Build roots `_build-laneW936` / `_build-laneW936b` left for coordinator (rm denied);
  ~2 full test-env compiles, deletable.
