# ash_graphlaw — AIRo reference (W981e)

- Repo: `/Users/sac/ash_graphlaw`, branch `main`, HEAD `1d89ba5f9a56f79e2c0b04cf1ca307d1086d3137` (verified via `git -C /Users/sac/ash_graphlaw rev-parse HEAD`, 2026-10-07).
- AIRo canonical vocab pin: `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469` (AIRo 1.0, DelaramGlp/airo@`6c67de4`, CC-BY-4.0) — same pin as ledger w600 convention.
- Risk dimension evidenced: **Control / guardrail enforcement over agentic actions** (unauthorized-action risk). The graphlaw WASM kernel (`lib/ash_graphlaw/admissions.ex`, `lib/ash_graphlaw/authority.ex`, `lib/ash_graphlaw/evidence.ex`) is a single executable admission/authority law loaded by multiple runtimes; it is the repo surface that most plausibly evidences AIRo's control dimension for AI-agent actuation.
- Standing: **UNKNOWN** — no AIRo risk-description artifact exists in the repo yet (verified by filesystem search, no `*airo*` file outside `_build`/`.git`).
- Wiring falsifier (UNKNOWN → ALIVE): a pin court at the pinned SHA asserting (a) `priv/airo_risk_description.ttl` exists with vocabulary union sha `6274d2d8…`, (b) cited paths `lib/ash_graphlaw/admissions.ex`, `lib/ash_graphlaw/authority.ex`, `lib/ash_graphlaw/evidence.ex` exist, (c) the emitted graph parses (rdflib/SPARQL EX) with RiskSource/Control/Risk triples citing those paths.

## See Also

`docs/cro/artifacts/airo-wiring-ledger.md` · `docs/sjira/v26.10.6/plans/w981e-airo-wiring-extension.md`
