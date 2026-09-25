# Boundary Qualification Receipt — autofde-lab / cap-crown (r9)

Release: SA2A v26.9.17 wave, 2026-09-17. Task: `qualify-boundary(autofde-lab, cap-crown)` — the self-reinforcing SA2A loop (Episode₁ UNKNOWN→Experience→KNOWN; Episode₂ KNOWN→Replay) and its top-level qualification/orchestration.

## Pinned subject

- Repo: /Users/sac/autofde-lab, branch master, pinned HEAD `00af45eeef96cdfe34d7ea8c2acf7fc31b9d54b0` (re-pinned, matches mission).
- Tag `v26.9.16` → `f5727fa9` (HEAD is post-release; no v26.9.17 tag exists — release act not yet performed).
- Dirty drift at verify time (10 entries, preserved, never stashed): 5 submodule pointers (`cpp/sdk/{Catch2,backward-cpp,json,nngpp,spdlog}`), `vendor/gyms/{enterprisebench,sregym}`, modified `src/autofde_lab/fabric/{bounded_exec,coverage}.py`, untracked `reports/capability_coverage/`, `tests/fabric/test_coverage.py`. All outside the crash path; additive concurrent work; none implicated in any observed failure.

## Verification court (commands + exits)

| # | Command | Exit | Result |
|---|---|---|---|
| 1 | `.venv/bin/python -c "…crown_report()"` | 0 | `internally_closed=True`, 83 requirements: 67 SATISFIED / 16 BLOCKED / 0 PARTIAL / 0 MISSING; `validate()` empty (fail-closed terminal court) |
| 2 | `pytest tests/sa2a/test_autonomic_closed_loop_lifecycle.py tests/sa2a/test_afde_2612_repeat_episode_zero_inference_closure.py tests/sa2a/test_unknown_bridge.py` | 0 | 15 passed — Episode₁ promotion + Episode₂ zero-inference replay, real counting collaborators |
| 3 | `pytest tests/sa2a/test_brce_replay.py tests/sa2a/conformance/test_court_replay.py tests/sa2a/conformance/test_afde_2604_replay_idempotency_fresh_mutations.py` | 0 | replay ledger / replay court / replay idempotency all pass |
| 4 | `.venv/bin/python scripts/run_chicago_qualification.py` (PRE-FIX) | **1** | BUILD-BROKEN FALSIFIER: `AttributeError: 'tuple' object has no attribute 'value'` at `src/autofde_lab/ocel/log.py:450` — 12-gate runner crashed during OCEL export, no StandingReceipt returned |
| 5 | Same, POST-FIX | 1 (adjudicated) | Runner COMPLETES: all 12 gates execute, **11 pass**, `ocel_conformance.all_objects_conform=True`, receipt + digest written to /tmp/uzc/chicago_receipt_fixed.json. Sole failing gate: CHI-ID `ExactIdentityFenced` — court correctly refuses to certify an untagged HEAD as `v26.9.16` (designed fence, not breakage) |
| 6 | `pytest` tracer + falsification-court suites (incl. new tripwire) | 0 | pass |
| 7 | Re-run of #2 + #3 post-fix | 0 | no regression |

## HDDL-task coverage map (capability probe, file:line)

