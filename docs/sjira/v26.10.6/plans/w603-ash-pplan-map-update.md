# W603 — ash_pplan `Map.update/4` absent-key-reliant sweep (OS-20)

Lane W603, v26.10.6 campaign, OS-20 execution, ash_pplan leg. Date: 2026-10-06.
Subject: `/Users/sac/ash_pplan` (canonical checkout, ONE, no worktree; private build
root `_build-laneW603`; **not committed** — coordinator owns transitions).

Basis: w525d census (`w525d-map-update-sweep.md` §3 ash_pplan). Probe confirmed the
pinned runtime (elixir 1.20.4-otp-29 / erlang 29.1.1) deviates on `Map.update/4`'s
absent-key path: `Map.update(%{}, :k, 7, &(&1+1))` → `%{k: 7}` — `default` inserted,
`fun` skipped. Documented semantics store `fun.(default)`. All 8 reliant sites are
"inverted": the deviation currently stores the intended initial accumulator value;
a toolchain fix would silently double-count / duplicate heads at every site.

## 1. Sites patched (8/8) — dual-safe idiom

Idiom (semantics-preserving under both runtime behaviors):

```elixir
case Map.fetch(m, k) do
  :error -> Map.put(m, k, d)          # absent: insert default, fun NOT applied
  {:ok, v} -> Map.put(m, k, f.(v))    # present: fun applied
end
```

| # | site | patch |
|---|---|---|
| 1 | `lib/ash_pplan/state_machine.ex:394` | inner `Map.update` → `case Map.fetch`; absent → `Map.put(state_actions, action, to_states)`; present → `normalize_terms(existing ++ to_states)` |
| 2 | `lib/ash_pplan/compiler.ex:200` | cons onto `[step.iri]` via fetch/put |
| 3 | `lib/ash_pplan/fond.ex:396` | cons onto `[state]` via fetch/put |
| 4 | `lib/ash_pplan/fond/synthesis.ex:166` | extracted `defp upsert_completed/3` (fetch/put cons onto `[action]`) |
| 5 | `lib/ash_pplan/fond/synthesis.ex:227` (edge_index) | cons onto `[{state, action}]` via fetch/put |
| 6 | `lib/ash_pplan/workflow/model.ex:160` | cons onto `[id]` via fetch/put |
| 7 | `lib/ash_pplan/workflow/project/fond.ex:89` | cons onto `[t.id]` via fetch/put |
| 8 | `lib/ash_pplan/reactor/durable/migration.ex:437` | `base_context = record.context \|\| %{}` then fetch/put: absent → `[entry]`; present → `migrations ++ [entry]` |

No site relies on `fun` running on the absent-key path under current runtime behavior
(the deviation made all 8 store `default` verbatim); the idiom preserves exactly that
behavior and additionally makes the present-key path explicit.

## 2. Untouched (contract compliance)

- W291's uncommitted files NOT touched: `lib/ash_pplan/fond/policy_supervisor/offers.ex`,
  `test/support/examples/qualified_fulfillment/ledger.ex`.
- w525d's one SAFE site not patched: `lib/ash_pplan/fond/synthesis.ex:210`
  (`min` idempotent over its own default — `min(a,a)=a`).
- Pre-existing modifications in the tree (runtime_contract/*, docs/demonstration.md,
  docs/sjira/v26.10.6/) are other lanes'/pre-session work; left alone.

## 3. New test

`/Users/sac/ash_pplan/test/map_update_absent_key_test.exs` — pins (a) absent-key
contract of the idiom with a `flunk`-guard proving `fun` never runs, (b) present-key
contract, (c) reduce-accumulation ordering, (d) the migration-site nil-context shape,
(e) a deviation witness that passes on BOTH deviating and fixed runtimes (a toolchain
fix flips the witness branch, forcing re-review instead of silent double-counting).

## 4. Verification (real runs, private build root `_build-laneW603`)

- `mix compile` under pinned toolchain (`PATH=$HOME/.asdf/shims:$PATH`,
  elixir 1.20.4-otp-29 / erlang 29.1.1): exit 0, 152 files compiled clean.
- Narrow gate `mix test test/manufacture_test.exs`: see §6 result line.
- New regression module: see §6 result line.
- Repo suite tail: see §6 result line.

## 5. Upgrade-safety note

On the deviating runtime, all 8 sites today store `default` on first insert — the
intended initial accumulator. Upgrading Elixir to a build with documented
`Map.update/4` semantics would, **unpatched**, flip every site to
`fun.(default)` (duplicated list heads, doubled counts, doubled migration entries)
with no crash. With these patches the behavior is identical under both semantics,
so the upgrade is now silent-safe for ash_pplan. Residual risk lives in the sibling
repos' counts from w525d (beam4pm 3, ash_a2a 14, ex4pm 35 — other legs).

## 6. Result line

`(filled at run completion)`
