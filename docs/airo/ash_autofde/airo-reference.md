# AIRo Reference — ash_autofde

- Repo: `/Users/sac/ash_autofde`
- HEAD: `65cd05e1bd884383456423af3e516981d8747560` (main) — verified via
  `git rev-parse HEAD` 2026-10-07.
- AIRo dimension: **Resource-allocation control and actuation receipts
  in a WASM CMCA cascade**. `cascade_allocator.ex` and `wasm_cmca.ex`
  are the Control surface against the RiskSource of unbounded cascade
  allocation; `actuation_receipt.ex` carries the replay evidence.

## Cited surface (paths verified on disk at HEAD)

- `lib/ash_autofde/cascade_allocator.ex`
- `lib/ash_autofde/wasm_cmca.ex`
- `lib/ash_autofde/resources/actuation_receipt.ex`,
  `lib/ash_autofde/resources/cmca_cascade_plan.ex`
- `lib/ash_autofde/port_bridge.ex`

## AIRo status

- No `*airo*` artifact exists in the repo (filesystem-verified).
- Standing: **UNKNOWN**.
- Falsifier (UNKNOWN→ALIVE): pin court at this exact SHA asserting an
  AIRo risk-description artifact with canonical vocab sha `6274d2d8…`,
  cited paths exist, graph parses. Absent that court, UNKNOWN.
