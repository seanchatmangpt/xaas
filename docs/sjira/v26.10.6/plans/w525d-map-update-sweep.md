# W525d — `Map.update/4` absent-key deviation sweep (otp-29 repos)

Lane: W525d, EU-AI-Act wave v26.10.6. Date: 2026-10-06.
Subject: `/Users/sac/beam4pm`, `/Users/sac/ash_a2a`, `/Users/sac/ash_pplan`, `/Users/sac/ex4pm`
(canonical checkouts, read-only except this file).

## 1. Probe — deviation confirmed in all 4 repos

```elixir
Map.update(%{}, :k, 7, &(&1+1))   # documented → %{k: 8}; actual → %{k: 7}
```

All four repos pin `elixir 1.20.4-otp-29 / erlang 29.1.1` (`.tool-versions`). Probe run in
each repo directory under that toolchain (asdf shims on PATH), real `elixir -e` runs:

| repo | probe output |
|---|---|
| beam4pm | `%{k: 7}` |
| ash_a2a | `%{k: 7}` |
| ash_pplan | `%{k: 7}` |
| ex4pm | `%{k: 7}` |

On this runtime the function returns the map with `default` inserted **without** calling
`fun`. Documented Elixir semantics: insert `default`, then store `fun.(default)`. The
present-key path is unchanged (fun applied normally). Fun is skipped, not mis-applied.

## 2. Classification rule

- **ABSENT-KEY-RELIANT (R)**: key plausibly absent (typical: reducer seeding from `%{}`)
  AND `fun.(default) != default` → skipping fun changes the stored value.
