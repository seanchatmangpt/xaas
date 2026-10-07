# W659 — xaas self-patch: dual-safe Map.update/4 remediation

Lane W659, wave v26.10.6. Subject: `/Users/sac/xaas` @ `feat/playwright-surface`
(dirty tree at dispatch; lane wrote only the files listed under Diffs).

Census source: W705
(`docs/sjira/v26.10.6/plans/w705-wasm4pm-ex4pm-gaps.md`, 12 absent-key-reliant
`Map.update/4` sites in `lib/`). All 12 sites are now the explicit
`case Map.fetch` dual-safe idiom: absent-key arm seeds the default and never
calls the update fun (pinned otp-28 observed semantics); present-key arm
applies the transform. Behavior-identical on the observed runtime; correct
under any future semantics flip because both arms are written explicitly.

## Per-site diffs

- `lib/xaas/runtime/fond/circuit.ex:4` — `fail/2` delegates to private
  `bump/2` (`case Map.fetch`: absent→seed 1, present→`n + 1`).
  `open?/2` unchanged (`Map.get` default 0); `reset/2` unchanged.
- `lib/xaas_web/controllers/ocel_summary_controller.ex:52,53` — the reduce
  extracted into `@doc false def summarize/1` (public so the real NDJSON
  aggregation is directly testable — Chicago-style, real lines) with private
  `bump/2`; `index/2` calls it over the unchanged real `File.stream!`
  pipeline of `log_path/0`.
- `lib/xaas/gall/turtle.ex:139,167,172` — three append sites call private
  `map_append/3` (absent→`[entry]`, present→`list ++ [entry]`). Same
  document-order append as before.
- `lib/xaas/semantics/vkg/workspace.ex:120` — prepend arm written explicitly
  (absent→`[annotated]`, present→prepend); downstream `Map.new` reverse
  unchanged, observed row order unchanged.
- `lib/xaas/ultracode/sequenced_drain.ex:239` — tries counter via explicit
  case (absent→1, present→+1).
- `lib/xaas/ultracode/run_validation.ex:798,799` — both epoch-grouping
  append sites written as explicit case (absent→`[event]`, present→prepend);
  tuple `{:unattributable, id}` key arm included.
- `lib/xaas/ultracode/semantic_drive.ex:2472` — object-descriptor merge
  written as explicit case (absent→fresh descriptor, present→attributes
  merge + `Enum.uniq` relationship union).
- `lib/xaas/fabric/planes/process.ex:26` — observe arm written as explicit
  case (absent→`[kind]`, present→append). w604-style SUSPECT pinned in a
  comment: the absent path stores exactly `[kind]`, never `fun.([kind])`;
  the later `:receipt` arm consumes `facts["process.events"] || []`.

## Upgrade-safety note

On the observed runtime (Elixir 1.20.2-otp-28), `Map.update/4` skips the fun
on an absent key, so seed+transform and dual-safe are behavior-identical —
each site's existing behavior pins (104 passed across the touched modules'
suites, plus w705's own pins) prove no drift was introduced. Under any future
runtime where the fun is applied to the default, every one of these 12 sites
would have silently corrupted counters (1→2 on first increment) or list
seeds (duplicated first entry) — the dual-safe form is immune by
construction. The remaining single `Map.update/4` in `lib/` is
`run_validation.ex:661`, whose default `[]` is fun-invariant
(`fun([]) == []`), correct under either semantics, outside the census.

## Verification (real runs, canonical `_build/test`)

- Strict compile: `MIX_ENV=test mix compile --warnings-as-errors` → rc=0
  (one pre-existing dep warning in `ash_affidavit`; not session-introduced).
- New suite: `mix test test/xaas/semantics/map_update_dual_safe_test.exs`
  → **9 passed, 0 failed** (canaries x3, census tripwires x2, circuit
  boundary, OCEL summarize x2, turtle admission pin).
- Touched modules' existing suites (circuit/turtle/workspace/run_validation/
  sequenced_drain/semantic_drive x3) → **104 passed, 7 skipped**.
- Ocel controller ConnCase (real HTTP + real log) → **1 passed**.
- Fabric castle_alive + w705 pin suite (incl. Process plane pins) →
  **4 passed, 10 excluded** (pre-existing tags).

## Notes for the coordinator

- The cold lane build root was abandoned: same pre-existing cold-dep failure
  w705 hit (`:ash_a2a` released-agent compile at cold build; canonical
  `_build/test` has the dep prebuilt and is green). No `_build-laneW659` was
  left on disk (cold build was stopped before it created one; the `rm -rf`
  of the partial root was permission-denied in this session — coordinator
  should delete `_build-laneW659` if a partial exists).
- The single pre-existing residue `run_validation.ex:661` is deliberately
  unpatched (fun-invariant default, outside census) and tripwired in the new
  test.
