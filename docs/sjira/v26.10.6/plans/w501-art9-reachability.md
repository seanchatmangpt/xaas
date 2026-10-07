# W501 — Art.9 inverse-reachability safe-set compilation (Theorem 3.1)

Lane: W501, wave EU-AI-Act Ch3 Art.9. Subject: `/Users/sac/ferroplan`
(one canonical checkout, no worktrees, no commit). Target dir: `/tmp/w501-target`.

## Mapping to Theorem 3.1

`S_safe = X \ ∪_k Reach⁻ᵏ(S_prohibited)` as a real planner feature.

- `X` = compiled state universe (`successors.len()` / `predecessors.len()`).
- `S_prohibited` = seed set at depth 0 (the planner-side Γ_prohibited analog:
  the same gate role the session-level forbidden-op mask plays, lifted from
  operators to states).
- `∪_k Reach⁻ᵏ(S_prohibited)` = level-by-level predecessor BFS, bounded by
  `max_depth`, with a typed saturation flag distinguishing "frontier
  exhausted" (full closure) from "stopped at the bound".
- `is_safe(s)` = `s ∉ ∪_k Reach⁻ᵏ(S_prohibited)`; out-of-range ids are safe
  (outside the compiled universe).

Surface: `ferroplan::reachability::{BackwardSafeSet, from_successors,
from_predecessors, is_safe, unsafe_count, depth_reached, saturated}`.

## Files

- `~/ferroplan/crates/ferroplan/src/reachability.rs` (new, hand-written;
  irreducible residue — no generator covers the dissertation recursion)
- `~/ferroplan/crates/ferroplan/src/lib.rs` (+1 line: `pub mod reachability;`)

## Verification (real runs, CARGO_TARGET_DIR=/tmp/w501-target)

Narrow gate:

```
cargo test -p ferroplan --lib reachability::tests
test result: ok. 6 passed; 0 failed; 0 ignored; 0 measured; 174 filtered out
```

Anti-vacuity mutant (drop first predecessor edge per state:
`predecessors[p].iter().skip(1)`):

```
test result: FAILED. 2 passed; 4 failed — killed by
  linear_chain_backward_reach, depth_bound_stops_before_full_closure,
  cycle_saturates_without_hang, disconnected_component_stays_safe
(mutant reverted; A/B/witness note lives at NOTE(mutant-anchor) in source)
```

Full gate: `cargo test -p ferroplan` — see tail appended below.

## Full-suite tail

```
$ CARGO_TARGET_DIR=/tmp/w501-target cargo test -p ferroplan 2>&1 | tail -8
   Doc-tests ferroplan
running 1 test
test crates/ferroplan/src/session.rs - session (line 11) - compile ... ok
test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.18s
[exited with code 0]
```

```
$ CARGO_TARGET_DIR=/tmp/w501-target cargo test -p ferroplan --lib 2>&1 | tail -3
test result: ok. 178 passed; 0 failed; 2 ignored; 0 measured; 0 filtered out; finished in 7.94s
```

## Receipt fields

- exact subject: `/Users/sac/ferroplan` @ HEAD (uncommitted lane diff, private
  target dir, no commit made — per lane contract)
- μ/diff: `reachability.rs` new (~210 lines, hand-written irreducible residue);
  `lib.rs` +1 module line. Generated-vs-handwritten: 100% handwritten — no
  ggen/Ash generator covers Rust FOND planner internals.
- standing: PARTIAL_ALIVE → narrow gate ALIVE on this subject; mutation court
  witnessed (mutant killed 4/6 tests); full suite exit 0.
- falsifiers run: narrow reachability gate (pass), skip(1) predecessor-edge
  mutant (killed), full suite (pass, exit 0).

