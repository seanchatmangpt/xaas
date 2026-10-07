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
  elixir 1.20.4-otp-29 / erlang 29.1 post-compile clean; 152 files): exit 0.
- Regression module `mix test test/map_update_absent_key_test.exs`: **5/5 passed, exit 0**.
- Narrow gate `mix test test/manufacture_test.exs`: **9/10**. Sole failure:
  `pack regeneration court: bin/manufacture-workflow` — ExUnit `TimeoutError` at the
  court's hard-coded `@tag timeout: 600_000` (per-test tag; CLI `--timeout` cannot
  lift it). Adjudication: standalone `bin/manufacture-workflow` run with the court's
  exact env (`MANUFACTURE_MANIFEST_ROOT` + private `MIX_BUILD_ROOT`) **exits 0** in
  12:35 wall / 652s user while the box ran at load average ~82 (other campaign
  lanes' suites). The regeneration/byte-identity check itself PASSES (exit 0); the
  failure is the wall-clock cap under multi-lane contention, not a semantic
  regression — the patched sites are pure Map.fetch/put with identical data flow,
  and the script's own compile+verify chain is green. Four court attempts during
  load 73-82 all hit the same 600s cap; the standalone run is direct evidence the
  manufactured output is correct.
- Suite tail `mix test` (full suite, `_build-laneW603`): **killed at the 2h background
  limit** (load average 74-92 throughout; other lanes' suites on the same host). Up to
  the kill, 4 failure classes, none touching the 8 patched sites:
  (1,2) `PackCourtsHarnessCourtTest` ×2 — external drift refusal
  `marketplace HEAD 4bb5fbaf != pinned 6f779318` (marketplace checkout moved vs
  ash_pplan's pin; external repo state, pre-existing);
  (3) `MultiStoreStormTest` — `Task.yield_many` 540s timeout under load-86;
  (4) `StressTest` Await-under-load — `Task.await` 30s timeout under contention.
  Storm/stress timeouts are contention-class; the marketplace-pin refusal is
  external-repo-state class. W291 observed the same killed-at-limit suite behavior on
  its reruns (w291 receipt, runs 2-3).

## 5. Upgrade-safety note

On the deviating runtime, all 8 sites today store `default` on first insert — the
intended initial accumulator. Upgrading Elixir to a build with documented
`Map.update/4` semantics would, **unpatched**, flip every site to
`fun.(default)` (duplicated list heads, doubled counts, doubled migration entries)
with no crash. With these patches the behavior is identical under both semantics,
so the upgrade is now silent-safe for ash_pplan. Residual risk lives in the sibling
repos' counts from w525d (beam4pm 3, ash_a2a 14, ex4pm 35 — other legs).

## 6. Result line

Sites patched: 8/8 (commit `7eeaaa1` — coordinator integrated the lane's working-tree
patches into the wave commit; lane itself made NO commits, per contract). Census after:
only w525d's SAFE site (`fond/synthesis.ex` `min`) retains `Map.update/4`.
Gates: compile exit 0 · regression module 5/5 exit 0 · manufacture_test 9/10 (sole
failure = 600s wall-clock tag on `bin/manufacture-workflow`; script exits 0 standalone
in 12:35 under load-82 — environmental, adjudicated in §4) · suite tail killed at 2h
limit under load 74-92; 4 failures up to kill, all external-drift or contention class
(§4), none referencing the 8 patched sites. Independent re-capture (lane W658e,
2026-10-07, subject 414a393 on `fix/ggen-verify-header`, `_build-laneW658e`): 3 full-suite
attempts (plain, `--trace`, and `--exclude demonstration_court`) all killed at the 2h
background limit under sustained fleet load 27-110 — the suite never reached a summary
line. Partials show ZERO test failures: the `--trace` run executed 1955 tests across
courts/pack_protocol, pack_dsl_smoke, case_study, demonstration, and more with no
failure blocks; the exclusion run cleared burn-in and standing-churn courts with no F
markers before its kill. One contention wedge observed: `DemonstrationCourtTest`'s
nested `bin/demonstrate` chain (~8 min quiet) ran 75+ min past its own 30-min tag under
load 70-90 before completing. Verdict: contention-class non-completion, consistent with
W603's capture; no evidence against the 8 patched sites. W610's quiet-machine rerun
remains the receipt-grade path. Cleanup: `_build-laneW603` (795M) and all
orphaned `_build-court-*` roots deleted (lease law).
