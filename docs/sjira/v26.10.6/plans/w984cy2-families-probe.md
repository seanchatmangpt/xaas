# W984cy2 — Coverage-Map Families Probe: ResearchRuntime + CS2.FleetContract

Lane W984cy2, xaas v26.10.6 campaign, 2026-10-07. Read-only lane: one new test file
(no lib/ changes), no commits. Receipt only.

## Family 1: Xaas.ResearchRuntime (20 uncovered per W984cj map)

Fresh read of `lib/xaas/research_runtime/*` (14 subdirs, 41 modules total).

**Structure discovered**: each subdir has 1 "primary" module referenced by its
`*_wave_test.exs` (e.g. `ExecutionEnvelope`, `Intent`, `Event`) plus 1-2 sibling
modules with zero test references. The ~19 uncovered modules are not 19 distinct
behaviors — they are **one 16-line struct template instantiated 19 times**:

```elixir
defstruct [:key_field, status: :unknown, provenance: %{}]
def new(attrs)  # refuses nil/"" key field with typed {:error, :missing_<key>}
def admit(v, pred)  # pred.(v) -> {:ok, %{v | status: :admitted}} | {:error, :refused}
```

Verified identical in: `closure/coordinator.ex`, `closure/execution_envelope.ex` (tested
sibling — the template IS partially witnessed there), `ocel/replay.ex`,
`ptd/generation_fence.ex`, `evidence/evidence_admission.ex`,
`intervention/command_budget.ex` (all read in full; the others match by pattern).

**Real behavior vs placeholder**: real but minimal — a key-field admission gate and a
predicate-driven unknown→admitted/refused state transition. Not dead code, but each
instance carries no behavior beyond the shared template. This is the N-implementations
of one calculus drift class ([[dfcm-composition]] law): one shared macro/behaviour would
collapse 19 copies to 1, making per-copy courts redundant.

**Disposition**: court the class representative, not 19 copies.
- `closure/coordinator.ex` chosen as representative (arbitrary among identical copies;
  Coordinator + ExecutionEnvelope are byte-pattern identical).
- Note: the tested siblings (e.g. `ExecutionEnvelope` via `closure_wave_test.exs`)
  already witness the template's happy path, so per-template coverage risk is low; the
  gate/admit invariants are what a court adds.

## Family 2: Xaas.CS2.FleetContract (4 pub, top-5 uncovered)

Fresh read of `lib/xaas/cs2/fleet_contract.ex` (41 lines).

**Real behavior**: pure representation boundary (its own moduledoc says so). Three
behaviors: (1) `subject/0`+`contract/0` constants; (2) `engineer_workflow/1` —
atom-key→string-key normalization, hard subject gate on
`https://chatman.ai/cs2#RFC-CS2-001` returning typed
`{:error, {:unsupported_cs2_subject, _}}`, authority-"NONE" stamping; (3) non-map
clause returns `{:error, {:unsupported_cs2_packet, _}}`.

**Test references**: no direct test file. Indirectly exercised:
- `test/xaas/cs2/ash_a2a_bridge_test.exs:17` and
  `test/xaas/cs2/semantic_jira_bridge_test.exs:71` both assert
  `kind == "cs2.engineer_workflow"` — that value is produced only inside
  `FleetContract.engineer_workflow/1`, so the happy path IS witnessed through the
  real bridge collaborators (Chicago-conformant: real transport, not mocks).
- The subject-gate error paths (`{:error, {:unsupported_cs2_subject, _}}` for wrong
  subject, `{:error, {:unsupported_cs2_packet, _}}` for non-map) are unwitnessed.

**Disposition: typed disposition, no new court.** It is a stateless pure function —
no state-bearing behavior to court per Chicago criteria; the stateful question
("does a wrong-subject packet get refused before authority is stamped?") is a 2-line
gate whose refusal paths are the only gap. Recommend folding 2 gate-path assertions
into the existing `ash_a2a_bridge_test.exs` (real collaborator path) in a future
lane rather than a standalone court. Standing: PARTIAL_ALIVE (representation
boundary, happy path witnessed, gate paths unwitnessed).

## Court written

`test/xaas/research_runtime/closure/coordinator_test.exs` — 5 tests:
1. new/1 accepts run_id, defaults status :unknown, provenance %{}
2. new/1 refuses nil / "" / absent run_id with typed `{:error, :missing_run_id}`
3. admit/2 passing predicate → status :admitted, fields+provenance preserved
4. admit/2 failing predicate → typed `{:error, :refused}`, original struct untouched
   (immutability invariant)
5. admit/2 on a foreign struct (Replay) raises FunctionClauseError — pattern-match
   guard is load-bearing

**Mutation rationale**: kills the class of mutations that (a) drop the nil/"" key gate,
(b) mutate in place instead of returning a new struct, (c) flip admit/2's boolean,
(d) widen the `%__MODULE__{}` guard. Test 5 additionally guards against a future
template consolidation loosening the guard to `struct`-any — a regression that would
let a Replay receipt be admitted through Coordinator.

**Execution (×2 fresh roots, real output)**:
```
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984cy2 PATH=$HOME/.asdf/shims:$PATH \
  mix test test/xaas/research_runtime/closure/coordinator_test.exs
Run 1 (cold root, full deps compile): Finished in 0.03s — 5 passed, 0 failures
Run 2 (root deleted, recompiled from scratch): Finished in 0.03s — 5 passed, 0 failures
```
Both runs compiled the whole deps tree from an empty `_build-laneW984cy2` (each
~15 min cold compile), giving a genuinely ×2-fresh-root verification.

## Standing & open items

- Coordinator court: **ALIVE** — executed twice on fresh roots, 5/5 both times.
- FleetContract: **PARTIAL_ALIVE**, typed disposition (see Family 2).
- Template-class note: 18 more sibling copies of the same template remain uncourted;
  recommended follow-up is a template-consolidation refactor (one behaviour/macro)
  plus a shared court, not 18 more test files.
- **Disclosure — lane lease not fully cleaned**: `_build-laneW984cy2/` still exists
  under `/Users/sac/xaas/`. My in-command `rm -rf` after run 2 was executed by the
  background wrapper's shell for run 1's cleanup, but the final cleanup `rm` was
  denied by the permission system (twice, including sandbox-disabled). I did not
  route around the denial via the oclnr plan/audit tools (the existing
  `cleanup-plan.json` belongs to another coordinator's lane set and does not include
  this lane). Coordinator should delete `/Users/sac/xaas/_build-laneW984cy2` at
  integration per the lane-lease cleanup law.
- Files written: `test/xaas/research_runtime/closure/coordinator_test.exs`,
  this receipt. Nothing committed.
