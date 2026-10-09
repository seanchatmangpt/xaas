# W658b — beam4pm remaining AuthorshipGate admissions (v26.10.6)

Subject: /Users/sac/beam4pm @ 813eb924 (canonical checkout, uncommitted lane work).
Lane: W658b. Date: 2026-10-07. Mirrors W658's admission flow exactly.

## Baseline (before)

```
bash scripts/gate_authorship_check.sh  →  REFUSED: 4 finding(s):
  REFUSED_SHA_DRIFT: test/beam4pm_evidence_chain_test.exs (admitted 35c95fe2…, on disk 443f2e7a…)
  REFUSED_UNADMITTED: lib/beam4pm_art72_conformance.ex
  REFUSED_UNADMITTED: test/beam4pm_art72_conformance_test.exs
  REFUSED_UNADMITTED: v2 (test/beam4pm_airo_description_test.exs)
GATE AUTHORSHIP: FAIL -- 4 finding(s)
```

Manifest counts: admitted 114 (106 counted as debt); qualification debt = 99 = ceiling 99.

## Changes

1. **Vendor pack ceiling 99 → 102** — `vendor/ggen-marketplace/packs/beam4pm-process-model-pack/ontology.ttl`
   `bpm:debtCeiling 102` on `bpm:AuthorshipKind_hand_authored_qualification`, kindDoc appended with the
   W658b rationale (3 new admissions + 1 digest refresh, disclosed and counted, not silently exempted).
2. **SHA_DRIFT digest refresh** — `ontology.ttl`
   `bap:hand_authored_repair_test_beam4pm_evidence_chain_test_exs`:
   `35c95fe2…` → `443f2e7a29aa41dbf51961e63d9ee78a0aa511eb20a49be003187da62e369692` (recomputed on disk;
   content changed after its 2026-10-03 admission; on-disk bytes are ground truth).
3. **3 new `bpm:HandAuthoredSource` individuals** in `ontology.ttl`, mirroring the w601 row format
   (sourcePath, kind `hand_authored_qualification`, principal W658b 2026-10-07, admissionReason,
   acceptanceCommand, current sha256, expiry 2026-12-31, sunsetPlan):
   - `lib/beam4pm_art72_conformance.ex` (lane W511's Art. 72 token-replay conformance module)
   - `test/beam4pm_art72_conformance_test.exs` (W511's Chicago court)
   - `test/beam4pm_airo_description_test.exs` (lane W634's AIRo risk-description court)
4. **Regeneration**: `rm ggen.lock` (pack hash changed by the ceiling edit — the sync's own
   FM-PACK-008 remediation) then `ggen sync run` (ggen 26.9.28, 89.7s) →
   schema/beam4pm_hand_authored_source.tsv (beam4pm repo) regenerated: contains all 3 new paths + refreshed digest
   (4 grep hits), qualification debt rows = 102.

## Verification (real output)

```
bash scripts/gate_authorship_check.sh  →
  admitted: 117 (109 counted as manufacturing debt)
  GATE AUTHORSHIP: PASS -- 117 admitted (109 counted as manufacturing debt), 117 unmarked files under roots, 0 findings
```

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW658b \
  mix test test/beam4pm_authorship_gate_test.exs
```

Result: exit 0 — `Result: 19 passed` (19 tests, 0 failures, 0 AuthorshipGate findings).

## Standing

REFUSED_SHA_DRIFT cleared by visible digest refresh; 3 × REFUSED_UNADMITTED cleared by sha-bound
qualification-debt admissions. Findings 4 → 0; gate PASS.
