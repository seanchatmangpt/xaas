# W978c — AuditExportTokenControllerTest repoint (2nd pass, receipt)

Lane: W978c, xaas v26.10.6. Source defect list: W922 final gate 2
(`w922-final-gate-2.md`): `AuditExportTokenControllerTest 404 x3`.
Repo: /Users/sac/xaas, branch `feat/playwright-surface`.
No commit (per lane contract). Build root `_build-laneW978c` deleted at close.

## Finding: STALE — W959's fix already covers this

`test/xaas_web/controllers/audit_export_token_controller_test.exs` already
targets the SPEC-16 route surface; no bare `/:id` PATCH remains. Current PATCH
call sites (all `/revoke`):

- line 203: `patch("/api/audit_export_tokens/#{token.id}/revoke", body)`
- line 230: same (cross-org 403 court)
- line 261: same (already-revoked refusal court)
- line 277: same (missing internal API token 401 court)

No `/use` PATCH tests exist in the file (`:use` is exercised at the Ash
resource surface, not via HTTP here). Route authority:
`lib/xaas/governance/audit_export_token.ex` json_api routes block:
`patch(:use, route: "/:id/use")`, `patch(:revoke, route: "/:id/revoke")`.

Conclusion: W922's 404 x3 was a stale-beam artifact of the mid-wave run (its
beam predated W959's landed repoint, commit `c3df69a8` lineage). Zero edits
made by this lane; the working-tree copy of the test file is unchanged by me.

## Verification (real tails, x2)

Env: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW978c
INTERNAL_API_TOKEN=<test value>`, `mix test
test/xaas_web/controllers/audit_export_token_controller_test.exs`.

Run 1 (exit 0):

```
..........
Finished in 1.3 seconds (0.00s async, 1.3s sync)

Result: 10 passed
```

Run 2 (exit 0): first attempt hit a transient shared-tree compile error
(`parse_inline_idents?/1 undefined` in `lib/xaas/billing/subscription.ex` +
2 siblings) from a concurrent lane's mid-wave write (files at mtime 08:24,
run at 08:26); retried after the write wave settled.

```
..........
Finished in 1.1 seconds (0.00s async, 1.1s sync)

Result: 10 passed
```

## Mutation rationale (not executed — lib is write-forbidden for this lane)

Reverting any PATCH path to bare `/:id` removes its route: the json_api
`routes` block declares only `/:id/use` and `/:id/revoke` as PATCH targets,
so `PATCH /api/audit_export_tokens/:id` has no matching route and Phoenix
returns `404 no_route_found` — exactly the W922 symptom, confirming the
failure class was stale path vs. current routes, not a behavior regression.

## Standing

ALIVE for the controller test surface (10/10 x2, real Postgres sandbox, real
HTTP via ConnCase). W959's fix (landed) supersedes this work order; no diff
manufactured. `_build-laneW978c` deleted.