- **orient** — README.md (standing vocabulary, court inventory); `docs/STATUS.md` (in-repo standing ledger); `Justfile` (test recipes); `.github/workflows/` (39 courts incl. 5 existing `*crown*.yml`).
- **close-boundaries** — `src/autofde_lab/sa2a/brce/boundary.py` (`ConsequenceBoundary`, sole DO boundary); `src/autofde_lab/sa2a/conformance/courts/` (6 courts: admission/authority/consequence/identity/logic_hook/replay); `tests/sa2a/conformance/test_afde_2604_boundary_fences.py`.
- **discovery-episode (UNKNOWN→Experience→KNOWN)** — `src/autofde_lab/sa2a/unknown/resolution.py:97` (`UnknownResolutionPipeline`: UNKNOWN → candidate frontier → discovery → admission → KNOWN; admission court is sole KNOWN-granter, :174-178); `unknown/compilation.py` (`MachineExperienceCompiler`, `ExperienceCompilationReceipt` = the Experience compilation); `unknown/allocator.py` (`CMCACandidateAllocator`, `FrontierAllocationPlan` = frontier accounting); loop witness `tests/sa2a/test_autonomic_closed_loop_lifecycle.py:63` (Cycle 0 refused → promotion → Cycle 1 zero inference).
- **replay-episode (KNOWN→Replay)** — `src/autofde_lab/sa2a/brce/replay.py` (deterministic replay ledger); `conformance/courts/replay_court.py`; `tests/sa2a/test_afde_2612_repeat_episode_zero_inference_closure.py` (second matching episode = measured 0 synthesis calls); Gates CHI-REPLAY + CHI-KNOWN in `conformance/runner.py:277-280`.
- **certify (top-level orchestration)** — `src/autofde_lab/sa2a/conformance/runner.py:269` `ChicagoCrownQualificationRunner` (12 gates CHI-ID→CHI-KNOWN, OCEL tracing, authenticated StandingReceipt); CLI `scripts/run_chicago_qualification.py`; terminal crown `src/autofde_lab/fabric/crown_terminal.py` + `fabric/crown.py` re-export.

**Named-term gap (observation, not UNSUPPORTED):** the literal gate `frontier_clean` exists nowhere in the repo (grep: 0 hits across src/tests/scripts/docs/.github). The concept it names is realized as `FrontierAllocationPlan` + OCEL `all_objects_conform` + Pareto law R-304 (`crown_terminal.py`). Extension available: alias/assert `frontier_clean := all(gates) ∧ all_objects_conform ∧ no PARTIAL/MISSING crown requirement` as a named artifact so the HDDL literal is directly checkable.

## Repairs (on `fix/autofde-lab-v26.9.17-boundary`, from pinned `00af45ee`)

- Commit `64181bb7` — narrow fix at the single defect site: `src/autofde_lab/sa2a/falsification/ocel_tracer.py::declare_object` appended raw `(key, value)` tuples into `OcelObject.attributes` (declared `tuple[OcelAttribute, ...]`), crashing every `to_ocel2_json` export and with it the 12-gate crown runner. Now emits `OcelAttribute(k, val)`. `record_event` was already Mapping-based and unaffected.
- Permanent tripwire (偽): `tests/sa2a/test_ocel_tracer_typed_object_attributes.py` — real tracer → real export → asserts declared types string/integer/boolean survive; fails with the exact AttributeError if raw tuples re-enter.
- No pushes, no PRs, no merges, no tag movement. Pre-existing dirt untouched (11 dirty entries remain: original 10 + nothing of mine; my 2 files committed atomically).
- Not done (outside this boundary's authority): bump `release_tag` in `runner.py:286` and cut tag `v26.9.17` — that is the release act; doing it here would fabricate release identity.

## Falsifiers attempted

1. Crown report fail-closed claim → 0 PARTIAL/MISSING despite 16 BLOCKED (each BLOCKED names an external dependency) — survived.
2. "Loop is aspirational only" (anticipated UNSUPPORTED) → falsified: loop executes for real; Episode₂'s zero-inference claim is measured, not asserted (`test_afde_2612` docstring documents the prior hardcoded-literal weakness and its closure).
3. Crash-is-dirt hypothesis → falsified: traceback path contains zero dirty files; reproduced identically through the official script.
4. Full 12-gate court against exact HEAD → 11/12, sole failure is the release fence, confirming the fence works rather than that the loop is broken.

## Standing: PARTIAL_ALIVE

The capstone loop machinery exists, executes, and is evidence-backed in this session at every HDDL level (discovery, replay, certification, 12-gate orchestration). "qualified" is withheld by the court's own identity gate — HEAD is lawfully uncertifiable as a release until the operator's release act (tag v26.9.17 + runner release constant). The court types that residual BUILD_BROKEN; inspection of the gate detail shows it is the fence, not the loop. Closure path: operator tags v26.9.17, one-line `release_tag` bump, re-run script → expect 12/12.

## What the operator did NOT have to write

The tracer defect, its diagnosis, the fix, and the permanent tripwire test (2 files, 54 insertions). Operator keystrokes reserved for: the release act (tag + release-constant bump) and standing review.
