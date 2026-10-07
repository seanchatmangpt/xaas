# AIRo Reference — ash_atlassian

- Repo: `/Users/sac/ash_atlassian`
- HEAD: `43e3d21b7c4e4571493fcf3757392ed16f2dd967` (main) — verified via
  `git rev-parse HEAD` 2026-10-07; matches the number cited by W981e
  (not stale).
- AIRo dimension: **Human-oversight / governance over architectural
  transitions**. The repo models Atlassian-platform governance artifacts
  (architecture decisions/requirements/receipts, SBB qualification,
  transition obligations) — a natural RiskSource (`airo:RiskSource`)
  is an ungoverned architectural transition, with the governance module
  acting as `airo:Control`.

## Cited surface (paths verified on disk at HEAD)

- `lib/ash_atlassian/governance/` — `architecture_decision.ex`,
  `architecture_requirement.ex`, `architecture_receipt.ex`,
  `sbb_qualification.ex`, `transition_obligation.ex`, `abb_gap.ex`
- `lib/ash_atlassian/architecture_governance.ex`
- `lib/ash_atlassian/jira.ex`, `confluence.ex` (transport surface)

## AIRo status

- No `*airo*` artifact exists in the repo (filesystem-verified,
  excluding `.git`/`_build`/`deps`).
- Standing: **UNKNOWN**.
- Falsifier (UNKNOWN→ALIVE): a pin court at this exact SHA whose
  `priv/airo_risk_description.ttl` (or equivalent) (a) byte-matches or
  header-pins the canonical AIRo 1.0 vocab sha256
  `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469`,
  (b) asserts the cited paths above exist, (c) parses as a graph with
  RiskSource/Control/Risk triples. Absent that court, the row stays
  UNKNOWN — not ALIVE and not ADMITTED.
