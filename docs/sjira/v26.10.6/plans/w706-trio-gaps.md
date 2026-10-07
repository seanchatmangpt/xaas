# W706 — trio gap fill (ash_pplan + ash_r2rml + ash_affidavit → xaas)

Lane: W706, repo `/Users/sac/xaas` @ `feat/playwright-surface` @ `d1db2b03`,
one canonical checkout, private build root `_build-laneW706` (cold-root compile
hits the pre-existing `ash_a2a` `:capability_release_closure_missing` failure
documented in w634; verification ran against the shared `_build/test`, same
precedent). Test-only diff; `lib/` untouched.

## Gap table (trio pattern → xaas state → verdict)

| # | Trio pattern (source) | Xaas state audited | Verdict |
|---|---|---|---|
| 1 | ash_pplan `manufacture_test.exs` + `bin/gate`: byte-identical regeneration court **with an anti-vacuity mutation leg** (real File tamper proving the comparison detects a hand edit) | xaas HAS a manufacture gate over its own generated surface: `test/xaas/ash_surface_drift_guard_test.exs` (full regen via `mix xaas.ash_surface --target-dir`, sha256 byte-identical) — but NO mutation leg; if its assertions were deleted, nothing fails | **FILLED** — `test/xaas/ash_surface_drift_mutation_test.exs` |
| 2 | ash_r2rml `VKG.Registry.admit([])` non-empty-contract refusal (`registry.ex:25`, typed `REFUSED_VKG_REGISTRY_AMBIGUOUS`) + W378's in-source dead-clause discipline (vkg.ex:52) | xaas exercises the edge only transitively (empty root → `REFUSED_VKG_MANIFEST`, `vkg_refusal_negative_test.exs`); no direct court over the dependency-level fail-closed edge that keeps vkg.ex:52 dead. In-source lib/ comment on the dead clause is **outside this lane's contract** (test/ + plan doc only) — carried instead as machine-greppable proof in the test moduledoc | **FILLED (test-side)** — `test/xaas/semantics/vkg_registry_nonempty_contract_test.exs`; in-source lib/ doc: **UNFILLED, contract-bounded** (operator/next lane with lib/ authority) |
| 3 | ash_affidavit closed-algorithm set + typed unsupported refusal (signing.ex `algorithm_of/2` refuses a key source with no usable alg; describe-domain closed) | `EuAiActAdmission.refusal_atoms/0` = **8 atoms (not 9 — task brief's count was wrong)**; exact-list assertion and fuzz allowed-set ALREADY EXIST (`eu_ai_act_admission_test.exs:44`, `admission_fuzz_test.exs:130,385`). Missing: closedness from the negative side — describe/1 must refuse every non-member | **FILLED** — `test/xaas/semantics/eu_ai_act_refusal_closed_set_test.exs` |

## Diffs (all new files, test/ + this doc; zero lib/ lines)

- `test/xaas/ash_surface_drift_mutation_test.exs` (new) — regenerates the real
  surface via `Mix.Tasks.Xaas.AshSurface.run(["--target-dir", tmp])`, hand-edits
  the largest regenerated artifact on disk (real `File.write!`, no mock),
  asserts the guard's own sha256 comparison reports exactly that file, restores
  the bytes, asserts drift collapses to `[]`. Chicago: real files, real
  comparison, assert on final state.
- `test/xaas/semantics/vkg_registry_nonempty_contract_test.exs` (new) — direct
  court over `AshR2RML.VKG.Registry.admit/1`: `[]` → typed Refusal
  (`:REFUSED_VKG_REGISTRY_AMBIGUOUS`, subject `:contracts`, exact detail), four
  non-list inputs → typed Refusal; moduledoc carries the full w378 structural
  proof that `vkg.ex:52` is dead (only entry binds `ids != []`; admit/1 refuses
  `[]`; `Catalog.ids` = keys of a non-empty registry map) so the proof is
  greppable without a lib/ edit.
- `test/xaas/semantics/eu_ai_act_refusal_closed_set_test.exs` (new) — refusal_atoms/0
  is exactly the 8-atom set, no duplicates; describe/1 total over the set and
  injective; describe/1 raises `FunctionClauseError` on every non-member
  (including `:REFUSED_EUAIA_MALFORMED_CANDIDATE`, deliberately outside the
  Art. 5(1) partition — dispatched via `apply/3` to keep expected
  no-clause diagnostics out of compile warnings); a real Art. 5(1)(a)
  refusal returns an atom inside the closed set.

## Verification (real runs, shared `_build/test`, asdf toolchain)

```
PATH=$HOME/.asdf/shims:$PATH mix test test/xaas/semantics/eu_ai_act_refusal_closed_set_test.exs test/xaas/semantics/vkg_registry_nonempty_contract_test.exs
# Result: 6 passed  (0.07s) — no compile warnings from the new files

PATH=$HOME/.asdf/shims:$PATH mix test test/xaas/ash_surface_drift_mutation_test.exs
# Result: 1 passed  — real regen + tamper detected + restore clears drift
```

## Standing

- Gap 1 (manufacture-gate mutation leg): ALIVE on this tree — real regen + real
  tamper + real sha256 comparison, 1 test.
- Gap 2 (registry non-empty contract): ALIVE at the dependency court level;
  in-source lib/ dead-clause comment remains an explicit operator decision
  (contract: test-only lane).
- Gap 3 (closed refusal vocabulary): ALIVE — closed from both sides (exact-set
  + negative membership). Task brief's "9 atoms" corrected to the real 8.

## Falsifiers

- Mutation test fails if the guard's comparison stops detecting edits or if
  regen drifts from the committed surface.
- Closed-set tests fail if a 9th atom joins without a describe clause, if
  describe gains a catch-all, or if admit/1 ever returns an out-of-set atom.
- Registry test fails if ash_r2rml ever admits an empty/non-list contract list.

## Cleanup

The lane build root `_build-laneW706` (380 MB, cold, unusable per the w634
cold-root ash_a2a failure) is a lease to be reclaimed at integration: this
lane's `rm -rf` was REFUSED by the session permission system, so deletion is
handed to the coordinator (one command: `rm -rf /Users/sac/xaas/_build-laneW706`).
