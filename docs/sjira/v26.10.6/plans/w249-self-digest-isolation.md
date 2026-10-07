# W249 — self_digest test isolation fix (v26.10.6 convergence, integration lane)

Date: 2026-10-06 · Repo: /Users/sac/xaas · Branch: feat/playwright-surface

## Subject

- Owned file: `test/mix/tasks/xaas_self_digest_test.exs` (only file touched)
- Symptom (W228): "prints the JSON receipt..." passes in isolation, fails under
  `mix test test/mix` with `frontier_episodes 0 vs 3` (order-dependent).

## Root cause (observed, not inferred)

`Xaas.Ultracode.CapitalCensus.SelfDigest.Run.episodes/1` maps each telemetry
line through `outcome_atom/1` → `String.to_existing_atom(name)`. The atom
`:worker_unclosed` only exists once the Ash enum type module
`Xaas.Ultracode.CapitalCensus.Types.FrontierOutcome`
(`lib/xaas/ultracode/capital_census/types/frontier_outcome.ex` —
`values: [:blocked, :dispatch_refused, :worker_unclosed, :handed_off, :refused, :error]`)
has been loaded in the VM. Under load orders where the test runs before
anything touches that type module, `String.to_existing_atom("worker_unclosed")`
raises `ArgumentError`, `outcome_atom/1` rescues to `{:error, :unknown_outcome}`,
and `episodes/1` drops every fixture line → 0 episodes → 0 frontier episodes.
Not a file/truncation interaction — an atom-universe load-order dependency.

Reproduced deterministically: `mix test test/mix --seed 0` (no fix) →
`assert summary["frontier_episodes"] == 3` failed with left: 0.

## Fix (test-side self-sufficiency, lib untouched)

The fixture now mints the outcome strings from literal atoms
(`Atom.to_string(:worker_unclosed)`, `Atom.to_string(:blocked)`). The test
module's own compile-time atom references guarantee the atoms exist in the VM
before the task's `String.to_existing_atom/1` runs, independent of any other
test's load order. Assertion strictness unchanged (still `== 3`, real content).
No mocking; real task, real fixture file, sandboxed Postgres (Chicago).

## Verification (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/mix/tasks/xaas_self_digest_test.exs`
  → `Result: 3 passed`
- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/mix --seed 0`
  (the previously failing order) → `Result: 48 passed, 1 skipped, 15 excluded`
- Default-seed dir run pre-fix had also passed (48 passed) — seed 0 was the
  discriminating falsifier and now passes.

## Standing

ALIVE (exact subject: working tree, test file at current edit; both
invocations observed passing). Boundary: other seeds not exhaustively swept;
the discriminating failing order is covered. No lib edits, no git actions.

## W287 seed-1

Post-W249 mix dir verify on seed 1 (non-discriminating; confirms no
regression in the previously passing orders):

```
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/mix --seed 1
→ Result: 48 passed, 1 skipped, 15 excluded
```

Matches target (48 passed, 1 skipped, 0 failed). Real output, W287,
v26.10.6 convergence lane.
