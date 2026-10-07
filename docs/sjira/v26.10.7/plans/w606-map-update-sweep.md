# W606 — Map.update absent-key sweep (WP-4 / OS-20)

Lane W606, v26.10.7 campaign. Repo `/Users/sac/xaas`, branch
`feat/playwright-surface` (shared checkout, no commit per directive).

## Runtime probe (grounding)

Directive said `Map.update/4`; verified: **Elixir's `Map.update` arity is 4**
(`Map.update(map, key, default, fun)`); `:maps.update/3` is the BEAM-side
function. Directive's `/4` was correct; the memory's "/4" and "arity is 3"
suspicion resolved in favor of /4.

Probe (2026-10-07, Elixir 1.20.2 / OTP 28 pinned, run twice via `mix run -e`
under the pinned asdf toolchain):

```
Map.update(%{}, :k, 0, fn v -> v + 1 end)  => %{k: 0}   # absent key: default seeded, fun NOT called
Map.update(%{k: 5}, :k, 0, fn v -> v + 1 end) => %{k: 6} # present key: fun applied
```

No skip on the pinned runtime. **Hazard is prospective** (OTP-29 deviation);
work proceeded as defensive hardening, disclosed.

## Sweep table (lib/xaas, exact `grep -rn "Map.update"`)

| class | count | sites | action |
|---|---|---|---|
| (a) absent-key-critical, patched | 1 | `lib/xaas/ultracode/run_validation.ex:661` (`court_event/1`, `"relationships"` seed) | replaced with explicit `case Map.fetch` arms + `Map.put`; semantics identical on OTP 28 (absent → `[]`, present → courted list / passthrough); function made `@doc false` public for direct Chicago-style court access (precedent: `OcelSummaryController.summarize/1`, W659) |
| (b) intended default-value semantics, left | 0 | — | — |
| Bang `Map.update!/2` (raises on absent key — not the silent-skip class) | 12 | event_simulation.ex:615,640; admission_attribution.ex:94; machine_experience.ex:409,420; autonomic.ex:1275,1281; semantic_crown.ex:638; machine_experience/episode.ex:267,395,420,621 | LEAVE — failure mode is loud, not silent |
| Already converted dual-safe (prior W659 work, comment-referenced) | 8 modules | ocel_summary_controller.ex, turtle.ex, circuit.ex, workspace.ex, sequenced_drain.ex, semantic_drive.ex, process.ex, vulnerability_lifecycle.ex (finding record only) | LEAVE |

Post-sweep grep: `Map.update(` (non-bang) in lib = **0** remaining.

Note on the "~60 sites across 4 repos" memory: in xaas that population
predates the W659 dual-safe conversion pass; xaas currently held exactly one
live `Map.update/4` site. The remaining ~59 presumably live in the other 3
repos, out of this lane's scope.

## Court

`test/xaas/otp29_map_update_court_test.exs` — parameterized, deterministic
key insertion across populated/empty baselines for the patched module
(`Xaas.Ultracode.RunValidation`):

- runtime probe pinned as a test (absent seeds default w/o fun; present applies fun; arity 4 not 3)
- `court_event/1` on `%{}`, populated-with-list-rels, scalar passthrough, absent-among-others, non-map
- parameterized: every baseline (empty, empty-rels, populated) yields `"relationships"` key present, always a list
- integration through the real `RunValidation.conformance/1` path (event normalization exercised; violations never mention relationships)

## Verification (real commands, pinned asdf toolchain, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW606)

- `mix compile --force` — clean, exit 0
- Run A: `mix test test/xaas/otp29_map_update_court_test.exs test/xaas/ultracode/run_validation_test.exs` — **43/43 passed, exit 0**
- Run B (fresh root: `rm -rf _build-laneW606/test` + full recompile of 209 dep libs + xaas) — **43/43 passed, exit 0**
- Two transient compile freezes from another lane's in-flight
  `lib/xaas/actuation/quiescent_stop.ex` edits (compile-abort, exit 1/2) —
  other lane's subject, not this diff; both cleared on retry per the
  compile-freeze SLA. Not session-introduced failures of this lane's code.

## Standing

PARTIAL_ALIVE — probe + court + ×2 fresh-root affected suites executed on the
real subject; full `mix test` not run (lane scope, shared checkout). Falsifier
for the prospective hazard: if an OTP-29 runtime skips the default seed on
absent keys, `RunValidation.court_event/1` still returns `"relationships" =>
[]` — the court at `test/xaas/otp29_map_update_court_test.exs` fails under
that deviation, making the skip non-silent.

## Left for coordinator

- `_build-laneW606/` NOT deleted — `rm -rf` was denied by the permission
  system twice; left for coordinator cleanup per the fallback in the lane
  directive ("delete when done, else leave for coordinator").
- No commit (per directive). Files touched: run_validation.ex (lib patch),
  court test, this receipt.
