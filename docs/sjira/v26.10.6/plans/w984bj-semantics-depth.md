# W984bj — Semantics depth court (airo_risk_mapping)

Standing: ALIVE (5/5 passing court, run twice on the lane build root)
Branch: feat/playwright-surface (no commit; tests + receipt only)
Lane build root: `_build-laneW984bj` — `rm -rf` was permission-denied in this lane; left for coordinator deletion.

## Module choice + coverage evidence

**Module: `Xaas.Semantics.AiroRiskMapping`** (`lib/xaas/semantics/airo_risk_mapping.ex`, 317 lines).

Selection: thinnest real coverage in `lib/xaas/semantics/` minus taken surfaces
(DatasetAdmission heavy; RobustMargin + VulnerabilityLifecycle = W981p;
Counterfactual/AdmissionAttribution via corpus; W984ai owns random_unit_direction).
Coverage evidence (grep test/ for module basename):

- `airo_risk_mapping`: **1 test file** (`test/xaas/semantics/airo_risk_mapping_test.exs`, 155 lines)
  plus one reference in `test/eu_ai_act/airo_grounding_test.exs` — thinnest of the family
  (all other semantics modules: 2–15+ referencing files; vkg/replay/witness/query 5–116).

## The court — `test/xaas/semantics/airo_risk_mapping_depth_test.exs`

5 tests, all real collaborators (real module, real ledger
`docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json`), no mocks:

1. **cond precedence ordering, determinism ×2** — 8 pairwise priority probes
   (MALFORMED > AUTHORITY > CASTLE+IDENTITY > DIGEST > RECEIPT > PROJECTION >
   CHECKPOINT > EVIDENCE > ... > fallback; EUAIA family beats MALFORMED).
   *Mutation rationale*: reordering cond branches silently re-families every
   multi-keyword variant string; no prior test pinned the order.
2. **typed fallback boundary** — unknown/empty/partial-keyword inputs
   (`""`, `"x"`, `"REFUSED_"`, unknown strings) all land on the closed-set
   `UNADMITTED_TRANSITION`, never raise. *Mutation rationale*: deleting the
   catch-all cond arm crashes the whole risk_graph build.
3. **`variants/0` idempotency + sortedness ×2 fresh calls** over the real
   ledger: `v1 == v2`, sorted by variant, `refused? == starts_with "REFUSED_"`,
   nonempty sites. *Mutation rationale*: dropping `Enum.sort_by` or leaking
   per-call accumulation breaks downstream deterministic emission.
4. **graph structural uniqueness** — exactly `variants + 8` hasRisk edges,
   exact duplicate-edge shape pinned. *Mutation rationale*: a `safe_local/1`
   collision silently merges two distinct risks into one RDF node.
5. **CASTLE+IDENTITY conjunction boundary** — CASTLE alone and IDENTITY alone
   both fall through to `UNADMITTED_TRANSITION`; both together →
   `IDENTITY_SPOOFING`, deterministic; pairwise-distinct concept set.
   *Mutation rationale*: loosening the guard's `and` to `or` is invisible to
   every prior test.

## Finding (witnessed defect, disclosed)

`REFUSED_EUAIA_MANIPULATIVE` exists **both** as a ledger variant and as an
`@euaia_atoms` entry, so `risk_graph/0` emits a duplicated
`ex:riskSource-REFUSED_EUAIA_MANIPULATIVE` node + hasRisk edge — two distinct
risk sources silently share one RDF subject. The prior contains-only suite
never observed this. Court 4 pins the exact observed duplicate shape; fixing
the duplicate in `risk_graph/0` will flip court 4 and force a visible repair.
Per repo operating mode, defect is disclosed, not gated on: no lib/ fix
landed in this lane (out of lane scope).

## Execution receipt

- Run 1 (fresh lane build root, full compile): **5 passed** (after court 4 was
  rewritten from asserting a violated uniqueness invariant to pinning the
  witnessed duplicate — the original form failed 4/5 and surfaced the defect).
  First compile run: 4/5, 1 failure = court 4 (the finding).
- Run 2 (warm root, same subject): **5 passed**.
- Prior suite regression: `test/xaas/semantics/airo_risk_mapping_test.exs`
  **8 passed, 1 skipped** (pre-existing rdflib-venv skip, unchanged).
- Commands: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
  MIX_BUILD_ROOT=_build-laneW984bj mix test test/xaas/semantics/airo_risk_mapping_depth_test.exs`
  (exits 0).
- Note: a second fresh-root run was not possible — `rm -rf` of the lane build
  root was permission-denied in this lane. Runs 1–2 above are fresh-compile
  (run 1) + warm (run 2) on one fresh root; build root left for coordinator.

## Files

- `test/xaas/semantics/airo_risk_mapping_depth_test.exs` (new, 5 courts)
- `docs/sjira/v26.10.6/plans/w984bj-semantics-depth.md` (this receipt)