- **SAFE (S)**: `fun.(default) == default` (fun idempotent over the default: `min/max`
  whose default equals the folded value, `MapSet.put`/`Map.put` re-inserting the
  default's own element), or the key is provably present (map pre-seeded with every key).

## 3. Per-repo census

### beam4pm — 5 sites, 3 RELIANT

| site | default / fun | verdict |
|---|---|---|
| `lib/beam4pm_discovery.ex:310` | `1, &(&1+1)` | **R** — absent-key counter stores 1 (deviation); documented stores 2 on first insert. Inverted: deviation matches intended first-occurrence count. |
| `lib/beam4pm_pro_simulation.ex:53` | `[to], &[to \| &1]` | **R (inverted)** — deviation stores `[to]`; documented `[to, to]`. |
| `lib/beam4pm_pro_simulation.ex:76` | `[to], &[to \| &1]` | **R (inverted)** — same. |
| `lib/beam4pm_revenue_metering.ex:288` | `candidate, &better_last(&1, candidate)` | S — `better_last(candidate, candidate) = candidate = default`. |
| `lib/beam4pm_claude_workflow_reactor.ex:224` | `e.line, &max(&1, e.line)` | S — `max(x, x) = x`. |

Note: w511's already-fixed module is not locatable in beam4pm history
(`git log --all --grep` for w511 / map.update → only unrelated commit 04a34363, whose
message mentions `ets.update_counter`, not `Map.update`). Census covers all current `lib/` sites.

### ash_a2a — 19 sites, 14 RELIANT

Reliant (14) — all inverted (deviation stores the intended initial accumulator value;
documented semantics would double-insert):

| site | default / fun |
|---|---|
| `lib/ash_a2a/trace.ex:180` | `%{key => [event]}, inner Map.update` — documented would apply the inner fun to the freshly built default, re-inserting `event`. |
| `lib/ash_a2a/trace.ex:181` | `[event], &[event \| &1]` |
| `lib/ash_a2a/a2a_transport/task_events.ex:142` | `[attempt], &Enum.take([attempt \| &1], 100)` |
| `lib/ash_a2a/security/dlp/entropy.ex:26` | `1, &(&1+1)` — first occurrence of a byte stores count 1 (correct); documented stores 2. |
| `lib/ash_a2a/chicago/closure/court.ex:331` | `[target], &[target \| &1]` |
| `lib/ash_a2a/chicago/ocel/log.ex:177` | `%{name => kind}, merge-fun` — documented would merge kind with itself. |
| `lib/ash_a2a/chicago/ocel/log.ex:178` | `kind, merge-fn` |
| `lib/ash_a2a/chicago/ocel/validator.ex:841` | `%{"count" => 1, ...}, %{"count" + 1}` — deviation stores count 1 (correct first count). |
| `lib/ash_a2a/chicago/courts/ocel_validity.ex:776` | `[undeclared_attr()], &(&1 ++ [attr])` |
| `lib/ash_a2a/chicago/courts/ocel_validity.ex:788` | `[attr], &(&1 ++ [attr])` |
| `lib/ash_a2a/protocol/agent/state.ex:138` | `[task_id], &[task_id \| &1]` |
| `lib/ash_a2a/spiffe/workload_watcher.ex:337` | `[value], &[value \| &1]` |
| `lib/ash_a2a/spiffe/workload_watcher.ex:340` | `[value], &[value \| &1]` |
| `lib/ash_a2a/spiffe/workload_watcher.ex:379` | `[value], &[value \| &1]` |

Safe (5):

| site | reasoning |
|---|---|
| `lib/ash_a2a/chicago/closure/court.ex:352` | `MapSet.new([from])` + `&MapSet.put(&1, from)` — `fun.(default) = default`. |
| `lib/ash_a2a/chicago/observer/journal.ex:207` | `total, &max(&1, total)` — `max(x,x)=x`. |
| `lib/ash_a2a/runtime_identity/execution.ex:285` | `{pid, mem}, max` — idempotent over default. |
| `lib/ash_a2a/telemetry/allocation_counters.ex:136` | `%{resolver => count}` + `&Map.put(&1, resolver, count)` — re-puts the default's own pair. |
| `lib/ash_a2a/c2/memory_claim_store.ex:21` | `{0, {:completed, r}}` with fun returning the same shape → `fun.(default) = default`. |

### ash_pplan — 9 sites, 8 RELIANT

Reliant (8), all inverted:

| site | default / fun |
|---|---|
| `lib/ash_pplan/state_machine.ex:394` | `to_states, &normalize_terms(existing ++ to_states)` — documented would normalize `to_states ++ to_states`. |
| `lib/ash_pplan/compiler.ex:200` | `[step.iri], &[iri \| &1]` |
| `lib/ash_pplan/fond.ex:396` | `[state], &[state \| &1]` |
| `lib/ash_pplan/fond/synthesis.ex:166` | `[action], &[action \| &1]` |
| `lib/ash_pplan/fond/synthesis.ex:227` | `[{state, action}], &[{state, action} \| &1]` |
| `lib/ash_pplan/workflow/model.ex:160` | `[id], &[id \| &1]` |
| `lib/ash_pplan/workflow/project/fond.ex:89` | `[t.id], &[t.id \| &1]` |
| `lib/ash_pplan/reactor/durable/migration.ex:437` | `[entry], &(&1 ++ [entry])` |

Safe (1): `lib/ash_pplan/fond/synthesis.ex:210` — `action, &min(&1, action)` → `min(a,a)=a`.

### ex4pm — 43 sites, 35 RELIANT

Reliant (35):

- `lib/ex4pm_engine/workflow_net.ex`: 156, 165, 256, 265, 408, 573, 578, 612, 826, 833 (counters + cons adjacency)
- `lib/ex4pm_engine/bench/topology.ex:127` — counter
- `lib/ex4pm/aloop.ex:133` — cons
- `lib/ex4pm/gall.ex:1247, 1271` — cons adjacency
- `lib/ex4pm/information/registry.ex:487` — `nil, &inspect/1`; `fun.(nil) ≠ nil`. Low impact (public-schema metadata only).
- `lib/ex4pm/explore/markov.ex:6` — `count, &(&1+count)`; inverted (deviation stores count — correct).
- `lib/ex4pm/explore/object_event.ex:7` — `[event], &(&1 ++ [event])`
- `lib/ex4pm/runtime/powl_executor.ex:110` — `1, &(&1+1)`
- `lib/ex4pm/explore/vector_clock.ex:3` — `1, &(&1+1)`
- `lib/ex4pm/engine/online_miner.ex:206, 217, 226, 260, 334` — counters / per-edge stats (`:226` = `%{count: 1, total_ms: d, min_ms: d, max_ms: d}` with incrementing fun)
- `lib/ex4pm/engine/discovery/incremental.ex:62, 68, 79, 100` — counters
- `lib/ex4pm/engine/discovery/inductive_miner.ex:78, 299, 303, 327` — counters/cons; `:327` is `0, &(&1-1)` (deviation stores 0, documented −1 — both suspicious)
- `lib/ex4pm_core/process_ir.ex:734` — counter
- `lib/ex4pm_core/process_ir.ex:757` — `0, &(&1-1)` decrement
- `lib/ex4pm_core/capsule_graph/independence/provenance.ex:7` — cons

Safe (8):

- `lib/ex4pm/gall.ex:1418` — `sequence, &min(&1, sequence)` — `min(x,x)=x`
- `lib/ex4pm/explore/topology_refusal.ex:4` — map pre-seeded with every node via `Map.new(nodes, &{&1, 0})` → key always present
- `lib/ex4pm/runtime/powl_executor.ex:104` — `0, &max(&1-1, 0)` → `fun.(0)=0=default`
- `lib/ex4pm/explore/floyd_warshall.ex:5, 15` — `min` idempotent over its own default
- `lib/ex4pm/engine/discovery/inductive_miner.ex:167, 168, 223` — `MapSet.new([x])` + `&MapSet.put(&1, x)` → `fun.(default)=default`

## 4. Severity

- Reliant-site counts: beam4pm **3**, ash_a2a **14**, ash_pplan **8**, ex4pm **35** — total **60**.
- **Every one of the 60 sites is inverted relative to the harm direction**: the buggy
  runtime stores `default` (the intended initial accumulator value), while documented
  semantics would store `fun.(default)` — a duplicate element / double count on first
  insert. There is no live silent corruption today; the risk flips on a toolchain fix.
- Severity: HIGH as an **upgrade blocker**. Upgrading Elixir to a build where `Map.update/4`
  follows documented semantics silently corrupts all 60 sites (duplicated heads, double
  counts, doubled migration entries) with no crash.
- Notable odd sites: `inductive_miner.ex:327` and `process_ir.ex:757` use `0, &(&1-1)` —
  under documented semantics an absent key would go to −1; the deviation currently stores 0.
  These two are suspect under BOTH behaviors and deserve independent review.

## 5. Recommended fix — patch call sites, not the toolchain

Replacing `Map.update(m, k, d, f)` at reliant sites with the explicit form is
semantics-preserving under both toolchain behaviors:

Correct dual-safe idiom:

```elixir
case Map.fetch(m, k) do
  :error -> Map.put(m, k, d)          # insert default, do NOT apply fun
  {:ok, v} -> Map.put(m, k, f.(v))    # present key: apply fun
end
```

This is mechanical across 60 sites and can be generated (ggen pack / Igniter transformer).
Patching beats upgrading-first: an upgrade without these patches flips all 60 sites to
silent double-counting at once.

## 6. Verification receipt

- Probes: real `elixir -e` runs from each repo directory under its pinned toolchain
  (asdf shims on PATH); all four output `%{k: 7}`.
- Census: `grep -rn "Map\.update(" <repo>/lib` per repo (exact-literal lookup; `_build`
  and `deps` excluded). All sites classified by reading the multi-line ones
  (validator.ex:841, ocel_validity.ex:776, real_transport.ex:532, online_miner.ex:226,
  state_machine.ex:394, registry.ex:487, trace.ex:180-181) directly.
- Corrections to classification intent: `ex4pm_engine/wasm/real_transport.ex:532` and
  `inductive_miner.ex:167/168/223` are SAFE (fun re-inserts the default's own content).
- No writes to any of the 4 repos. Only this file was written.
