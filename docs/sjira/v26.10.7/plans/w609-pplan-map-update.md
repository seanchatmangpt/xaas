# W609 — ash_pplan Map.update sweep (WP-4, OS-20, quartet closer)

Status: ALIVE
Subject: /Users/sac/ash_pplan @ 6dbd3b0 (main, ff-pulled; W601p seal commit 6dbd3b0 head)
Toolchain: elixir 1.20.4-otp-29 / OTP 29.1.1 (repo .tool-versions, ggen-pinned)
Build roots: `_build-laneW609`, `_build-laneW609b` (lane leases)

## Grounding probe (runtime, exact subject)

`elixir -e` under the pinned shims, elixir 1.20.4 / OTP 29:

    absent_small:  Map.update(%{}, :k, 1, &(&1+10))  -> %{k: 1}    # fun NOT applied (deviation)
    present_small: Map.update(%{k: 5}, :k, 1, &(&1+10)) -> %{k: 15} # normal
    absent_bigmap: Map.update(<42-key map>, 99, 7, &(&1+10))[99] -> 7   # fun NOT applied
    present_bigmap: ...[5] -> 13                                        # normal
    bang_absent:   Map.update!(%{}, :k, &(&1+1)) -> KeyError         # bang unaffected by deviation

Deviation confirmed live on the current pinned toolchain: `Map.update/4` absent-key
path inserts `default` without applying `fun` (small AND large maps; present-key
path normal; `Map.update!/3` raises KeyError as documented).

## Census (grep -rn "Map.update" lib/, skips deps)

6 residual sites, all classified per the W606 rubric:

| # | site | form | class | disposition |
|---|------|------|-------|-------------|
| 1 | fond/synthesis.ex:217 | `Map.update(acc, state, action, &min(&1, action))` | (b) — invariant: `fun.(default) == default` (`min(a,a)==a`) under BOTH semantics | leave + disclose |
| 2 | state_machine.ex:393 | `Map.update!(relation, from_state, ...)` | bang — no default; absent key raises KeyError under both semantics (probe) | leave |
| 3 | fond/provider_registry.ex:38 | `Map.update!(:capabilities, ...)` | bang; key guaranteed present by `Map.put_new(:capabilities, ...)` immediately before | leave |
| 4 | fond/provider_registry.ex:80 | `Map.update!(providers, id, ...)` | bang; guarded by `Map.has_key?` check | leave |
| 5 | reactor/durable/store/ets.ex:336 | `Map.update!(:version, ...)` | bang; `:version` structurally present in `AshPPlan.Reactor.Durable.Record` | leave |
| 6 | reactor/durable/store/dets.ex:526 | `Map.update!(:version, ...)` | bang; `:version` structurally present | leave |

Note: the census test in the court re-derives the grep on every run and fails if
any lib/ `Map.update` hit is not in the classified table.

## What 7eeaaa1 already covered

7eeaaa1 ("OS-20 dual-safe Map.update … (w603)") converted 8 absent-key-critical
lib sites to the dual-safe `case Map.fetch` idiom (site count per its commit
message; the diff touches 13 lib files, some files carrying >1 site — compiler,
fond, synthesis ×2, migration, the 5 runtime_contract modules, state_machine,
workflow/model, workflow/project/fond).

The w525d census doc is the site-level authority
(~/ash_pplan/docs/sjira/v26.10.6/plans/w525d-map-update-sweep.md, not re-opened
this session — see Tails). After 7eeaaa1, the residual non-bang
`Map.update/4` population in lib/ is exactly one site (synthesis.ex:217), which
is the W609 finding above.

## Court

`test/map_update_w609_residual_court_test.exs` (new, uncommitted, lane-written):

- parameterized over 6 residual sites ({module, file:line, invariant} table),
- census self-check: re-greps lib/ and refuses unclassified residuals,
- class-(b) invariance witness for synthesis.ex:217 under both semantics,
- bang-form KeyError witness + ProviderRegistry put/observe_health behavior pins,
- ETS durable-store version-bump pin (start_run → version ≥ 1),
- fresh deviation witness re-derived each run (flips on a toolchain fix).

## Gates (real output)

- `git pull --ff-only` → "Already up to date." (head 6dbd3b0)
- strict compile `MIX_BUILD_ROOT=_build-laneW609 MIX_ENV=test mix compile --force`
  → exit 0, **0 warnings** (grep -ci warning on full output = 0), 264 files
- court + w603 pin, root #1: `mix test court w603` → **12 passed, 0 failures, 0 warnings**
- second fresh root `_build-laneW609b`: `mix compile --force` exit 0 →
  court + w603 pin → **12 passed, 0 failures** (fresh root #2)
- affected-module tests (state_machine, state_machine_hardening, store_ets,
  store_dets, fond corpus), lane root #1: **74 passed, 0 failures**, exit 0

## Tails

- w525d census doc not re-opened; 7eeaaa1 site-level count (8) taken from commit
  message, file-level (13) from `git show --stat`.
- synthesis.ex:217 is the one residual `Map.update/4` in the quartet; provably
  invariant today, but any future change to its `fun` breaks the invariance —
  the court's census test will keep it classified and the class-(b) witness pins
  current behavior, not the invariant claim.
- DETS court row pins exist via the shared Record/put_run shape; dets.ex:526
  exercised through the ets/dets conformance tests, not a dedicated dets run in
  the court (ets pin only).
- Lane build roots `_build-laneW609{,b}` left in place at seal time (lane leases).

## Standing

**ALIVE.** Court ×2 fresh roots green (12/12 each) + affected tests green
(74/74) + strict compile 0 warnings, both roots. WP-4/OS-20 quartet closer:
ash_pplan carries zero unclassified residual `Map.update` sites in lib/ —
7eeaaa1 covered all class-(a) sites; the sole residual `Map.update/4`
(synthesis.ex:217) is provably semantics-invariant and pinned by court.
