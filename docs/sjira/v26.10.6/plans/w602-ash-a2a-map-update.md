# W602 — ash_a2a `Map.update/4` dual-safe sweep (OS-20, EU-AI-Act wave v26.10.6)

Lane W602. Date 2026-10-06. Subject `/Users/sac/ash_a2a` (canonical checkout, uncommitted).
Build root `_build-laneW602`, toolchain elixir 1.20.4-otp-29 via asdf shims.
Spec: `/Users/sac/xaas/docs/sjira/v26.10.6/plans/w525d-map-update-sweep.md` (census + idiom).

## Idiom applied (w525d §5)

```elixir
case Map.fetch(m, k) do
  :error -> Map.put(m, k, d)          # absent key: store default verbatim, no fun
  {:ok, v} -> Map.put(m, k, f.(v))    # present key: apply fun
end
```

Preserves the currently-observed (deviating) absent-key behavior — the w525d census
classified every reliant site as inverted-risk, i.e. storing `default` unmodified IS the
intended behavior — while being well-defined under both the deviating and documented
toolchain semantics. Present-key path is unchanged (fun applied normally).

## Per-site diff summary (14/14 patched, 9 lib files)

| # | site | pattern |
|---|---|---|
| 1 | `lib/ash_a2a/trace.ex:180` | outer: `:events` → `%{key => [event]}` nested accumulator, rewritten as nested case/fetch/put |
| 2 | `lib/ash_a2a/trace.ex:181` | inner: `[event], &[event \| &1]` cons |
| 3 | `lib/ash_a2a/security/dlp/entropy.ex:26` | byte-frequency counter `1, &(&1+1)` → case/fetch/put |
| 4 | `lib/ash_a2a/chicago/closure/court.ex:331` | caller→`[target]` cons adjacency (`if do:` branch → parenthesized case) |
| 5 | `lib/ash_a2a/a2a_transport/task_events.ex:142` | attempts cons, `Enum.take(.., 100)` cap kept on the present-key path |
| 6 | `lib/ash_a2a/chicago/ocel/log.ex:177` | outer: type→`%{name => kind}` default |
| 7 | `lib/ash_a2a/chicago/ocel/log.ex:178` | inner: kind-widening merge preserved exactly via `{:ok, ^kind} -> kind` / `{:ok, _other} -> "string"` case clauses |
| 8 | `lib/ash_a2a/chicago/ocel/validator.ex:841` | warning counter `%{"count" => 1, ...}` + `%{w \| "count" => w["count"]+1}` |
| 9 | `lib/ash_a2a/chicago/courts/ocel_validity.ex:776` | `[undeclared_attr()]` then `attrs ++ [undeclared_attr()]` |
| 10 | `lib/ash_a2a/chicago/courts/ocel_validity.ex:788` | `[attr]` then `attrs ++ [attr]` |
| 11 | `lib/ash_a2a/protocol/agent/state.ex:138` | `ctx_id → [task_id]` cons |
| 12 | `lib/ash_a2a/spiffe/workload_watcher.ex:337` | field-1 `[value]` cons |
| 13 | `lib/ash_a2a/spiffe/workload_watcher.ex:340` | field-3 `[value]` cons |
| 14 | `lib/ash_a2a/spiffe/workload_watcher.ex:379` | `:chain` `[value]` cons |

Untouched (w525d-classified SAFE, fun idempotent over default): `chicago/closure/court.ex:352`,
`chicago/observer/journal.ex:207`, `runtime_identity/execution.ex:285`,
`telemetry/allocation_counters.ex:136`, `c2/memory_claim_store.ex:21`.

## Regression test

New module `test/ash_a2a/dual_safe_map_update_test.exs` (12 tests): pins the cons and
counter accumulator patterns (absent key stores default verbatim, present key folds and
caps correctly), runs `Entropy.shannon_bits_per_char` end-to-end, and includes a
repo-wide guard test that re-scans `lib/` for `Map.update(` and asserts only the five
w525d-SAFE sites remain — reintroducing a reliant site fails the suite.

## Verification

- Toolchain: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW602 mix test`.
- New module: 12/12 passed (`mix test test/ash_a2a/dual_safe_map_update_test.exs`).
- Full suite (real run, exit 0):

```
Result: 3720 passed (113 doctests, 51 properties, 3556 tests), 1 skipped, 1032 excluded
[exited with code 0]
```

Prior green was ~3706 pass; 3720 = prior suite + the 12 new guard tests, 0 failures —
the patch changed no observable behavior on this toolchain (expected: all rewrites are
behavior-preserving under the deviating semantics by construction).

## Upgrade-safety note

The pinned runtime (elixir 1.20.4-otp-29) deviates from documented `Map.update/4`
semantics on the absent-key path (inserts `default` without calling `fun`; probe
`Map.update(%{}, :k, 7, &(&1+1))` → `%{k: 7}`). All 14 former reliant sites now use the
explicit fetch/put form, whose behavior is identical under BOTH semantics — an Elixir
upgrade can no longer flip these sites to silent double-counting. The five SAFE sites
remain on `Map.update/4` by design (idempotent over their defaults under both
semantics). The guard test fails the suite if any new reliant `Map.update` site is
introduced into `lib/`.

## Suite tail (filled at close)

```
Result: 3720 passed (113 doctests, 51 properties, 3556 tests), 1 skipped, 1032 excluded
```

Standing: OS-20 ash_a2a leg — 14/14 reliant sites patched, ALIVE (suite witnessed on
exact working tree, uncommitted per lane contract; coordinator owns the commit).
