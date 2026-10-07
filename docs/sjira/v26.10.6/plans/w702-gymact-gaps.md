# W702 — gymact→xaas gap wave receipt

Lane: W702 · Repos: audit `/Users/sac/gymact`, fill `/Users/sac/xaas @ feat/playwright-surface` (one canonical checkout, `_build-laneW702`)
Date: 2026-10-06 · Contract: new test files under `test/` + this receipt only.

## Audit findings (gymact surface → xaas status)

| gymact surface | gymact evidence | xaas status found |
|---|---|---|
| (a) standing-enforcement discipline (`tests/test_standing_enforcement.py`) | unavailable+undeclared standing = hard failure; named env-allow → typed skip; wildcard → skip; sibling stays collected — all over real pytest subprocesses | PARTIAL gap. Kernel-level authority floor exists (`Xaas.Actuation` → `:delegated_actuation_requires_authority_evidence`, fuzz-covered by `test/xaas/semantics/authority_decoupling_test.exs`), but the frontier-evidence standing gate `{:standing_required, producer}` (lib/xaas/actuation/frontier_evidence.ex:148-150) had ZERO test coverage |
| (b) production-surfaces gate (`tests/test_production_surfaces.py`) | real-surface smoke: REST candidate construct + raw-DO refusal `BRCE_EXECUTION_GRANT_REQUIRED` | Covered. xaas equivalent already exists: `test/xaas/actuation_test.exs` (real Ash.Reactor over real sandboxed Postgres, bypass refusal + replay) — no new surface to add |
| (c) AIRo risk description (W603, `tests/test_airo_risk_description.py`) | TTL parses, AISystem/deployer/risks structure, cited consumers exist | PARTIAL gap. xaas vendors AIRo + pins SHA (W621b, `test/xaas/semantics/airo_vendored_pin_test.exs`) and projects a risk graph (W601, `airo_risk_mapping.ex`), but the eu_ai_act suite had ZERO AIRo references — Art. 5 refusal atoms were never grounded to AIRo |
| (d) reward/gate integrity (`test_two_gym_gate.py`, `test_run_sparql_gates.py`) | SPARQL gates + two-gym gate | Covered in kind, not name: xaas court family (castle_refusal_negative_*, authority_decoupling, mutation courts) plays the same role |

## Gaps found → filled / typed

1. **Frontier-evidence standing court (filled)** — new
   `test/xaas/frontier_evidence_standing_enforcement_test.exs`: absent/blank/whitespace
   standing → hard typed refusal `{:standing_required, producer}`, per-producer named;
   no bundle hash minted on refusal; declared standing admits; gymact sibling property;
   actuation-surface leg (no authority evidence → hard refusal, zero state + zero
   prepared-intent yield; with evidence → success + sealed receipt).
2. **Untyped skips (found none)** — `grep '@tag :skip\|@moduletag :skip\|skip: true'` over
   `test/` = 0 matches; every machinery-absent skip in the tree already carries a named
   reason (w155 compliant). Nothing to convert.
3. **AIRo grounding (filled + typed gap recorded)** — new
   `test/eu_ai_act/airo_grounding_test.court`… i.e. `test/eu_ai_act/airo_grounding_test.exs`:
   grounding-first cited-file existence, vendored-TTL namespace, describe/2 completeness
   over the Art. 5 atoms, deterministic AIRo grounding per atom, graph emission of the
   grounded concept (`mapsToRiskConcept`), and a pinned TYPED GAP: all 8 Art. 5 atoms
   fall through `risk_concept_for/1`'s cond to the generic `UNADMITTED_TRANSITION`
   fallback (no EUAIA family clause in lib/xaas/semantics/airo_risk_mapping.ex) — pinned
   so a future EUAIA clause must update the court consciously.
4. **EUAIA clause in `AiroRiskMapping.risk_concept_for/1`** — BLOCKED by lane contract
   (tests+receipt only). Typed: `REFUSED(CONTRACT_LIB_EDITS_OUT_OF_SCOPE)`. Follow-up for a
   lib lane.

## Verification (real commands, lane build root)

Command form (asdf-pinned toolchain, private build root):

```
MIX_BUILD_ROOT=_build-laneW702 MIX_ENV=test PATH=$HOME/.asdf/shims:$PATH mix test <files>
```

Build-root note: a fresh `_build-laneW702` fails on the vendored `ash_a2a`
dep (`:capability_release_closure_missing`, lib/ash_a2a/chicago/bench/b11_wire.ex:41)
— a pre-existing fresh-root gate, not session-introduced. Lane seeded the
dep artifacts from the canonical `_build/test` (same checkout, same SHA,
same toolchain) and compiled the xaas app itself privately (926 files, clean).

### Tails

- `mix test test/xaas/frontier_evidence_standing_enforcement_test.exs test/eu_ai_act/airo_grounding_test.exs`
  → `Result: 13 passed` (0.6s async)
- `mix test test/xaas/frontier_test.exs …` — neighbor sweep
  `frontier_evidence_test + airo_vendored_pin_test + airo_risk_mapping_test +
  authority_decoupling_test + eu_ai_act/smoke_test + actuation_test`
  → `Result: 29/30 passed, 3 excluded`
  - the 1 failure is PRE-EXISTING and environmental, not session-introduced:
    `Xaas.Semantics.AiroRiskMappingTest "rdflib round-trip parse when a parser
    is available"` (test/xaas/semantics/airo_risk_mapping_test.exs:62) — the
    test's `Enum.find` selects `/tmp/airo-venv/bin/python` as a string even
    when the venv binary is absent → `System.shell` exit 127. Untouched by
    this lane; fix belongs to a lib/test lane (pick an executable python).

## Standing

- Standing-enforcement court: PARTIAL_ALIVE (13 real-court tests green over
  real FrontierEvidence + real sandboxed-Postgres actuation).
- AIRo grounding court: ALIVE for the grounding contract; EUAIA-specific
  risk-concept refinement typed as a follow-up gap (lib lane).
- Lane lease: `_build-laneW702/` left on disk for coordinator deletion at
  integration, per [[same-checkout-fanout]] cleanup law.

