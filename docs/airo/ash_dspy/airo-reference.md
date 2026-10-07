# AIRo Reference — ash_dspy

- Repo: `/Users/sac/ash_dspy`
- HEAD: `5d985d5332e86d663ba554d249498ba5bd9a0306`
  (feat/v26926-ashdspy-abb-sbb-seed) — verified via `git rev-parse HEAD`
  2026-10-07.
- AIRo dimension: **Verification/admission integrity for AI-program
  (DSPy) evaluation outcomes**. The court/receipt/verify surface is a
  natural `airo:Control` against the RiskSource of unadmitted metric
  claims passing as evidence.

## Cited surface (paths verified on disk at HEAD)

- `lib/ash_dspy/court.ex`, `lib/ash_dspy/court/` (admission courts)
- `lib/ash_dspy/receipt.ex`, `lib/ash_dspy/verify.ex`
- `lib/ash_dspy/metric.ex`, `lib/ash_dspy/ocel.ex`
- `lib/ash_dspy/sa2a/` (sa2a governed-process surface)

## AIRo status

- No `*airo*` artifact exists in the repo (filesystem-verified).
- Standing: **UNKNOWN**.
- Falsifier (UNKNOWN→ALIVE): pin court at this exact SHA asserting a
  `priv/airo_risk_description.ttl` with canonical vocab sha
  `6274d2d8…`, cited paths exist, graph parses with
  RiskSource/Control/Risk triples. Absent that court, UNKNOWN.
