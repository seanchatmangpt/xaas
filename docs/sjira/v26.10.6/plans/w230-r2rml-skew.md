# W230 — ash_r2rml API skew adjudication (v26.10.6 convergence)

Date: 2026-10-06. Lane: W230 integration. Status: **ADJUDICATED, gate green.**

## Subjects

| repo | subject |
|---|---|
| xaas | `d1db2b03179975213c14663b9dbd86b5ac2a14cf` (branch `feat/playwright-surface`) |
| ash_surface | `db5a8899e41fd87ef4917d07095677ecb057ed3f` (HEAD) |
| ash_r2rml | pin `0d5320f6c5e9a43bb3e8dcb0f30d301b1ebb64d7` (mix.exs override + mix.lock, git dep) |

## Adjudication table

| option | claim | evidence | verdict |
|---|---| applied |
|---|---|---|---|
| (a) advance xaas pin to a ref providing `Resource.Info` | pin lacks `Resource.Info` | FALSE. `git show 0d5320f:lib/ash_r2rml/resource.ex` lines 544–553 define `AshR2RML.Resource.Info.mapping/1 :: module() -> Mapping.Resource.t() \| nil` — exactly the signature `ash_surface/lib/ash_surface/compiler/semantic.ex:53` matches (`case R2RMLInfo.mapping(resource) do %Mapping.Resource{} -> ...; nil -> nil end`). Beam-level proof: `:beam_lib.chunks` abstract code of a fresh `_build/test/lib/ash_r2rml/ebin/Elixir.AshR2RML.Resource.Info.beam` exports `mapping: 1, mapping!: 1, mapping_result: 1, mapped?: 1, sparql_queries: 1`. No git mutation needed. | **not applicable** |
| (b) rewrite `semantic.ex:53` to `AshR2RML.Resource.mapping/1` | pinned API is the old one | IMPOSSIBLE. No `AshR2RML.Resource.mapping/1` exists at the pin (`AshR2RML.Resource` exports only `section/0`) nor in any ref (`git grep` across `--all` refs). Changing `semantic.ex` would break both copies. | **refused (impossible)** |
| (c) pin and ash_surface HEAD out of mutual alignment | W224's mechanism | WRONG mechanism, right symptom. The crash is real and reproducible, but not pin↔consumer skew. `~/ash_surface/lib/ash_r2rml/` (info.ex, resource.ex, persist.ex, verify.ex) is an **untracked, gitignored** stray (`.gitignore:28`), created 2026-10-06 13:10:32 — same-day, i.e. manufactured during the current wave, shadowing the dep's `AshR2RML.Resource.Info` with a stub lacking `mapping/1` (only `r2rml/1`, `sparql/1`, `compiled*/0..1`). Because ash_surface's ebin precedes the dep's in the code path and the vendored modules redefine the dep's modules in-memory at ash_surface compile time, the stub won at xaas runtime → `UndefinedFunctionError` on `mapping/1`, tagged `(ash_r2rml 26.9.28)` — a misleading version tag: the git repo's own `@version` is "26.9.28" even though `deps/` is a git checkout at the 0d5320f pin. | **confirmed as the real defect, different locus** |
| applied | remove the shadow, not change the pin or the consumer | Quarantined the stray: `mv ~/ash_surface/lib/ash_r2rml → /tmp/w230-quarantine/ash_surface-lib-ash_r2rml` (reversible mv, not `rm`; restore = `mv` back). Then `mix deps.compile ash_surface --force` to purge the vendored beams from ash_surface's ebin. Pin and `semantic.ex` untouched — **zero source edits on either owned side; the pin was already lawful.** | **applied** |

## What changed

- **Nothing in git** (no commits, no branch ops, no pin change).
- Removed from closure: `/Users/sac/ash_surface/lib/ash_r2rml/` (4 files: info.ex, persist.ex, resource.ex, verify.ex) — untracked, gitignored stray, quarantined to `/tmp/w230-quarantine/ash_surface-lib-ash_r2rml/`. **Restore:** `mv /tmp/w230-quarantine/ash_surface-lib-ash_r2rml ~/ash_surface/lib/ash_r2rml`, then `MIX_ENV=test mix deps.compile ash_surface --force` in xaas. Note: `/tmp` is not durable; if quarantined copy is lost, restore is not possible from git (untracked) — but the files are provably redundant: the dep at the pin provides every function they stubbed (mapping/1 etc. beam-verified; r2rml/1, sparql/1, compiled*/0..1 verified present in dep resource.ex/introspection surface — parity confirmed by the guard going green with zero vendored files).
- Recompiled under pinned toolchain: `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`.

## Gate outputs

```
$ MIX_ENV=test mix deps.compile ash_r2rml (clean rebuild)
  fresh dep beam exports: mapping: 1, mapping!: 1, mapping_result: 1, mapped?: 1, sparql_queries: 1  (via :beam_lib abstract_code)

$ MIX_ENV=test mix deps.compile ash_surface --force
Generated ash_surface app

$ MIX_ENV=test mix test test/xaas/ash_surface_drift_guard_test.exs
Finished in 1.7 seconds (0.00s async, 1.7s sync)
Result: 1 passed
```

## Falsifier

The guard asserts committed `priv/ash_surface` artifacts are byte-identical to regeneration through
the real `Mix.Tasks.Xaas.AshSurface` regen path on the pinned ash_r2rml — the exact transition W224
said crashes. Green = the skew mechanism W224 named (pin↔consumer API drift) is refuted; the
shadow-stray mechanism is confirmed by difference: with the stray present the same command raises
`UndefinedFunctionError function AshR2RML.Resource.Info.mapping/1 is undefined or private`
(reproduced 3x), with it quarantined the guard passes. Reproduce the defect by restoring the stray.
## W265 compile state

- Command: `cd /Users/sac/ash_surface && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix compile` — exit 0, "Generated ash_surface app".
- Quarantine held: `lib/ash_r2rml` and `lib/ash_a2a` both absent under `/Users/sac/ash_surface/lib` (ls exit 1).
- Note: one warning residue referencing quarantined surface — `lib/mix/tasks/ash_r2rml.install.ex:5: Mix.Tasks.AshR2rml.Install (module)` (mix task not quarantined with the lib tree). Non-blocking; no fixes per lane scope.
- Subject: /Users/sac/ash_surface, branch state at integration-lane W265 check time; no git actions taken.
