# W660 — airo_grounding refresh (flip the pinned TYPED GAP)

Wave: EU-AI-Act, lane W660. Repo `/Users/sac/xaas` @ `feat/playwright-surface`,
canonical checkout, build root `_build-laneW660`.

## Subject

- `test/eu_ai_act/airo_grounding_test.exs` (sole permitted test edit)

## Preconditions observed

- W657 landed: `lib/xaas/semantics/airo_risk_mapping.ex` carries the EUAIA
  clauses in `risk_concept_for/1` (mtime 2026-10-06 23:57) plus the
  `@euaia_atoms` table mirrored in `risk_graph/0`.
- The file already contained the flipped per-atom test ("W657 EVIDENCED"),
  but had NO fallback test for a truly unknown atom.

## Change

1. Preserved the flipped per-atom EUAIA assertions (all 8 Art. 5 atoms ->
   distinct dissertation-partition concept, `UNADMITTED_TRANSITION` refuted
   per atom).
2. Added the preserved fallback court: `REFUSED_TOTALLY_BOGUS_ATOM` ->
   `UNADMITTED_TRANSITION`, determinism re-check on the bogus atom.

## Per-atom concept table (via real `risk_concept_for/1` calls)

| Art. 5(1) atom | risk concept |
|---|---|
| REFUSED_EUAIA_MANIPULATIVE | RISK_TO_INFORMED_CHOICE |
| REFUSED_EUAIA_VULNERABILITY_EXPLOIT | RISK_TO_VULNERABLE_PERSONS |
| REFUSED_EUAIA_SOCIAL_SCORING | CROSS_CONTEXT_RISK |
| REFUSED_EUAIA_PREDICTIVE_POLICING | DUE_PROCESS_RISK |
| REFUSED_EUAIA_FACIAL_SCRAPING | PRIVACY_RISK |
| REFUSED_EUAIA_EMOTION_RECOGNITION | MENTAL_PRIVACY_RISK |
| REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION | DISCRIMINATION_RISK |
| REFUSED_EUAIA_REALTIME_RBI | SURVEILLANCE_RISK |
| REFUSED_TOTALLY_BOGUS_ATOM (fallback) | UNADMITTED_TRANSITION |

## Verification

```bash
MIX_BUILD_ROOT=_build-laneW660 PATH=$HOME/.asdf/shims:$PATH \
  mix test test/eu_ai_act/airo_grounding_test.exs
```

(Real command output recorded in the lane report; suite green required.)

## Actual output (observed 2026-10-07)

```
Finished in 0.03 seconds (0.03s async, 0.00s sync)

Result: 7 passed
[exited with code 0]
```

Pre-existing (not session-introduced): dialyzer type warning at
`test/eu_ai_act/airo_grounding_test.exs:106` on the always-true
`concept != ""` conjunct — informational only, not a failure.

## Standing

ALIVE on subject `feat/playwright-surface` working tree, files:
`test/eu_ai_act/airo_grounding_test.exs`,
`docs/sjira/v26.10.6/plans/w660-grounding-refresh.md`.
