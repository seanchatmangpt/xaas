# Episode₂ Replay-Contract Receipt — autofde-lab / cap-crown (HDDL §6-§7)

Wave: SA2A v26.9.17, 2026-09-17. Agent: wave-4 agent 3 of 8 (Episode₂ machinery: prove-semantic-equivalence + route-known-replay + frontier_clean invariant).

## Isolation

- Worktree: /tmp/uzc/autofde-ep2-wt, branch `feat/ep2-replay-contract`, cut from `fix/autofde-lab-v26.9.17-boundary` (64181bb7, the boundary agent's crash fix). All writes inside the worktree; main checkout untouched; no push/PR/merge/tag.

## 1. Machinery map (as found, file:line @ 64181bb7)

- **MachineExperienceCompiler** — `src/autofde_lab/sa2a/unknown/compilation.py:57`; `compile_candidate_experience` :73 compiles `(pattern, output, shacl)` triples into `CompiledDeterministicRule` :17 keyed by exact pattern; `resolve()` :107 serves rules deterministically; emits `ExperienceCompilationReceipt` :35 (fingerprints + digest). NOTE: it carries NO goal/subject/steps/bounds record — the typed transition record had to be introduced (below).
- **Frontier** — `unknown/allocator.py:112` `CMCACandidateAllocator.allocate` :120 (this is the call Episode₂ must never reach); `unknown/resolution.py:148` `route_unknown_to_frontier` is the only pipeline path into it.
- **Admission** — `unknown/resolution.py:174` `admit_candidate`, default court :115 is sole KNOWN-granter for candidates.
- **ReplayEngine** — `src/autofde_lab/sa2a/brce/replay.py:73`; `verify_chain` :83 does offline receipt-chain verification (hashes, prepared→final links, authority; Replay != DO). Replay court: `sa2a/conformance/courts/replay_court.py` (CHI-REPLAY/TAMPER/FRESH/KNOWN); gates at `conformance/runner.py:287,289`.
- **Equivalence: ZERO existing machinery.** Grep for `equivalen` across `src/autofde_lab/sa2a/` + `tests/sa2a/`: 0 hits (only unrelated SemanticEnvelope/Graph hits for "semantic"). `frontier_clean`: 0 hits in src (boundary receipt's named-term gap confirmed). HDDL predicates `equivalent` / `equivalence-failed` / `route-known-replay` / `replay-contract` had no repo realization.
- **Harness** — pytest, plain functions/classes, counting-collaborator style (real subclasses, counters read as final integer state, no unittest.mock), per `tests/sa2a/test_afde_2612_repeat_episode_zero_inference_closure.py`; run via `.venv/bin/python -m pytest` (Justfile). Gotcha: the venv installs autofde-lab as a scikit-build PEP-660 editable (`_autofde_lab_editable.ScikitBuildRedirectingFinder` in `sys.meta_path`), which beats PYTHONPATH; worktree testing requires neutralizing that finder in-process and inserting the worktree `src` first (verified `autofde_lab.__file__` → worktree).

## 2. Implemented (branch `feat/ep2-replay-contract`, commit 112d7e41; 2 files, 811 insertions)

**`src/autofde_lab/sa2a/brce/episode_replay.py`** (new):
- `EpisodeRecord` — typed structural transition record: `goal`, `subject`, `steps: tuple[str, ...]` (HDDL §2 subtask keys), `bounds: ExplorationBudget` (reused typed bounds); content-addressed `transition_signature` (ignores episode_id).
- `prove_semantic_equivalence(new, old)` — pure typed field comparison over goal/subject/steps/bounds; steps ordered (permutation = mismatch); bounds field-wise. Returns `EQUIVALENT | EQUIVALENCE_FAILED` + named `mismatched_fields` + `proof_digest`. No other input read — no analogy/LLM channel exists structurally.
- `admit_machine_experience(compilation, record)` — admission court; refuses uncompiled/empty experience (typed `ExperienceAdmissionRefusal`); success yields `AdmittedMachineExperience` with declared literals `admitted: Literal[True]`, `replay_contract: Literal[True]` (same anti-absence pattern as `CandidateResolution.authority`).
- `route_known_replay(new, experience, equivalence, *, frontier_clean)` — the §6 court, all-or-nothing reasons: REFUSED_EQUIVALENCE_FAILED / _PROOF_MISMATCH (ids must bind) / _PROOF_INVALID (route re-proves equivalence structurally from records — a forged/stale/judgment-produced "equivalent" verdict cannot route) / REFUSED_EXPERIENCE_NOT_ADMITTED / REFUSED_NO_REPLAY_CONTRACT / REFUSED_FRONTIER_NOT_CLEAN. Effect: `ReplayRoute` at `EpistemicState.KNOWN` with frontier_clean retained.
- `replay_known_transition(route, *, replay_engine, receipt_records)` — re-asserts known ∧ frontier_clean ∧ replay-contract fail-closed (typed `EpisodeReplayContractError`); replay = `ReplayEngine.verify_chain` offline (Replay != DO); returns `ReplayOutcome.frontier_clean_retained`.
- **Structural explore-unknown absence**: module imports `ExplorationBudget` only — never `CMCACandidateAllocator`/`UnknownResolutionPipeline`; `replay_known_transition`'s signature is exactly {route, replay_engine, receipt_records} — no parameter through which frontier allocation could be expressed.

**`tests/sa2a/test_episode2_replay_contract.py`** (new, 14 tests) — both directions plus teeth:
- Equivalent episode: real Episode₁ frontier use (counting allocator = 1), real compiler + admission court, real executed DO receipts via `ConsequenceBoundary`; Episode₂ (same transition, new id) → EQUIVALENT → routed KNOWN → replayed ALIVE; counting allocator still exactly 1 (zero frontier), counting engine exactly 1; proof digest deterministic.
- Non-equivalent (parametrized 5 ways: goal, subject, step missing, steps reordered, bounds): EQUIVALENCE_FAILED with field named → `ReplayRouteRefusal` (carries no route-shaped attribute) → counting engine stays 0 — never reaches replay.
- frontier_clean=False refuses even when equivalent; stale proof (episode-3's) cannot route episode-2; forged EQUIVALENT report cannot route a structurally different episode; forged route without contract facts raises; empty compilation refused; import-graph + signature isolation asserted.

## 3. Test evidence (worktree src; editable meta-finder neutralized in-process, resolution verified)

| Command (from /tmp/uzc/autofde-ep2-wt) | Exit | Result |
|---|---|---|
| pytest tests/sa2a/test_episode2_replay_contract.py -v | 0 | 14 passed in 1.97s |
| pytest {test_autonomic_closed_loop_lifecycle, test_afde_2612_repeat_episode_zero_inference_closure, test_unknown_bridge, test_brce_replay, conformance/test_court_replay, conformance/test_afde_2604_replay_idempotency_fresh_mutations, test_ocel_tracer_typed_object_attributes}.py | 0 | 33 passed (regression: loop 15-court set + replay courts + boundary tripwire) |
| All 8 suites together | 0 | 47 passed, 0 failed |

## 4. UNKNOWN / remaining

- `frontier_clean` here is caller-declared at route time + structurally enforced post-route (no allocator reachability, measured zero calls). An OCEL/witness-derived `frontier_clean` predicate (wired to the 12-gate runner's CHI-KNOWN) remains open — the boundary receipt's named-term extension.
- `EpisodeRecord.steps` are declared, not yet projected from a real episode's OCEL trace; tying them to the falsification tracer is future work.
- Release act (tag v26.9.17 + runner release constant) remains the operator's, per boundary receipt.
- Module compiles clean; two pre-existing SyntaxWarnings in `brce/boundary.py`/`replay.py` docstrings are upstream, untouched.

## Falsifiers attempted

1. "PYTHONPATH suffices for worktree testing" → falsified (meta-path finder won); permanent evidence in this receipt of the neutralization procedure.
2. Forged `EquivalenceReport(verdict=EQUIVALENT)` against a structurally different episode → refused (`REFUSED_EQUIVALENCE_PROOF_INVALID`) — the analogy channel is closed, not merely discouraged.
3. Direct `ReplayRoute` forgery without contract facts → `EpisodeReplayContractError` — transition teeth independent of the router.
4. Steps permutation treated as equivalent → refused (ordered comparison) — survived as a test.

## Standing: ALIVE

(For THIS boundary: the Episode₂ contract exists, executes, and is evidence-backed in this session, both directions measured. Release-level qualification still awaits the operator's release act and the wave integration.)

What the operator did NOT have to write: both files (811 insertions) — the equivalence court, the route gate, the structural frontier exclusion, and the 14-test proof.
