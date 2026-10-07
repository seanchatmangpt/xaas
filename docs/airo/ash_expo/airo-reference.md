# AIRo Reference — ash_expo

- Repo: `/Users/sac/ash_expo`
- HEAD: `59a80d5e9a18208d8b25c47e02de6e714e0b8e8c`
  (test/end-to-end-codegen) — verified via `git rev-parse HEAD`
  2026-10-07.
- AIRo dimension: **Generated-artifact integrity** (codegen output
  drift for Expo/EAS mobile builds). `codegen.ex` + `manifest.ex` are
  the Control surface against the RiskSource of a stale manifest
  driving a production mobile build.

## Cited surface (paths verified on disk at HEAD)

- `lib/ash_expo/codegen.ex`, `lib/ash_expo/manifest.ex`
- `lib/ash_expo/resource/` (codegen resource surface)
- `lib/ash_expo/info.ex`

## AIRo status

- No `*airo*` artifact exists in the repo (filesystem-verified).
- Standing: **UNKNOWN**.
- Falsifier (UNKNOWN→ALIVE): pin court at this exact SHA asserting an
  AIRo risk-description artifact with canonical vocab sha `6274d2d8…`,
  cited paths exist, graph parses. Absent that court, UNKNOWN.
