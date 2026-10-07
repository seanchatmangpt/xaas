# W959 — audit_export_token controller test route repoint

Date: 2026-10-07. Lane W959, xaas v26.10.6, branch `feat/playwright-surface`.
Origin: W944b F2 (`docs/sjira/v26.10.6/plans/w944b-route-collision.md`) — controller test
still PATCHed bare `/:id` after W940b moved routes to `/:id/use` and `/:id/revoke`.

## Change (4 line diffs, 1 file, no lib changes)

`test/xaas_web/controllers/audit_export_token_controller_test.exs` — repoint PATCH paths
from `/api/audit_export_tokens/:id` to `/api/audit_export_tokens/:id/revoke`
(`lib/xaas/governance/audit_export_token.ex:60`: `patch(:revoke, route: "/:id/revoke")`):

1. L203 — "revokes a real token from the matching org" (expects 200 + persisted `revoked_at`)
2. L230 — cross-org reject (403, no persisted revoke)
3. L261 — already-revoked reject (400)
4. L277 — no-internal-API-token reject (401) — repointed as a sed-restore artifact; kept
   because at HEAD bare `PATCH /:id` has no route (verified 404 `no_route_found` below), so
   the 401 assertion is only meaningful against the real `/:id/revoke` route.

Other 6 tests untouched (POST/GET/GET-by-id surfaces).

## Verification (real runs, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW959, asdf toolchain)

- Baseline pre-edit run compiled the pre-edit file: `Result: 10 passed` (diverges from
  W944b's 3-failing observation — likely stale-build at that lane; noted, not blocking).
- Post-edit: `Result: 10 passed` (run 1), `Result: 10 passed` (run 2). 10/10 ×2 green.
- Mutation: reverted one path to bare `/:id` → 2 failures with real
  `no_route_found` 404 (`"status":"404","title":"NoRouteFound"`), 8/10. Restored → 10/10.
  Reverting the repoint reintroduces the failure; the fix is non-vacuous.

## Notes / transport failures

- Mid-run, another lane's in-progress write to
  `lib/xaas/operations/capability_liveness_regressions.ex` broke compilation
  (`unexpected reserved word: end`) for ~10 min; waited, lane fixed it itself, compile
  green, no action taken on foreign file.
- No commit made (coordinator owns transitions). `_build-laneW959` deleted at cleanup.

## Standing

PARTIAL_ALIVE → ALIVE for this surface: controller test suite is green ×2 on the exact
routed surface (`/:id/revoke`), mutation-killed. Remaining UNKNOWN: none for this lane.
