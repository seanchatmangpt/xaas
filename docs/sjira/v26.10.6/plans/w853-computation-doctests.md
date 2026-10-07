# W853 — Computation hash doctests (from W832 candidates)

- **Repo**: /Users/sac/xaas, branch `feat/playwright-surface`, HEAD `a0723bf6`
- **Lane**: W853, `MIX_BUILD_ROOT=_build-laneW853` (deleted at end of lane)
- **Scope honored**: only `lib/xaas/semantics/computation.ex` (@doc blocks only) + new `test/xaas/semantics/computation_doctest_test.exs` + this receipt. No commit (as directed).
- **Standing**: PARTIAL_ALIVE (verified on this lane's exact diff; uncommitted by directive)

## What landed

One doctest per hash function flagged by W832 (all four, none skipped — every
input is a small literal map/struct construction):

| W832 line | Function | Doctest input |
|---|---|---|
| 66 | `Xaas.Semantics.ComputationArtifact.hash/1` | literal artifact map (schema.org IRI, runtime NX, deterministic true) |
| 91 | `Xaas.Semantics.ComputationHash.hash/1` | `%{a: 1, b: :x}` |
| 186 | `Xaas.Semantics.ComputationClaim.hash/1` | claim over the same literal artifact, value 0.5, evidence_class GENERATED |
| 289 | `Xaas.Semantics.PlanningAdvice.hash/1` | advice over the same artifact, kind FRONTIER, candidates c1/c2 |

## Provenance of expected outputs (never guessed)

All four hashes were produced by actually running the functions before writing
any @doc (`mix run -e`, test env, pinned asdf toolchain, lane build root),
then pasted verbatim into the @doc blocks:

- artifact: `14c69125e2dd6a21ed2376cf9008af551aee0706de94ab02999597f14f26b0d7`
- plain:    `2bd10397da30531af1cd6a14cf90c58ffdf61440c288ff409db3f616cb1e5b7d`
- claim:    `c252f6a5ddc64f23c4e34f37e180b2a8fca996c76b25547fbf46f430cb461f6c`
- advice:   `488187d431e24e42ca4066f2703b109bdf5f0fbd52b8f5f7900e45bbdc122b52`

## Commands / exits

```
mix run -e (hash probes)                                        exit 0
mix test test/xaas/semantics/computation_doctest_test.exs  #1   4 passed
mix test test/xaas/semantics/computation_doctest_test.exs  #2   4 passed
mix test test/xaas/sa2a_computation_boundary_test.exs           21 passed
mutation run (below)                                            1 failure, exactly the mutated doctest
```

All under `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW853`.

## Mutation rationale (falsifier run, witnessed)

Corrupted the ComputationArtifact.hash expected output: leading `1`→`0` in
`14c69125...`. Real failure tail:

```
1) doctest Xaas.Semantics.ComputationArtifact.hash/1 (1) (Xaas.Semantics.ComputationDoctestTest)
   test/xaas/semantics/computation_doctest_test.exs:9
   Doctest failed
```

Exactly one failure, naming the mutated doctest only; the other three doctests
still passed. Restored the correct hash; re-run green (4 passed). Proves the
doctests are non-vacuous: a corrupted expected value is caught, and the
failure is localized to exactly the doctest it lives in.

## Falsifier

A doctest would be vacuous if a corrupted expected output still passed —
refuted by the witnessed mutation run above.

## Cleanup (coordinator check)

```
rm -rf /Users/sac/xaas/_build-laneW853
```
