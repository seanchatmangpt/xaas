# W604 — ex4pm `Map.update/4` absent-key-reliant sweep (OS-20 / ex4pm leg)

Lane W604, v26.10.6 campaign, 2026-10-06. Subject: `/Users/sac/ex4pm` (canonical checkout,
NOT committed — lane contract). Build root: `_build-laneW604`, toolchain asdf
`elixir 1.20.4-otp-29 / erlang 29.1.1` (repo `.tool-versions`).

Census source: `w525d-map-update-sweep.md` §3 (ex4pm: 43 sites, 35 RELIANT).

## 1. What was executed

All 35 RELIANT sites in `lib/` patched with the w525d dual-safe idiom:

```elixir
case Map.fetch(m, k) do
  :error -> Map.put(m, k, default)      # absent: store default, do NOT apply fun
  {:ok, v} -> Map.put(m, k, fun.(v))    # present: apply fun
end
```

This preserves the OBSERVED runtime behavior under BOTH toolchain behaviors
(current runtime skips fun on absent keys; documented semantics would apply it).

## 2. Per-site diff summary

**Counters (`1, &(&1+1)` family) — 21 sites, mechanical idiom swap:**

| site | form |
|---|---|
| `lib/ex4pm_engine/bench/topology.ex:127` | `d = Map.update(d, {a,b}, 1, &(&1+1))` → assignment case |
| `lib/ex4pm_engine/workflow_net.ex` 156/165/826/833 | counter (826/833 as paren-wrapped `do:` keyword case) |
| `lib/ex4pm/runtime/powl_executor.ex:110` | counter |
| `lib/ex4pm/explore/vector_clock.ex:3` | one-line `def tick/2, do:` → multi-clause `def do/end` |
| `lib/ex4pm/engine/online_miner.ex` 206/217/260/334 | counters |
| `lib/ex4pm/engine/discovery/incremental.ex` 62/68/79/100 | counters |
| `lib/ex4pm_core/process_ir.ex:734` | indegree counter in `check_dag` |

**Cons sites (`[x], &[x \| &1]`) — 9 sites:**

- `lib/ex4pm/aloop.ex:133`, `lib/ex4pm/gall.ex` 1247/1271, `lib/ex4pm_engine/workflow_net.ex` 578/612, `lib/ex4pm_core/capsule_graph/independence/provenance.ex:7` — cons idiom (`:error -> [x]`, `{:ok, l} -> [x | l]`).
- `lib/ex4pm_engine/workflow_net.ex` 256/265 — nested-map `Map.put` idiom (`{:ok, m} -> Map.put(m, s, w)`).
- `lib/ex4pm/explore/object_event.ex:7` — append-at-END idiom (`{:ok, l} -> l ++ [event]`).
- `lib/ex4pm/explore/markov.ex:6` — `count, &(&1+count)` idiom.

**Multi-line block — 1 site:**
- `lib/ex44pm_engine/engine/online_miner.ex:226` — per-edge stats map; absent → `%{count: 1, total_ms: d, min_ms: d, max_ms: d}`, present → incremented stats map.

**SUSPECT sites — 2, analyzed and pinned (not blind-patched):**

Both use `0, &(&1-1)` in Kahn-style topological sorts. Analysis: in both, the degree map
is pre-seeded with EVERY node before the sort consumes it
(`inductive_miner.ex:~300` pre-seeds `0..n-1`; `process_ir.ex` pre-seeds `node_set`),
so the key is always present in practice and the absent branch is dead code under both
runtime behaviors. -1 is never meaningful (degrees stay ≥ 0 for valid DAGs; a −1 degree
would never match the `degree == 0` selection). Patch preserves observed behavior
(absent → 0) with explicit comments at both sites.

- `lib/ex4pm/engine/discovery/inductive_miner.ex:~336` — `do_kahn/4` decrement; reached via
  sequence-cut detection in `mine/1`.
- `lib/ex4pm_core/process_ir.ex:~757` — `consume_dag/3` decrement; reached via
  `Ex4pmCore.ProcessIR.new/1` partial-order DAG check.

## 3. Regression test

`/Users/sac/ex4pm/test/w604_map_update_dual_safe_test.exs` — 8 tests:
runtime canary (`Map.update(%{}, :k, 7, &(&1+1)) == %{k: 7}` — fails loudly if the
toolchain deviation is ever fixed, flagging re-review), VectorClock/ObjectEvent/Markov/
DFG idiom pins, and the two suspect pins via public entry points:
`InductiveMiner.mine([["a","b","c"]])` (kahn ordering a→b→c) and
`ProcessIR.new` acyclic-OK / cyclic-refused / shared-successor diamond DAG.

## 4. Verification

- `mix compile` (MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW604): clean; only pre-existing
  warnings in unpatched files (ocel.ex, exposure_court.ex).
- New regression tests: 8/8 pass.
- Full suite: see §5.

## 5. Suite tail

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW604 mix test
# exit 0
Result: 896 passed (2 doctests, 5 properties, 889 tests), 6 skipped, 60 excluded
```

Baseline prior green was 888/0-era; 888 + 8 new W604 tests = 896 passed, 0 failures.
Standing: ALIVE (exact subject /Users/sac/ex4pm working tree, uncommitted per lane contract).
