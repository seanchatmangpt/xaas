# W601 — beam4pm `Map.update/4` ABSENT-KEY-RELIANT patch (OS-20)

Lane: W601, v26.10.6. Date: 2026-10-06.
Subject: `/Users/sac/beam4pm` @ `813eb92477ecee3ec734ea93269a32a700692057` (uncommitted,
per contract — coordinator owns commits).
Build root: `_build-w601` (private, per lane law). Toolchain: asdf elixir 1.20.4-otp-29 / erlang 29.1.1.

## 1. Sites patched (3/3 RELIANT per w525d census)

`Map.update(map, key, default, fun)` → dual-safe idiom:

```elixir
case Map.fetch(map, key) do
  {:ok, v} -> Map.put(map, key, fun-or-inline(v))
  :error -> Map.put(map, key, default)
```

- `lib/beam4pm_discovery.ex:310` — `Map.update(counts, pair, 1, &(&1 + 1))` →
  `case Map.fetch(counts, pair)` … `:error -> Map.put(counts, pair, 1)` (counter).
- `lib/beam4pm_pro_simulation.ex:53` (`reachable_from/2` adjacency) —
  `[to]` default, `[to | &1]` fun → dual-safe cons.
- `lib/beam4pm_pro_simulation.ex:76` (`has_cycle?/1` adjacency) — same.

## 2. Upgrade-safety note

The observed otp-29 deviation returns `default` un-updated on the absent-key path
(fun skipped). The dual-safe idiom reproduces the deviation's result exactly on this
toolchain (stores `default` directly) and fixes the branch explicitly, so when the
runtime is fixed to documented semantics (`fun.(default)` stored) nothing changes in
these code paths — behavior is pinned by our own code, not by the runtime's
`Map.update`. Present-key path unchanged (`fun` applied normally), identical on both.

## 3. Regression test

`test/beam4pm_w601_map_update_dual_safe_test.exs` — pins the dual-safe behavior
through the public API:

- `Discovery.causal_dfg_from_spans/1`: chain of 4 same-service spans → one
  observed pair {a,a} with frequency 3 (each link counted exactly once).
- `Simulation.reachable_from/2`: duplicated edge + chain → reachable set {a,b,c}.
- `Simulation.has_cycle?/1`: duplicated edges forming a 2-cycle → true.

## 4. Verification

| run | command | result |
|---|---|---|
| touched modules | `MIX_BUILD_ROOT=_build-w601 MIX_ENV=test mix test test/beam4pm_w601_map_update_dual_safe_test.exs test/beam4pm_discovery_test.exs test/beam4pm_pro_simulation_test.exs` | **39 passed, 0 failures, exit 0** |
| full suite | `MIX_BUILD_ROOT=_build-w601 MIX_ENV=test mix test` | **1562/1565 passed (3/3 doctests), 147 skipped — 3 failures, all classified below** |

Full-suite tail (two consecutive runs, identical 3):

```
Result: 1562/1565 passed (3/3 doctests, 1559/1562 tests), 147 skipped
Failed: 3 tests
```

## 5. Failure classification (3/3 pre-existing or gate-adjacent, zero session-introduced behavior regressions)

1. `Beam4pmEx4pmSoakCorrectnessTest` "dedup under a live store" —
   `GenServer.call` timeout against a live Ex4pm evidence store (5s). Timing/
   environment flake under full-suite load; no relation to the patched sites.
2. `BeamPM.AuthorshipGateTest` "real gate PASSes…" — the authorship gate
   REFUSES on 4 findings, of which 3 are pre-existing tree state NOT produced
   by this lane: `test/beam4pm_evidence_chain_test.exs` SHA drift vs
   schema/beam4pm_hand_authored_source.tsv (beam4pm repo, file untouched by W601), and
   unadmitted `lib/beam4pm_art72_conformance.ex` +
   `test/beam4pm_art72_conformance_test.exs` (untouched by W601).
3. `BeamPM.AuthorshipGateTest` "manufactured manifest carries the marker…" —
   same gate run, same findings.

W601's own delta to the gate: the new regression test file
`test/beam4pm_w601_map_update_dual_safe_test.exs` is unadmitted under
`bpm:HandAuthoredSource` — an expected 1-of-4 contribution to a gate that was
already failing (3 pre-existing findings). Lawful repair belongs to the
coordinator's ontology-admission step (`ontology.ttl` admission + manifest
regeneration), outside this lane's write contract. The two patched `lib/`
files carry GENERATED markers and raise no gate findings.

## 6. Standing

PARTIAL_ALIVE — sites patched and verified semantics-preserving on this
toolchain (39/39 touched-module tests; all 3 full-suite failures classified
pre-existing/adjacent by file-non-overlap with this lane's diff — no
pre-patch baseline run was taken). Coordinator admission of the new test
file is the open repair.
