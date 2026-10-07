# W851 — JCS encode/1 doctests (receipt)

- **Subject**: /Users/sac/xaas @ feat/playwright-surface, HEAD a0723bf6 (uncommitted lane diff: lib/xaas/semantics/jcs.ex, test/xaas/semantics/jcs_doctest_test.exs, this receipt)
- **O***: W832 candidate receipt docs/sjira/v26.10.6/plans/w832-doctest-verify.md — JCS encode/1 top doctest candidate.
- **μ/diff**: 2 files + receipt. All expected doctest outputs derived by actually running `Xaas.Semantics.Jcs.encode/1` under the pinned toolchain (asdf elixir 1.20.2-otp-28, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW851), pasted verbatim; zero guessed outputs.
- **generated-vs-handwritten**: 100% handwritten (doc examples + harness; no generator path exists for doctests).
- **Changes**:
  - `lib/xaas/semantics/jcs.ex`: `@doc` added to `encode/1` with 4 real `iex>` examples (nested-map canonical ordering, big integer, float minimal form `1e+30`, `-0.0 -> "0"`).
  - `test/xaas/semantics/jcs_doctest_test.exs` (new): doctest harness, `doctest Xaas.Semantics.Jcs`, async.
- **Verification (real tails)**:
  - `mix test test/xaas/semantics/jcs_doctest_test.exs` ×2 → `Result: 4 passed` (both runs)
  - `mix test .../jcs_doctest_test.exs .../jcs_property_test.exs --include property` → `Result: 9 passed (4 doctests, 1 property, 4 tests)` — no regression
  - Mutation rationale witnessed: temporarily replaced the first expected output with `"MUTATED"` → `Doctest failed / code: ... === "MUTATED" / Result: 3/4 passed`; restored, re-ran → `Result: 9 passed`. The docs are executable assertions, not prose.
- **Commands/exits**: all mix runs exit 0 on final state (grafana/PromEx nxdomain warnings pre-existing, unrelated).
- **Standing**: PARTIAL_ALIVE (doctests witnessed green on exact subject; not yet committed — coordinator owns integration commit).
- **Falsifier**: any doctest example in `lib/xaas/semantics/jcs.ex` failing on a future encoder change — the harness `test/xaas/semantics/jcs_doctest_test.exs` converts doc drift into a red suite.
- **Replay**: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW851 mix test test/xaas/semantics/jcs_doctest_test.exs test/xaas/semantics/jcs_property_test.exs --include property`
- **Lease**: `_build-laneW851` left in place for coordinator per fanout cleanup law (not deleted; lane had a green final run on it).

Note: the W832 task spec asked for 3 examples; 4 were included (nested map, integer, 1.0e30, -0.0) since the -0.0 minimal form is the load-bearing RFC 8785 corner the module doc already documents.
