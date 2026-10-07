# W981k — Registry EngineLimit Seams Receipt

- Lane W981k, xaas v26.10.6, repo `/Users/sac/xaas`, branch `feat/playwright-surface`
  (uncommitted; coordinator owns commits per fan-out law).
- Continuation of SPEC-10 from `docs/sjira/v26.10.6/plans/w976-design-wave5.md`:
  the remaining gateable EngineLimit rows measured at their true consumption
  seams.

## Limits chosen (by real registry + consumption-seam usage)

Read `lib/xaas/bridges/registry.ex engine_limits/0` (abi scope) and the real
graphlaw registry (`/Users/sac/graphlaw/registry/capability-registry.json`,
15 limits / 15 scopes+meta rows). Selection: the only limits with a true
consumption seam inside `Xaas.Bridges.Graphlaw` are the byte limits on the
exact payloads the bridge renders and hands to the engine — no artificial
plumb-through for any others (plan/hooks/wasm-scoped rows have no xaas
consumer that produces those quantities; measuring them would be theater).
Chosen:

| limit | scope | engine truth | seam |
|---|---|---|---|
| `max_request_bytes` | abi | 16 MiB (`src/abi.rs`) | byte_size of the JSON request (data + steps) rendered for `AshGraphLaw.law/3` |
| `n3_max_term_bytes` | n3 | 64 KiB (`src/law.rs`) | largest single N-Triples line (terms) in the rendered facts |
| `n3_max_total_bytes` | n3 | 256 MiB (`src/law.rs`) | total facts bytes fed to the n3 step |

All three gated in `Xaas.Bridges.Graphlaw.do_assess/3`.

## Wiring (minimal, one file)

`lib/xaas/bridges/graphlaw.ex` only:

- `do_assess/3` now renders facts/data/steps, then calls the new private
  `gate_engine_limits/3` before `AshGraphLaw.law/3` dispatch; a refusal is
  mapped through the same `limit_refusal_envelope/2` the W976 depth gate
  uses (typed `:limit_exceeded`, `class: :refused_admission`,
  `broken_term: :mu_on_O`, engine `refusal_name` carried verbatim).
- `gate_engine_limits/3` measures the rendered payloads (request JSON bytes,
  max N-Triples line bytes, total facts bytes) and runs three
  `LimitGate.enforce/2` calls (`abi` scope for `max_request_bytes`; `n3`
  scope for the two n3 rows); the first `{:refused, _}` wins, all-`:ok`
  admits. No engine dispatch on exceedance.
- Row-absent/unreadable stays fail-open (W976 semantic), now court-pinned at
  these seams too.

## Court

`test/xaas/graphlaw_limit_seams_test.exs` (NEW, 9 tests, Chicago — real
sandboxed Postgres rows via `Ash.create!`, real bridge calls against a dead
graphlaw server; zero mocks; the dead host isolates the gate: gate refusal is
`:limit_exceeded`, gate pass-through is the host layer's `:host_not_started`):

- per-limit exceedance refuses typed at the seam, naming `refusal_name`,
  `limit_value`, `broken_term` (3 courts, one per limit);
- per-limit within-limit passes through to engine dispatch (`:host_not_started`)
  (3 courts);
- no rows ⇒ fail-open reaches the engine (1);
- wrong-scope row does not gate (scope isolation, 1);
- W976 depth gate still refuses alongside the new gates (1).

Mutation rationale: deleting `gate_engine_limits/3` (restoring direct engine
dispatch) flips all three exceedance courts RED; making the gate fail-closed
on absent rows flips the row-absent court RED.

## Cross-lane overlap (disclosed)

`lib/xaas/bridges/graphlaw.ex` was dirty from W976's landed depth-gate wiring
(see `w976-design-wave5.md`) and stayed dirty through my lane; my edits are
additive on top (do_assess + two private helpers + envelope helper reuse).
Mid-lane, other lanes' in-flight files twice broke the shared compile
(`lib/xaas/ocel/event.ex`, then `lib/xaas/generated/regen_check.ex` mid-write);
both were concurrent, not introduced here, and both self-resolved on disk —
per the compile-freeze SLA I waited out the owners rather than touching their
files.

## Verification (real output)

- `mix compile` under `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW981k`: green.
- Courts green ×2, identical:
  `mix test test/xaas/graphlaw_limit_seams_test.exs test/xaas/graphlaw_limit_gate_test.exs test/xaas/chicago/bridges/`
  → **51 passed**, twice (runs at 09:17 and 09:20 local). First post-wiring
  run was 48/51 — the three exceedance courts exposed a real defect in my
  first `gate_engine_limits/3` (it returned the first `:ok` instead of the
  first refusal); fixed and re-run. The courts killed the defect, not
  coordinator pre-thinking.
- Direct probe confirmed `LimitGate.enforce/2` refuses a real n3-scope row
  exceedance (999 > 120 → `{:refused, %{limit: "n3_max_term_bytes", ...}}`).
- No commit made (per lane contract).

## Standing

- SPEC-10 (W731-GAP-2) EngineLimit enforcement: **PARTIAL_ALIVE → stronger
  PARTIAL_ALIVE**: 4 of 15 registry limits (depth + 3 byte limits) are now
  measured at true seams; the remaining 11 rows (plan/hooks/wasm/policy
  scopes) have no xaas consumer that produces their quantities — recorded and
  gateable via `enforce/2`, unmeasured by design (no artificial plumb-through).
  Registry surfacing of n3-scope rows (`Registry.engine_limits/0` still abi-only)
  is a disclosed remaining gap, not silently claimed.

## Cleanup

`_build-laneW981k/` NOT deleted: the `rm -rf` was denied by the permission
system at lane close. Left on disk for the coordinator (lane-lease law:
delete at integration, before the final commit).
