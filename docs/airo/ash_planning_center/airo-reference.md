# AIRo Reference — ash_planning_center

- Repo: `/Users/sac/ash_planning_center`
- HEAD: `5ee26cbdc8fef26c92c7691355c76f5aed2e7b2c` (main) — verified via
  `git rev-parse HEAD` 2026-10-07.
- AIRo dimension: **Data-integrity and access-control over a generated
  external-API client**. The generated Planning Center client is the
  RiskSource (incorrect/over-broad requests against a live third-party
  system); the codegen + JSON:API surface is the potential Control.

## Cited surface (paths verified on disk at HEAD)

- `lib/ash_planning_center/client.ex` (generated client core)
- `lib/ash_planning_center/json_api.ex`, `open_api.ex`
- `lib/ash_planning_center/generated/` (codegen projection)
- `lib/ash_planning_center/people/` (domain resources)

## AIRo status

- No `*airo*` artifact exists in the repo (filesystem-verified).
- Standing: **UNKNOWN**.
- Falsifier (UNKNOWN→ALIVE): pin court at this exact SHA asserting an
  AIRo risk-description artifact with canonical vocab sha `6274d2d8…`,
  cited paths exist, graph parses. Absent that court, UNKNOWN.
