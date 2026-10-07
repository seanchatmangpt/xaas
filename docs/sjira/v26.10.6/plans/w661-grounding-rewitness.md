# W661 — Grounding re-witness (EUAIA merge verification)

Subject: /Users/sac/xaas @ feat/playwright-surface, lane build root `_build-laneW661`.

## Merged-state inventory

- `lib/xaas/semantics/airo_risk_mapping.ex` — `risk_concept_for/1` carries the
  full EUAIA family (W657): 8 `String.contains?` clauses for
  MANIPULATIVE / VULNERABILITY_EXPLOIT / SOCIAL_SCORING / PREDICTIVE_POLICING /
  FACIAL_SCRAPING / EMOTION_RECOGNITION / BIOMETRIC_CATEGORIZATION / REALTIME_RBI,
  each mapping to a distinct concept (RISK_TO_INFORMED_CHOICE,
  RISK_TO_VULNERABLE_PERSONS, CROSS_CONTEXT_RISK, DUE_PROCESS_RISK, PRIVACY_RISK,
  MENTAL_PRIVACY_RISK, DISCRIMINATION_RISK, SURVEILLANCE_RISK — no duplicates),
  plus the `MALFORMED -> MALFORMED_INPUT_CANDIDATE` clause and the generic
  `true -> UNADMITTED_TRANSITION` fallback. W657's `@euaia_atoms` list also
  drives EUAIA nodes/edges in `risk_graph/0` — intact.
- `test/eu_ai_act/airo_grounding_test.exs` — W660's flipped assertions intact:
  8-atom expected map (8 distinct concepts), `refute concept == "UNADMITTED_TRANSITION"`,
  bogus-atom fallback test preserved (`REFUSED_TOTALLY_BOGUS_ATOM -> UNADMITTED_TRANSITION`,
  determinism check), graph-emission court present. Header still says "W702 court"
  with a flipped-assertion comment — prose only, no defect.

## Real run (merge witness)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW661 \
  mix test test/eu_ai_act/airo_grounding_test.exs test/xaas/semantics/airo_risk_mapping_test.exs
```

Tail:

```
Finished in 0.07 seconds (0.07s async, 0.00s sync)

Result: 15 passed, 1 skipped
[exited with code 0]
```

## Verdict

MERGE-CLEAN — both lanes' work (W657 clauses, W660 flipped tests) intact in the
merged tree; all green together.
