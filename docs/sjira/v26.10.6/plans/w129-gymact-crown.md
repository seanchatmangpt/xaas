# W129 — gymact DCM-018 witnessed-crown attempt

Date: 2026-10-06. Subject: /Users/sac/gymact @ d3eb5e848cb86952921d1b0083e0b7e7e1f53609 (dirty tree, W129 lane read-only on sources).
Task: attempt to flip DCM-018 `CROWN_REQUIRES_WITNESSED_DCM` (witnessed_crown: false) by running the canonical DCM flow end to end with real output.

## What DCM-018 requires (read from code)

- `src/gymact/dcm_requirements.py`: `witnessed_crown = standings.get("ALIVE") == 18` over `src/gymact/schemas/dcm-v26.8.7.json` (static file, DCM-001..018).
- `validate_dcm_requirements()` raises `DCM_CROWN_CANNOT_BE_PREMARKED_ALIVE` if DCM-018's standing is ever ALIVE/ADOPTED in the file.
- There is NO runtime feedback path: no code reads execution receipts back into dcm-v26.8.7.json or dcm-evidence-v26.8.7.json. `gymact dcm-status` reads only the static schema.

Consequence (structural, verified by reading the validator + tests
`tests/test_dcm_requirements.py::test_mutated_crown_cannot_predeclare_alive`): `gymact dcm-status` can never print `witnessed_crown: true`. The crown row is forbidden to be ALIVE in the file, and `witnessed_crown` requires all 18 rows ALIVE in that file.

## The witnessed run (real, executed)

Fixtures created under /tmp/w129 (in-repo fixture `tests/fixtures/cli_explore_request.json` was NOT modified):

- court request: `/tmp/w129/explore_mem.json` — `DecisionCourtRequest` over `action_possibility_fragment` for the real memory capability `urn:gymact:memory:capability:set` (test-fixture action re-capped to the provider's real capability).
- authority: `/tmp/w129/authority.json` — `{"authority_refs": ["urn:authority:operator"]}` (operator-controlled, separate from the request).
- execute request: `/tmp/w129/execute_request2.json` — self-materialized subject sentinel, `grant.admitted_observation_ref = digest({"x": 1})` (real BLAKE3/RFC8785 precomputed), payload `{"key": "x", "value": 2}`, expected `{"x": 2}`.

Commands (all via `/Users/sac/gymact/.venv/bin/gymact`, MemoryProvider, zero external world):

1. `gymact explore /tmp/w129/explore_mem.json` → exit 0. `rdf_validation.conforms: true`, `exploration.truncated: false`, frontier path_id `b2153d5773943c46…`, morphism_id `urn:gymact:morphism:b3543c76…` (saved `/tmp/w129/explore2_out.json`, `/tmp/w129/frontier2.json`).
2. `gymact execute /tmp/w129/execute_request2.json --authority-file /tmp/w129/authority.json` → exit 0, `evidence_verified: true`, transition **ALIVE**:
   - receipt_id `adae920dffff40f3aab590db9a2abacf`, standing ALIVE, `world_changed: true`, `verified: true`
   - pre_state_digest `690258f2…`, post_state_digest `6506c8a2…` (state actually changed `{"x":1} → {"x":2}`)
   - closure-bound: `possibility_graph_digest 0a7c52e6…`, `selection_digest bb47d877…` bound in the receipt.
   - Output: `/tmp/w129/execute2_out.json`.

Debug sequence that got there (real typed failures, each fixed): UNKNOWN_CAPABILITY → SELECTION_GRANT_NOT_ADMITTED:IDENTITY_REFUSED (grant.action_ref must equal action.semantic_id) → REFUSED actuation (grant.authority_ref must be in operator allow-list) → BLOCKED PROVIDER_ERROR:KeyError (memory payload needs `{"key","value"}`) → ALIVE.

## dcm-status before / after

- Before: `{"standings": {"STRUCTURAL": 17, "UNKNOWN": 1}, "total": 18, "witnessed_crown": false}`
- After the real ALIVE witnessed transition: identical — `{"standings": {"STRUCTURAL": 17, "UNKNOWN": 1}, "total": 18, "witnessed_crown": false}`

## Verdict

The full DCM chain executes end to end locally with zero external dependencies (public RDF → SHACL → maximal closure → cut → operator authority → BRCE → real consequence → verification → closure-bound receipt). But DCM-018 cannot flip `witnessed_crown` without a source/schema edit plus a receipt→standing feedback mechanism that does not exist in the repo today. Per lane rules (no source edits), stopped here rather than editing `dcm-v26.8.7.json` — and note the validator would refuse a premarked-ALIVE crown row anyway, so flipping the displayed flag requires new runtime code (a standing-feedback/overlay writer + relaxed crown-row rule), not just data.

Exact requirement to close DCM-018 (for W79/coordinator): (a) repo change adding a machine overlay that records the witnessed receipt (receipt_id `adae920d…` replays via the test-suite chain `tests/test_combinatorial_receipt.py` / `test_combinatorial_replay.py`) and updates the evidence overlay `dcm-evidence-v26.8.7.json` end_to_end field; (b) a decision on the `DCM_CROWN_CANNOT_BE_PREMARKED_ALIVE` law (currently witnessed_crown is unreachable by construction); (c) only then a schema edit for DCM-001..017 standings, backed by per-requirement receipts. No external collaborators (castle binary etc.) were needed; the blocker is in-repo design, not environment.

All artifacts under /tmp/w129; no gymact files modified (`git status` diff unchanged by this lane beyond pre-existing W129-lane modifications).
