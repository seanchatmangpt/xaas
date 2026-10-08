# W984dq6 — SpgGate Execute Receipt

Lane W984dq6, xaas v26.10.6 campaign, branch `feat/playwright-surface`.
Executed W984dq5's work order
(`docs/sjira/v26.10.7/plans/w984dq5-spg-integration-workorder.md`)
verbatim. No commit made (lane law); coordinator owns integration.

## Subject

`Xaas.Actuation.SpgGate` integration: F2 refinement + single-funnel seam
in `Kernel.do_admit/2` + 7-case integration court. Files touched (all
absolute paths, working-tree state at receipt time; base SHA not pinned
by this lane — coordinator pins at integration):

- `lib/xaas/actuation/spg_gate.ex` — F2 fingerprint guard.
- `lib/xaas/actuation.ex` — seam (`admit_spg/1` + `unwrap_reactor_error/1`
  extension).
- `test/xaas/actuation/spg_gate_test.exs` — amended unit court test 5.
- `test/xaas/actuation/spg_integration_test.exs` — new 7-case court
  (+1 bonus case pinning rule 4's atom-only `:spg` key channel).

## Work-order acceptance checkboxes

- [x] **F2 refinement landed**: `fingerprint_token/1` guard head, exact
      refusal atom `{:error, :spg_fingerprint_atom_keyed}`; never
      raises. Amended unit court test 5 exercises string-keyed input
      (partial and full shape) + unchanged atom-keyed determinism
      (test 4 stays green).
- [x] **Seam caller landed**: `Kernel.do_admit/2` → `admit_spg/1`
      private step per contract §1 (opt-in atom `:spg` key; ordered
      after `admit_authority/2`; no string-key fallback — commented at
      the call site; no other call site added).
- [x] **Integration court 7 cases green, ×2 fresh roots**: see runs
      below.
- [x] **Unit court green (amended test 5)**: same runs.
- [x] **`mix test test/xaas/actuation_test.exs` still green**: 6/6 in
      both runs.
- [x] **Zero bypass callers**: `grep -rln SpgGate lib/` → exactly
      `lib/xaas/actuation.ex` and `lib/xaas/actuation/spg_gate.ex`
      (witnessed this session, exit 0).

Standing: **ALIVE as an integrated path** — all six boxes witnessed.

## Deviations from the work order (disclosed)

1. **`unwrap_reactor_error/1` extension** (not in the work order).
   The work order's §1 claim that the refusal "already propagates
   correctly through the existing pipeline" was falsified on first
   derivation: the transactional path wraps the `:admit` step's
   `{:error, {:spg_gate_refused, reason}}` in Reactor's
   `{:reactor_failed, %Reactor.Error.Invalid{...}}` envelope, and the
   existing unwrapper only unwrapped idempotency contract tuples, so
   `run/4` returned `{:error, {:reactor_failed, ...}}` instead of the
   work order's expected `{:error, {:spg_gate_refused, reason}}`
   (court cases 3 and 4 failed on the exact expected shapes).
   Repair per the work order's named refuting-run-then-correct
   protocol: added `{:spg_gate_refused, _reason} -> step_error` to the
   existing case in `unwrap_reactor_error/1` — same contract-tuple
   class as `{:idempotency_conflict, _key}` (typed refusals surfaced
   bare to `run/4` callers). Court cases then passed unchanged from the
   work order's exact expected shapes. Not an ad-hoc weakening of the
   court; the court text is byte-identical to the work order's §3
   expectations.
2. **Fresh-root ×2 via two distinct roots** (`_build-laneW984dq6`,
   `_build-laneW984dq6b`) instead of delete-and-reuse one root:
   `rm -rf` was denied in this session's permission sandbox. Both
   fresh-root compiles were true full `mix compile --force` builds
   (EXIT=0 each), so the ×2 requirement is met on substance; both
   roots left on disk for the coordinator to delete at integration
   (lane-lease law).
3. **+1 bonus court case** (string `"spg"` authority key ignored —
   DO proceeds): pins §1 rule 4's fail-closed-by-absence channel
   against seam-side string-key-fallback mutants. Additive; does not
   alter the 7 required cases.

## Commands/exits (real tails)

Root 1 (`_build-laneW984dq6`, fresh `mix compile --force`):

```
Generated xaas app
COMPILE EXIT=0
...
Finished in 1.4 seconds (1.4s async, 0.00s sync)
Result: 18 passed
EXIT=0
```

Command (both roots):
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=<root>
mix test test/xaas/actuation/spg_integration_test.exs
test/xaas/actuation/spg_gate_test.exs test/xaas/actuation_test.exs`

Root 1: 18 passed, 0 failures, EXIT=0.
Root 2 (`_build-laneW984dq6b`, fresh `mix compile --force` EXIT=0,
"Generated xaas app"):

```
Result: 18 passed
TEST EXIT=0
```

(Note: expected `[error] [Reactor.Audit] Failed with errors:
... {:spg_gate_refused, :spg_not_admitted} ...` log lines in both runs
— the audit middleware logging the deliberately-refused court cases;
tests themselves 0 failures.)

## Replay

1. Check out this working tree state (coordinator pins SHA at
   integration).
2. `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
   MIX_BUILD_ROOT=_build-replay mix compile --force`
3. `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-replay
   mix test test/xaas/actuation/spg_integration_test.exs
   test/xaas/actuation/spg_gate_test.exs test/xaas/actuation_test.exs`
   → expect 18 passed, EXIT=0.

## Standing verdicts

- `Xaas.Actuation.SpgGate`: PARTIAL_ALIVE → **ALIVE as an integrated
  path** (capability + integrated path both witnessed; zero remaining
  UNKNOWN surface on this work order).
- F2 refusal atom `:spg_fingerprint_atom_keyed`: FINAL (as adjudicated
  in W650x / the work order).
- Seam decision (single funnel in `Kernel.do_admit/2`): confirmed by
  §3 case 7 — external-path parity passed without extra wiring; seam
  decision stands FINAL.
