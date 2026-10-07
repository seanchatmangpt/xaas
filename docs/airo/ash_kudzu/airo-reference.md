# AIRo Reference — ash_kudzu

- Repo: `/Users/sac/ash_kudzu`
- HEAD: `2d600ffd4a6721ed5534c753bd4031cd2bf77500` (main) — verified via
  `git rev-parse HEAD` 2026-10-07.
- AIRo dimension: **Evidence-admission integrity for ontology extraction
  from untrusted sources**. `shacl_admission.ex` and
  `sa2a_evidence_admission.ex` are `airo:Control`s against the
  RiskSource of unvetted extracted facts entering the canonical graph.

## Cited surface (paths verified on disk at HEAD)

- `lib/ash_kudzu/shacl_admission.ex`
- `lib/ash_kudzu/sa2a_evidence_admission.ex`
- `lib/ash_kudzu/sa2a_candidate.ex`
- `lib/ash_kudzu/unified_source/` + `unified_source_adapters/`
  (external-source ingestion surface)

## AIRo status

- No `*airo*` artifact exists in the repo (filesystem-verified).
- Standing: **UNKNOWN**.
- Falsifier (UNKNOWN→ALIVE): pin court at this exact SHA asserting a
  `priv/airo_risk_description.ttl` with canonical vocab sha
  `6274d2d8…`, cited paths exist, graph parses with
  RiskSource/Control/Risk triples. Absent that court, UNKNOWN.
